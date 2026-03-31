import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/io.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/router_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/local_media_store.dart';
import '../../../data/models/router_models.dart';
import '../../widgets/shared/adaptive_media.dart';
import '../editor/editor_screen.dart';

class ConsultantScreen extends ConsumerStatefulWidget {
  const ConsultantScreen({
    super.key,
    required this.selectedImagePath,
    this.returnDraftToPrevious = false,
  });

  final String selectedImagePath;
  final bool returnDraftToPrevious;

  @override
  ConsumerState<ConsultantScreen> createState() => _ConsultantScreenState();
}

class _ConsultantScreenState extends ConsumerState<ConsultantScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, TextEditingController> _answerControllers =
      <String, TextEditingController>{};
  final List<_ChatMessage> _messages = <_ChatMessage>[];
  final Map<String, dynamic> _pendingAnswers = <String, dynamic>{};

  String? _uploadedBaseImageName;
  String? _activeSessionId;
  String? _activeStreamId;
  String? _lastPrompt;
  int? _activeResultMessageIndex;
  IOWebSocketChannel? _streamChannel;
  StreamSubscription<dynamic>? _streamSubscription;

  bool _isUploadingBaseImage = false;
  bool _isSending = false;

  List<RouterClarifyQuestion> _pendingQuestions = const <RouterClarifyQuestion>[];

  @override
  void initState() {
    super.initState();
    _messages.addAll(<_ChatMessage>[
      const _ChatMessage(
        role: _ChatRole.assistant,
        kind: _ChatMessageKind.text,
        text: '把你的修图需求直接告诉我，我会先判断是否需要补充信息，再自动编排并执行。',
      ),
      _ChatMessage(
        role: _ChatRole.assistant,
        kind: _ChatMessageKind.imagePreview,
        imagePath: widget.selectedImagePath,
      ),
    ]);
    Future<void>.microtask(_ensureBaseImageUploaded);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    for (final controller in _answerControllers.values) {
      controller.dispose();
    }
    unawaited(_closeStreamChannel());
    super.dispose();
  }

  Future<void> _ensureBaseImageUploaded() async {
    if (_uploadedBaseImageName != null || _isUploadingBaseImage) return;
    setState(() => _isUploadingBaseImage = true);
    try {
      final result = await ref
          .read(routerRepositoryProvider)
          .uploadBaseImage(filePath: widget.selectedImagePath);
      if (!mounted) return;
      setState(() => _uploadedBaseImageName = result.filename);
    } catch (error) {
      _appendMessage(
        _ChatMessage(
          role: _ChatRole.assistant,
          kind: _ChatMessageKind.error,
          text: _errorMessage(error, '源图上传失败，请稍后再试。'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingBaseImage = false);
      }
    }
  }

  Future<void> _submitPrompt() async {
    if (_isSending) return;
    final prompt = _textController.text.trim();
    if (prompt.isEmpty) return;

    FocusScope.of(context).unfocus();
    _textController.clear();
    _lastPrompt = prompt;
    _activeSessionId = null;
    _activeResultMessageIndex = null;
    _clearPendingQuestions();

    _appendMessage(
      _ChatMessage(
        role: _ChatRole.user,
        kind: _ChatMessageKind.text,
        text: prompt,
      ),
    );

    await _runRouterRequest(
      userMessage: prompt,
      sessionId: null,
      answers: const <String, dynamic>{},
    );
  }

  Future<void> _submitClarificationAnswers() async {
    if (_isSending || _pendingQuestions.isEmpty) return;

    _activeResultMessageIndex = null;

    final answers = <String, dynamic>{};
    for (final question in _pendingQuestions) {
      final value = _resolveQuestionAnswer(question);
      if (question.required && _isAnswerEmpty(value)) {
        _showSnackBar('请先补充“${question.prompt}”');
        return;
      }
      if (!_isAnswerEmpty(value)) {
        answers[question.id] = value;
      }
    }

    _appendMessage(
      _ChatMessage(
        role: _ChatRole.user,
        kind: _ChatMessageKind.text,
        text: _summarizeAnswers(answers),
      ),
    );

    await _runRouterRequest(
      userMessage: null,
      sessionId: _activeSessionId,
      answers: answers,
    );
  }

  Uri _buildRouterWsUri(String streamId) {
    final baseUri = Uri.parse(ApiConstants.baseUrl);
    final scheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    return baseUri.replace(
      scheme: scheme,
      path: '/api/v1/router/ws/run/$streamId',
      query: null,
      fragment: null,
    );
  }

  Future<void> _closeStreamChannel({bool clearIdentifiers = true}) async {
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    await _streamChannel?.sink.close();
    _streamChannel = null;
    if (clearIdentifiers) {
      _activeStreamId = null;
      _activeResultMessageIndex = null;
    }
  }

  Future<String?> _prepareStreamChannel() async {
    await _closeStreamChannel(clearIdentifiers: false);
    final streamId = (await ref.read(routerRepositoryProvider).createStreamId()).streamId;
    if (streamId.isEmpty) {
      return null;
    }

    final channel = IOWebSocketChannel.connect(_buildRouterWsUri(streamId));
    _streamChannel = channel;
    _activeStreamId = streamId;
    _streamSubscription = channel.stream.listen(
      _handleStreamEventData,
      onError: (Object error) {
        if (!mounted) return;
        _updateActiveResultMessage((current) {
          final nextExtra = Map<String, dynamic>.from(current.extra);
          nextExtra['stream_state'] = '实时通道连接异常';
          return current.copyWith(
            extra: nextExtra,
            executionError: current.executionError ?? error.toString(),
          );
        });
      },
      onDone: () {
        if (!mounted) return;
        _streamChannel = null;
        _streamSubscription = null;
      },
      cancelOnError: false,
    );
    return streamId;
  }

  Map<String, dynamic> _normalizeLoopbackUrls(Map<String, dynamic> data) {
    return _normalizeNode(data) as Map<String, dynamic>;
  }

  dynamic _normalizeNode(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value.map<String, dynamic>(
        (key, nested) => MapEntry<String, dynamic>(key, _normalizeNode(nested)),
      );
    }
    if (value is List<dynamic>) {
      return value.map<dynamic>(_normalizeNode).toList();
    }
    if (value is String) {
      return _rewriteLocalUrl(value);
    }
    return value;
  }

  String _rewriteLocalUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return raw;
    final host = uri.host.trim();
    if (host != '127.0.0.1' && host != 'localhost') {
      return raw;
    }

    final baseUri = Uri.parse(ApiConstants.baseUrl);
    final updated = uri.replace(
      host: baseUri.host,
      port: uri.hasPort ? uri.port : baseUri.port,
    );
    return updated.toString();
  }

  Future<void> _runRouterRequest({
    required String? userMessage,
    required String? sessionId,
    required Map<String, dynamic> answers,
  }) async {
    await _ensureBaseImageUploaded();
    if (_uploadedBaseImageName == null) {
      _showSnackBar('源图还没有准备好，请稍后再试');
      return;
    }

    final userId = ref.read(authProvider)?.userId.toString() ?? '';
    setState(() => _isSending = true);
    try {
      String? streamId;
      try {
        streamId = await _prepareStreamChannel();
      } catch (_) {
        await _closeStreamChannel();
        streamId = null;
      }
      final response = await ref.read(routerRepositoryProvider).routeAndRun(
            userId: userId,
            sessionId: sessionId,
            userMessage: userMessage,
            baseImage: sessionId == null ? _uploadedBaseImageName : null,
            baseImageMeta: const <String, dynamic>{},
            answers: answers,
            executeWhenReady: true,
            asyncExecution: streamId != null,
            streamId: streamId,
          );

      if (!mounted) return;
      setState(() => _activeSessionId = response.sessionId);
      _handleRouterResponse(response);
    } catch (error) {
      await _closeStreamChannel();
      _appendMessage(
        _ChatMessage(
          role: _ChatRole.assistant,
          kind: _ChatMessageKind.error,
          text: _errorMessage(error, 'AI 修图暂时不可用，请稍后再试。'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _handleRouterResponse(RouterRouteAndRunResponse response) {
    final userFacingThought = _buildUserFacingThought(response);
    if (userFacingThought != null && userFacingThought.trim().isNotEmpty) {
      _appendMessage(
        _ChatMessage(
          role: _ChatRole.assistant,
          kind: _ChatMessageKind.text,
          text: userFacingThought,
        ),
      );
    }

    switch (response.status) {
      case RouterStatus.needClarification:
        unawaited(_closeStreamChannel());
        _bindPendingQuestions(response.questions);
        final questionText = response.questions.map((item) => item.prompt).join('\n');
        _appendMessage(
          _ChatMessage(
            role: _ChatRole.assistant,
            kind: _ChatMessageKind.text,
            text: questionText.isEmpty ? '还需要补充一点信息。' : questionText,
          ),
        );
        break;
      case RouterStatus.ready:
        _clearPendingQuestions();
        final nextExtra = Map<String, dynamic>.from(response.extra);
        if (response.executionStarted) {
          nextExtra['stream_state'] = '透镜流程已启动，正在实时生成';
        }
        final seededResponse = response.copyWith(
          extra: nextExtra,
          streamId: response.streamId ?? _activeStreamId,
          stepResults: response.stepResults.isEmpty
              ? _seedStepResults(response.blueprint)
              : response.stepResults,
        );
        final index = _appendMessage(
          _ChatMessage(
            role: _ChatRole.assistant,
            kind: _ChatMessageKind.result,
            response: seededResponse,
          ),
        );
        _activeResultMessageIndex = index;
        if (!seededResponse.executionStarted &&
            !seededResponse.hasExecutionError &&
            seededResponse.resultUrl != null) {
          Future<void>.microtask(() => _cacheResultForMessage(index, seededResponse));
        }
        break;
      case RouterStatus.failed:
        unawaited(_closeStreamChannel());
        _clearPendingQuestions();
        _appendMessage(
          _ChatMessage(
            role: _ChatRole.assistant,
            kind: _ChatMessageKind.error,
            text: _buildFailedMessage(response),
          ),
        );
        break;
      case RouterStatus.unknown:
        unawaited(_closeStreamChannel());
        _appendMessage(
          const _ChatMessage(
            role: _ChatRole.assistant,
            kind: _ChatMessageKind.error,
            text: '返回了未识别的 Router 状态。',
          ),
        );
        break;
    }
  }

  List<RouterStepResult> _seedStepResults(RouterBlueprint? blueprint) {
    if (blueprint == null) {
      return const <RouterStepResult>[];
    }
    return blueprint.steps
        .map(
          (step) => RouterStepResult(
            stepId: step.stepId,
            lensId: step.lensId,
            tweakControls: const <Map<String, dynamic>>[],
            outputs: const <RouterStepOutput>[],
          ),
        )
        .toList();
  }

  void _handleStreamEventData(dynamic event) {
    try {
      final dynamic decoded = event is String ? jsonDecode(event) : event;
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      _handleStreamEvent(_normalizeLoopbackUrls(decoded));
    } catch (_) {}
  }

  void _handleStreamEvent(Map<String, dynamic> event) {
    if (!mounted) return;
    final name = event['event']?.toString() ?? '';
    switch (name) {
      case 'connected':
        return;
      case 'blueprint_ready':
        _updateActiveResultMessage((current) {
          final blueprint = event['blueprint'] is Map<String, dynamic>
              ? RouterBlueprint.fromJson(event['blueprint'] as Map<String, dynamic>)
              : current.blueprint;
          return current.copyWith(
            blueprint: blueprint,
            stepResults: current.stepResults.isEmpty
                ? _seedStepResults(blueprint)
                : current.stepResults,
          );
        });
        return;
      case 'execution_started':
        _updateActiveResultMessage((current) {
          final nextExtra = Map<String, dynamic>.from(current.extra);
          nextExtra['stream_state'] = '开始执行透镜流程';
          return current.copyWith(
            executionStarted: true,
            extra: nextExtra,
          );
        });
        return;
      case 'step_started':
        final stepIndex = event['step_index'];
        final totalSteps = event['total_steps'];
        final lensId = event['lens_id']?.toString() ?? '';
        _updateActiveResultMessage((current) {
          final nextExtra = Map<String, dynamic>.from(current.extra);
          nextExtra['current_step_id'] = event['step_id']?.toString();
          nextExtra['stream_state'] = '正在执行 ${stepIndex ?? ''}/${totalSteps ?? ''} · $lensId';
          return current.copyWith(
            executionStarted: true,
            extra: nextExtra,
          );
        });
        return;
      case 'step_completed':
        final stepId = event['step_id']?.toString() ?? '';
        final lensId = event['lens_id']?.toString() ?? '';
        final outputs = (event['outputs'] as List<dynamic>? ?? const <dynamic>[])
            .map((item) => RouterStepOutput.fromJson(item as Map<String, dynamic>))
            .toList();
        _updateActiveResultMessage((current) {
          final nextExtra = Map<String, dynamic>.from(current.extra);
          nextExtra['current_step_id'] = stepId;
          nextExtra['stream_state'] = '$lensId 已输出 ${outputs.length} 张过程图';
          return current.copyWith(
            executionStarted: true,
            extra: nextExtra,
            stepResults: _mergeStepResults(
              current.stepResults,
              RouterStepResult(
                stepId: stepId,
                lensId: lensId,
                tweakControls: _existingTweakControls(current.stepResults, stepId),
                outputs: outputs,
              ),
            ),
          );
        });
        _scheduleScrollToBottom();
        return;
      case 'execution_completed':
        _updateActiveResultMessage((current) {
          final nextExtra = Map<String, dynamic>.from(current.extra);
          nextExtra['stream_state'] = '执行完成';
          nextExtra.remove('current_step_id');
          return current.copyWith(
            executed: true,
            executionStarted: true,
            executionContext: Map<String, dynamic>.from(
              event['execution_context'] as Map<String, dynamic>? ?? const <String, dynamic>{},
            ),
            resultFilename: event['result_filename']?.toString(),
            resultUrl: event['result_url']?.toString(),
            extra: nextExtra,
            stepResults: (event['step_results'] as List<dynamic>? ?? const <dynamic>[])
                .map((item) => RouterStepResult.fromJson(item as Map<String, dynamic>))
                .toList(),
          );
        });
        final index = _activeResultMessageIndex;
        final response = index != null && index < _messages.length
            ? _messages[index].response
            : null;
        if (index != null && response != null && response.resultUrl != null) {
          Future<void>.microtask(() => _cacheResultForMessage(index, response));
        }
        unawaited(_closeStreamChannel(clearIdentifiers: false));
        return;
      case 'execution_failed':
        _updateActiveResultMessage((current) {
          final nextExtra = Map<String, dynamic>.from(current.extra);
          nextExtra['stream_state'] = '执行失败';
          nextExtra.remove('current_step_id');
          return current.copyWith(
            executionError: event['error']?.toString() ?? '执行失败',
            extra: nextExtra,
          );
        });
        unawaited(_closeStreamChannel(clearIdentifiers: false));
        return;
    }
  }

  List<Map<String, dynamic>> _existingTweakControls(
    List<RouterStepResult> steps,
    String stepId,
  ) {
    for (final step in steps) {
      if (step.stepId == stepId) {
        return step.tweakControls;
      }
    }
    return const <Map<String, dynamic>>[];
  }

  List<RouterStepResult> _mergeStepResults(
    List<RouterStepResult> steps,
    RouterStepResult incoming,
  ) {
    final next = List<RouterStepResult>.from(steps);
    final index = next.indexWhere((step) => step.stepId == incoming.stepId);
    if (index == -1) {
      next.add(incoming);
      return next;
    }
    next[index] = RouterStepResult(
      stepId: incoming.stepId,
      lensId: incoming.lensId.isEmpty ? next[index].lensId : incoming.lensId,
      tweakControls: incoming.tweakControls.isEmpty
          ? next[index].tweakControls
          : incoming.tweakControls,
      outputs: incoming.outputs.isEmpty ? next[index].outputs : incoming.outputs,
    );
    return next;
  }

  void _updateActiveResultMessage(
    RouterRouteAndRunResponse Function(RouterRouteAndRunResponse current) update,
  ) {
    final index = _activeResultMessageIndex;
    if (index == null || index < 0 || index >= _messages.length) {
      return;
    }
    final current = _messages[index].response;
    if (current == null) {
      return;
    }
    setState(() {
      _messages[index] = _messages[index].copyWith(
        response: update(current),
      );
    });
  }

  Future<void> _cacheResultForMessage(
    int index,
    RouterRouteAndRunResponse response,
  ) async {
    final resultUrl = response.resultUrl;
    if (resultUrl == null || resultUrl.trim().isEmpty) return;
    try {
      final http = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 5),
        ),
      );
      final download = await http.get<List<int>>(
        resultUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = download.data;
      if (bytes == null || bytes.isEmpty) return;
      final savedPath = await LocalMediaStore.persistBytes(
        Uint8List.fromList(bytes),
        folder: 'router_results',
        prefix: 'router_result',
        extension: _guessExtension(response.resultFilename ?? resultUrl),
      );
      if (!mounted || index >= _messages.length) return;
      setState(() {
        _messages[index] = _messages[index].copyWith(localResultPath: savedPath);
      });
    } catch (_) {}
  }

  void _bindPendingQuestions(List<RouterClarifyQuestion> questions) {
    for (final controller in _answerControllers.values) {
      controller.dispose();
    }
    _answerControllers.clear();
    _pendingAnswers.clear();

    for (final question in questions) {
      final defaultValue = question.uiSchema.defaultValue;
      switch (question.type) {
        case RouterQuestionType.text:
        case RouterQuestionType.unknown:
          final controller = TextEditingController(
            text: defaultValue?.toString() ?? '',
          );
          _answerControllers[question.id] = controller;
          break;
        case RouterQuestionType.singleChoice:
          _pendingAnswers[question.id] = defaultValue?.toString();
          break;
        case RouterQuestionType.multiChoice:
          final values = defaultValue is List<dynamic>
              ? defaultValue.map((item) => item.toString()).toList()
              : <String>[];
          _pendingAnswers[question.id] = values;
          break;
        case RouterQuestionType.slider:
          _pendingAnswers[question.id] =
              (defaultValue as num?)?.toDouble() ?? question.uiSchema.min ?? 0.0;
          break;
      }
    }

    setState(() {
      _pendingQuestions = questions;
    });
  }

  void _clearPendingQuestions() {
    for (final controller in _answerControllers.values) {
      controller.dispose();
    }
    _answerControllers.clear();
    _pendingAnswers.clear();
    setState(() => _pendingQuestions = const <RouterClarifyQuestion>[]);
  }

  dynamic _resolveQuestionAnswer(RouterClarifyQuestion question) {
    return switch (question.type) {
      RouterQuestionType.text || RouterQuestionType.unknown =>
        _answerControllers[question.id]?.text.trim(),
      RouterQuestionType.singleChoice => _pendingAnswers[question.id]?.toString(),
      RouterQuestionType.multiChoice =>
        List<String>.from(_pendingAnswers[question.id] as List<String>? ?? const <String>[]),
      RouterQuestionType.slider => _pendingAnswers[question.id],
    };
  }

  bool _isAnswerEmpty(dynamic value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    if (value is List) return value.isEmpty;
    return false;
  }

  int _appendMessage(_ChatMessage message) {
    final index = _messages.length;
    setState(() => _messages.add(message));
    _scheduleScrollToBottom();
    return index;
  }

  void _scheduleScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 160,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _openEditorWithDraft(String draftPath, RouterRouteAndRunResponse response) {
    if (widget.returnDraftToPrevious) {
      Navigator.pop(
        context,
        ConsultantDraftResult(
          draftImagePath: draftPath,
          prompt: _lastPrompt,
          lensId: response.blueprint?.steps.isNotEmpty == true
              ? response.blueprint!.steps.last.lensId
              : 'router_generate',
          lensName: 'AI 修图',
          tagLabel: 'AI 草稿',
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditorScreen(
          selectedImage: File(widget.selectedImagePath),
          initialPrompt: _lastPrompt,
          initialDraftImagePath: draftPath,
          initialDraftLensId: response.blueprint?.steps.isNotEmpty == true
              ? response.blueprint!.steps.last.lensId
              : 'router_generate',
          initialDraftLensName: 'AI 修图',
          initialDraftTagLabel: 'AI 草稿',
        ),
      ),
    );
  }

  String? _buildUserFacingThought(RouterRouteAndRunResponse response) {
    final sanitizedThought = _sanitizeThoughtProcess(response.thoughtProcess);
    switch (response.status) {
      case RouterStatus.needClarification:
        return sanitizedThought?.isNotEmpty == true
            ? sanitizedThought
            : '我还需要补充一点信息，才能继续帮你修图。';
      case RouterStatus.ready:
        if (response.executionStarted) {
          return null;
        }
        return sanitizedThought;
      case RouterStatus.failed:
      case RouterStatus.unknown:
        return null;
    }
  }

  String _buildFailedMessage(RouterRouteAndRunResponse response) {
    final sanitizedThought = _sanitizeThoughtProcess(response.thoughtProcess);
    if (sanitizedThought != null && sanitizedThought.isNotEmpty) {
      return sanitizedThought;
    }
    return '这次处理失败了，请换一种描述再试试。';
  }

  String? _sanitizeThoughtProcess(String? rawThought) {
    final raw = rawThought?.trim() ?? '';
    if (raw.isEmpty) return null;

    const blockedFragments = <String>[
      'rag',
      'retrieved_lenses',
      'heuristic',
      'planner',
      'planning',
      'validation',
      'asset-based recovery',
      'blueprint',
      'dns',
      'temporary failure in name resolution',
      'router v2',
      'external',
      'llm',
      'debug',
      'trace',
      'stack',
    ];

    final lines = raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where((line) {
          final lower = line.toLowerCase();
          for (final fragment in blockedFragments) {
            if (lower.contains(fragment)) {
              return false;
            }
          }
          return true;
        })
        .toList();

    if (lines.isEmpty) {
      return null;
    }
    return lines.join('\n');
  }

  String _summarizeAnswers(Map<String, dynamic> answers) {
    final parts = <String>[];
    answers.forEach((key, value) {
      if (value is List<dynamic>) {
        parts.add(value.join(' / '));
      } else {
        parts.add(value.toString());
      }
    });
    return parts.isEmpty ? '已补充信息' : parts.join('\n');
  }

  String _guessExtension(String source) {
    final normalized = source.split('?').first.trim();
    final dotIndex = normalized.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == normalized.length - 1) {
      return '.png';
    }
    final extension = normalized.substring(dotIndex).toLowerCase();
    if (extension.length > 10) return '.png';
    return extension;
  }

  String _errorMessage(Object error, String fallback) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic> && data['detail'] != null) {
        return data['detail'].toString();
      }
      if (error.message != null && error.message!.trim().isNotEmpty) {
        return error.message!;
      }
    }
    return fallback;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020204),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF141019), Color(0xFF060609), Color(0xFF020204)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, 0.3, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 220),
                      itemCount: _messages.length + (_isSending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_isSending && index == _messages.length) {
                          return const _TypingBubble();
                        }
                        return _buildMessageItem(_messages[index]);
                      },
                    ),
                    IgnorePointer(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          height: 36,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xCC060609), Colors.transparent],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: 64,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.transparent, Color(0xE6060609)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_pendingQuestions.isNotEmpty) _buildClarificationPanel(),
              _buildComposer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: Colors.white,
            iconSize: 18,
            splashRadius: 18,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI 修图',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  _uploadedBaseImageName == null
                      ? (_isUploadingBaseImage ? '正在准备源图...' : '等待源图上传')
                      : '源图已接入，可以直接开始对话',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.56),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _uploadedBaseImageName == null
                        ? const Color(0xFFF4B740)
                        : AppTheme.electricIndigo,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _uploadedBaseImageName == null ? '准备中' : '已连接',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(_ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Align(
        alignment: message.role == _ChatRole.user
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.82,
          ),
          child: switch (message.kind) {
            _ChatMessageKind.text => _TextBubble(message: message),
            _ChatMessageKind.error => _TextBubble(message: message, error: true),
            _ChatMessageKind.imagePreview => _ImagePreviewBubble(
                imagePath: widget.selectedImagePath,
                isUploading: _isUploadingBaseImage,
                isReady: _uploadedBaseImageName != null,
              ),
            _ChatMessageKind.result => _ResultBubble(
                message: message,
                onOpenEditor: message.localResultPath == null || message.response == null
                    ? null
                    : () => _openEditorWithDraft(
                          message.localResultPath!,
                          message.response!,
                        ),
              ),
          },
        ),
      ),
    );
  }

  Widget _buildClarificationPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
              color: const Color(0xCC111118),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '还差一点信息',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '补充这些参数后，我会继续自动编排并执行。',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.56),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                ..._pendingQuestions.map(_buildQuestionCard),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSending ? null : _submitClarificationAnswers,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.electricIndigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      '继续生成',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(RouterClarifyQuestion question) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.prompt,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          switch (question.type) {
            RouterQuestionType.text || RouterQuestionType.unknown =>
              _buildTextQuestion(question),
            RouterQuestionType.singleChoice => _buildSingleChoiceQuestion(question),
            RouterQuestionType.multiChoice => _buildMultiChoiceQuestion(question),
            RouterQuestionType.slider => _buildSliderQuestion(question),
          },
        ],
      ),
    );
  }

  Widget _buildTextQuestion(RouterClarifyQuestion question) {
    return TextField(
      controller: _answerControllers[question.id],
      style: const TextStyle(color: Colors.white),
      minLines: 2,
      maxLines: 4,
      decoration: InputDecoration(
        hintText: '请输入补充说明',
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.3),
          fontSize: 12,
        ),
        filled: true,
        fillColor: const Color(0xFF17171D),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }

  Widget _buildSingleChoiceQuestion(RouterClarifyQuestion question) {
    final selected = _pendingAnswers[question.id]?.toString();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: question.options.map((option) {
        final active = selected == option;
        return ChoiceChip(
          label: Text(option),
          selected: active,
          onSelected: (_) => setState(() => _pendingAnswers[question.id] = option),
          labelStyle: TextStyle(
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.78),
            fontWeight: FontWeight.w600,
          ),
          selectedColor: AppTheme.electricIndigo.withValues(alpha: 0.28),
          backgroundColor: const Color(0xFF17171D),
          side: BorderSide(
            color: active
                ? AppTheme.electricIndigo
                : Colors.white.withValues(alpha: 0.08),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMultiChoiceQuestion(RouterClarifyQuestion question) {
    final selected = List<String>.from(
      _pendingAnswers[question.id] as List<String>? ?? const <String>[],
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: question.options.map((option) {
        final active = selected.contains(option);
        return FilterChip(
          label: Text(option),
          selected: active,
          onSelected: (value) {
            final next = List<String>.from(selected);
            if (value) {
              next.add(option);
            } else {
              next.remove(option);
            }
            setState(() => _pendingAnswers[question.id] = next);
          },
          labelStyle: TextStyle(
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.78),
            fontWeight: FontWeight.w600,
          ),
          selectedColor: AppTheme.electricIndigo.withValues(alpha: 0.28),
          backgroundColor: const Color(0xFF17171D),
          side: BorderSide(
            color: active
                ? AppTheme.electricIndigo
                : Colors.white.withValues(alpha: 0.08),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSliderQuestion(RouterClarifyQuestion question) {
    final min = question.uiSchema.min ?? 0;
    final max = question.uiSchema.max ?? 100;
    final step = question.uiSchema.step ?? 1;
    final currentValue = (_pendingAnswers[question.id] as double?) ?? min;
    final divisions = step <= 0 ? null : ((max - min) / step).round();

    return Column(
      children: [
        Row(
          children: [
            Text(
              min.toStringAsFixed(step < 1 ? 1 : 0),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: 11,
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: AppTheme.electricIndigo,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                  thumbColor: Colors.white,
                  overlayColor: AppTheme.electricIndigo.withValues(alpha: 0.18),
                ),
                child: Slider(
                  value: currentValue.clamp(min, max),
                  min: min,
                  max: max,
                  divisions: divisions,
                  onChanged: (value) =>
                      setState(() => _pendingAnswers[question.id] = value),
                ),
              ),
            ),
            Text(
              max.toStringAsFixed(step < 1 ? 1 : 0),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: 11,
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            currentValue.toStringAsFixed(step < 1 ? 1 : 0),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComposer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: const Color(0xCC0E0E14),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_pendingQuestions.isEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _QuickPromptChip(
                        label: '宫崎骏风格',
                        onTap: () => _textController.text = '帮我把这张图改成宫崎骏动画风格，保留主体构图',
                      ),
                      _QuickPromptChip(
                        label: '背景清理',
                        onTap: () => _textController.text = '保留人物不变，把背景杂物清理干净',
                      ),
                      _QuickPromptChip(
                        label: '人像通透',
                        onTap: () => _textController.text = '让整个人像更通透自然，肤色更干净',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        minLines: 1,
                        maxLines: 5,
                        enabled: !_isSending,
                        decoration: InputDecoration(
                          hintText: _pendingQuestions.isNotEmpty
                              ? '先完成上面的补充信息'
                              : '直接描述你想要的修图效果',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.28),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF17171D),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                        ),
                        onSubmitted: (_) =>
                            _pendingQuestions.isEmpty ? _submitPrompt() : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: _pendingQuestions.isEmpty && !_isSending ? _submitPrompt : null,
                      borderRadius: BorderRadius.circular(22),
                      child: Ink(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _pendingQuestions.isEmpty && !_isSending
                              ? AppTheme.electricIndigo
                              : const Color(0xFF2B2B33),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Icon(
                          _isSending ? Icons.hourglass_top_rounded : Icons.arrow_upward_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _ChatRole { assistant, user }

enum _ChatMessageKind { text, imagePreview, result, error }

class ConsultantDraftResult {
  const ConsultantDraftResult({
    required this.draftImagePath,
    required this.prompt,
    required this.lensId,
    required this.lensName,
    required this.tagLabel,
  });

  final String draftImagePath;
  final String? prompt;
  final String lensId;
  final String lensName;
  final String tagLabel;
}

class _ChatMessage {
  const _ChatMessage({
    required this.role,
    required this.kind,
    this.text,
    this.imagePath,
    this.response,
    this.localResultPath,
  });

  final _ChatRole role;
  final _ChatMessageKind kind;
  final String? text;
  final String? imagePath;
  final RouterRouteAndRunResponse? response;
  final String? localResultPath;

  _ChatMessage copyWith({
    String? localResultPath,
    RouterRouteAndRunResponse? response,
  }) {
    return _ChatMessage(
      role: role,
      kind: kind,
      text: text,
      imagePath: imagePath,
      response: response ?? this.response,
      localResultPath: localResultPath ?? this.localResultPath,
    );
  }
}

class _TextBubble extends StatelessWidget {
  const _TextBubble({
    required this.message,
    this.error = false,
  });

  final _ChatMessage message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == _ChatRole.user;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: isUser
            ? const LinearGradient(
                colors: [Color(0xFF7B61FF), AppTheme.electricIndigo],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isUser
            ? null
            : error
                ? const Color(0xFF2B1218)
                : const Color(0xCC121219),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(22),
          topRight: const Radius.circular(22),
          bottomLeft: Radius.circular(isUser ? 22 : 8),
          bottomRight: Radius.circular(isUser ? 8 : 22),
        ),
        border: Border.all(
          color: error
              ? Colors.redAccent.withValues(alpha: 0.28)
              : Colors.white.withValues(alpha: isUser ? 0.0 : 0.08),
        ),
      ),
      child: Text(
        message.text ?? '',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          height: 1.55,
        ),
      ),
    );
  }
}

class _ImagePreviewBubble extends StatelessWidget {
  const _ImagePreviewBubble({
    required this.imagePath,
    required this.isUploading,
    required this.isReady,
  });

  final String imagePath;
  final bool isUploading;
  final bool isReady;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xCC121219),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 0.95,
              child: buildAdaptiveImage(
                imagePath,
                fit: BoxFit.cover,
                errorWidget: Container(
                  color: const Color(0xFF17171D),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_outlined,
                    color: AppTheme.electricIndigo,
                    size: 36,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isReady ? AppTheme.electricIndigo : const Color(0xFFF4B740),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isReady
                    ? '原图已就绪，可以直接开始 AI 修图'
                    : isUploading
                        ? '正在上传原图到编排引擎...'
                        : '等待原图接入',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultBubble extends StatelessWidget {
  const _ResultBubble({
    required this.message,
    required this.onOpenEditor,
  });

  final _ChatMessage message;
  final VoidCallback? onOpenEditor;

  @override
  Widget build(BuildContext context) {
    final response = message.response;
    if (response == null) {
      return const SizedBox.shrink();
    }

    final resultImage = message.localResultPath ?? response.resultUrl;
    final retrievedLenses = (response.extra['retrieved_lenses'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => item.toString())
        .toList();
    final streamState = response.extra['stream_state']?.toString();
    final currentStepId = response.extra['current_step_id']?.toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xCC121219),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.electricIndigo.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'AI 结果',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                response.executed
                    ? '已执行'
                    : response.executionStarted
                        ? '执行中'
                        : '已编排',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (streamState != null && streamState.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              streamState,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (resultImage != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: 0.92,
                child: buildAdaptiveImage(
                  resultImage,
                  fit: BoxFit.contain,
                  placeholder: Container(
                    color: const Color(0xFF17171D),
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(
                      color: AppTheme.electricIndigo,
                    ),
                  ),
                  errorWidget: Container(
                    color: const Color(0xFF17171D),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ),
            ),
          if (resultImage != null) const SizedBox(height: 12),
          Row(
            children: [
              _MetricPill(
                label: '${response.blueprint?.steps.length ?? 0} 步编排',
              ),
              const SizedBox(width: 8),
              _MetricPill(
                label: response.stepResults.isEmpty
                    ? (response.executionStarted ? '等待过程图' : '暂无过程图')
                    : '${response.stepResults.length} 个过程节点',
              ),
            ],
          ),
          if (retrievedLenses.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '透镜组合',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: retrievedLenses
                  .map((lens) => _LensTag(label: lens))
                  .toList(),
            ),
          ],
          if (response.hasExecutionError) ...[
            const SizedBox(height: 12),
            Text(
              response.executionError!,
              style: const TextStyle(
                color: Color(0xFFFF8A8A),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
          if (response.stepResults.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              '过程图',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            ...response.stepResults.map(
              (step) => _StepResultCard(
                step: step,
                isActive: currentStepId != null && currentStepId == step.stepId,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onOpenEditor,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.electricIndigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                onOpenEditor == null
                    ? (response.executionStarted ? '正在生成修图草稿...' : '正在准备修图草稿...')
                    : '进入修图',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepResultCard extends StatelessWidget {
  const _StepResultCard({
    required this.step,
    this.isActive = false,
  });

  final RouterStepResult step;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.electricIndigo.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive
              ? AppTheme.electricIndigo.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step.lensId,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            step.stepId,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11,
            ),
          ),
          if (step.outputs.isEmpty) ...[
            const SizedBox(height: 10),
            Text(
              isActive ? '正在生成当前步骤的结果...' : '等待执行或等待过程图回传',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 12,
              ),
            ),
          ],
          if (step.outputs.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: step.outputs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final output = step.outputs[index];
                  return SizedBox(
                    width: 108,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: buildAdaptiveImage(
                              output.url,
                              fit: BoxFit.cover,
                              width: 108,
                              errorWidget: Container(
                                color: const Color(0xFF17171D),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.image_not_supported_outlined,
                                  color: Colors.white38,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          output.outputName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.76),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LensTag extends StatelessWidget {
  const _LensTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.electricIndigo.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.electricIndigo.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xCC121219),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget>.generate(
            3,
            (index) => Container(
              margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7 - index * 0.16),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickPromptChip extends StatelessWidget {
  const _QuickPromptChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
