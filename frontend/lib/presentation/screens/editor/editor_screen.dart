import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers/asset_tree_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/local_media_store.dart';
import '../../../data/models/asset_tree_models.dart';
import '../../../data/models/lens_tool_models.dart';
import '../../../data/models/router_models.dart';
import '../../../data/repositories/asset_tree_repository.dart';
import '../../../data/repositories/lenses_repository.dart';
import '../../../data/repositories/router_repository.dart';
import '../create/consultant_screen.dart';
import '../../widgets/editor/asset_tree_node_sheet.dart';
import '../../widgets/editor/editor_ai_toolbox_panel.dart';
import '../../widgets/editor/editor_canvas.dart';
import '../../widgets/editor/editor_header.dart';
import '../../widgets/editor/editor_tools_panel.dart';
import '../../widgets/editor/image_history_tree.dart';
import '../../widgets/shared/adaptive_media.dart';

enum ToolType { none, aiChat, aiToolbox, crop, adjust, templates }

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({
    super.key,
    required this.selectedImage,
    this.initialPrompt,
    this.initialDraftImagePath,
    this.initialDraftLensId,
    this.initialDraftLensName,
    this.initialDraftTagLabel,
  });

  final File selectedImage;
  final String? initialPrompt;
  final String? initialDraftImagePath;
  final String? initialDraftLensId;
  final String? initialDraftLensName;
  final String? initialDraftTagLabel;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  final TextEditingController _promptController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isGenerating = false;
  bool _isBootstrapping = true;
  bool _isLoadingProject = false;

  String? _displayedImagePath;
  String? _initialImagePath;
  String? _projectError;
  Size? _currentImageSize;

  ToolType _activeTool = ToolType.aiChat;
  double _cropAspectRatio = -1;
  String _activeAdjustParam = '曝光';
  double _adjustValue = 0.0;
  String? _selectedLensId;
  String? _selectedAiToolId = kEditorAiToolDefinitions.first.lensId;
  Rect _cropRect = const Rect.fromLTWH(0.12, 0.1, 0.76, 0.76);
  Map<String, dynamic> _aiToolParamValues = <String, dynamic>{};
  Map<String, dynamic> _aiToolControlValues = <String, dynamic>{};
  Map<String, String> _aiToolLocalAssetPaths = <String, String>{};
  final Map<String, String> _uploadedAiAssetCache = <String, String>{};
  String? _aiToolStatusText;
  List<RouterStepResult> _aiToolStepResults = const <RouterStepResult>[];

  List<String> _appliedLensIds = <String>[];
  String? _activeHighlightId;
  bool _hasPendingEdits = false;
  String? _pendingLensId;
  String? _pendingLensName;
  String? _pendingPrompt;
  String? _pendingTagLabel;

  AssetTreeProject? _project;
  AssetTreeProjectTree? _tree;
  String? _currentNodeId;

  @override
  void initState() {
    super.initState();
    final initialPrompt = widget.initialPrompt?.trim();
    if (initialPrompt != null && initialPrompt.isNotEmpty) {
      _promptController.text = initialPrompt;
    }
    Future<void>.microtask(_bootstrapInitialProject);
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _bootstrapInitialProject() async {
    setState(() {
      _projectError = null;
      _isBootstrapping = true;
    });

    try {
      await _createProjectFromFile(widget.selectedImage);
      await _seedInitialDraftIfNeeded();
    } catch (error) {
      _showError(error, '初始化资产树项目失败');
      if (!mounted) return;
      setState(() => _projectError = _messageFromError(error, '初始化资产树项目失败'));
    } finally {
      if (mounted) {
        setState(() => _isBootstrapping = false);
      }
    }
  }

  Future<void> _createProjectFromFile(File source) async {
    final repository = ref.read(assetTreeRepositoryProvider);
    final storedPath = await LocalMediaStore.persistFile(
      source,
      folder: 'asset_tree',
      prefix: 'root',
    );
    final payload = await _buildFilePayload(source, storedPath);

    final project = await repository.createProject(
      CreateAssetTreeProjectInput(
        name: _buildDefaultProjectName(),
        description: '编辑器项目',
      ),
    );
    ref.invalidate(assetTreeProjectsProvider);
    final rootNode = await repository.addRootNode(
      projectId: project.projectId,
      input: payload,
    );

    _initialImagePath = storedPath;
    await _loadProject(project.projectId, preferredNodeId: rootNode.nodeId);
  }

  Future<void> _loadProject(
    String projectId, {
    String? preferredNodeId,
  }) async {
    setState(() => _isLoadingProject = true);
    try {
      final tree = await ref.read(assetTreeRepositoryProvider).getProjectTree(
            projectId,
          );
      final nodeId =
          preferredNodeId ??
          tree.project.currentNodeId ??
          tree.project.rootNodeId ??
          (tree.nodes.isNotEmpty ? tree.nodes.last.nodeId : null);
      final node = nodeId == null ? null : tree.nodeMap[nodeId];
      final imagePath = _normalizeProjectImagePath(
        node?.imageUrl ?? tree.project.coverUrl ?? _initialImagePath,
      );
      final imageSize = await _resolveImageSize(imagePath);

      if (!mounted) return;
      setState(() {
        _project = tree.project;
        _tree = tree;
        _currentNodeId = nodeId;
        _displayedImagePath = imagePath;
        _currentImageSize = imageSize;
        _projectError = null;
        _clearPendingEdit();
        _resetCropRect();
      });

      if (nodeId != null) {
        await _syncWorkflow(nodeId);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingProject = false);
      }
    }
  }

  Future<void> _syncWorkflow(String nodeId) async {
    try {
      final path = await ref
          .read(assetTreeRepositoryProvider)
          .getNodeAncestors(nodeId);
      final lensIds = <String>[];
      for (final edge in path.pathEdges) {
        final id = edge.lensId?.trim();
        if (id != null && id.isNotEmpty && !lensIds.contains(id)) {
          lensIds.add(id);
        }
      }
      if (!mounted) return;
      setState(() {
        _appliedLensIds = lensIds;
        _activeHighlightId = lensIds.isEmpty ? null : lensIds.last;
      });
    } catch (_) {}
  }

  Future<void> _handleUserCommand(String text) async {
    final prompt = text.trim();
    FocusScope.of(context).unfocus();
    if (prompt.isEmpty) return;

    setState(() {
      _promptController.clear();
      final lensId = _selectedLensId ?? 'ai_prompt';
      if (!_appliedLensIds.contains(lensId)) {
        _appliedLensIds = [..._appliedLensIds, lensId];
      }
      _activeHighlightId = lensId;
      _hasPendingEdits = true;
      _pendingLensId = lensId;
      _pendingLensName = _selectedLensName();
      _pendingPrompt = prompt;
      _pendingTagLabel = _buildPromptTag(prompt);
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('指令已加入当前草稿，点击保存后写入版本树')),
    );
  }

  Future<void> _handleSave() async {
    final project = _project;
    final currentNodeId = _currentNodeId;
    final currentPath = _normalizeProjectImagePath(_displayedImagePath);
    if (project == null || currentNodeId == null || currentPath == null) {
      _showError(StateError('当前没有可保存的画面'), '当前没有可保存的画面');
      return;
    }

    try {
      final repository = ref.read(assetTreeRepositoryProvider);
      final currentSize = await _resolveImageSize(currentPath);
      final imageFileSize = isAdaptiveLocalFilePath(currentPath)
          ? await File(normalizeAdaptiveFilePath(currentPath)).length()
          : null;
      final created = await repository.createChildNode(
            projectId: project.projectId,
            input: CreateAssetTreeChildNodeInput(
              parentNodeId: currentNodeId,
              imageUrl: currentPath,
              thumbnailUrl: currentPath,
              width: currentSize?.width.round(),
              height: currentSize?.height.round(),
              fileSize: imageFileSize,
              format: _extractFormat(currentPath),
              lensId: _pendingLensId ?? 'manual_save',
              lensName: _pendingLensName ?? '手动存档',
              userPrompt: _pendingPrompt ?? '用户手动保存当前画面',
              generationParams: {
                'mode': _hasPendingEdits ? 'pending_edit_save' : 'manual_save',
                'tool': _pendingLensId ?? 'manual_save',
                if (_adjustValue != 0) 'adjust_value': _adjustValue,
              },
              status: 'completed',
              metadata: {
                'source': _hasPendingEdits ? 'draft_save' : 'manual_save',
              },
            ),
          );
      await repository.addNodeTag(
        nodeId: created.node.nodeId,
        input: AddAssetTreeTagInput(label: _pendingTagLabel ?? '手动存档'),
      );
      ref.invalidate(assetTreeProjectsProvider);
      ref.invalidate(assetTreeProjectDetailProvider(project.projectId));
      ref.invalidate(assetTreeProjectTreeProvider(project.projectId));
      await _loadProject(project.projectId, preferredNodeId: created.node.nodeId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已保存到资产树历史版本')));
    } catch (error) {
      _showError(error, '保存到资产树失败');
    }
  }

  Future<void> _applyMirror() async {
    await _applyImageTransform(
      lensId: 'mirror_horizontal',
      lensName: '镜像',
      tagLabel: '镜像',
      userPrompt: '水平镜像当前画面',
      transformer: (source) => img.flipHorizontal(source.clone()),
    );
  }

  Future<void> _applyFlip() async {
    await _applyImageTransform(
      lensId: 'flip_vertical',
      lensName: '纵向翻转',
      tagLabel: '纵向翻转',
      userPrompt: '按垂直方向翻转当前画面',
      transformer: (source) => img.flipVertical(source.clone()),
    );
  }

  Future<void> _confirmCrop() async {
    final ratio = _cropAspectRatio;
    await _applyImageTransform(
      lensId: ratio == -1 ? 'free_crop' : 'ratio_crop',
      lensName: ratio == -1 ? '自由裁剪' : '比例裁剪',
      tagLabel: ratio == -1 ? '自由裁剪' : _cropLabel(ratio),
      userPrompt: ratio == -1 ? '自由裁剪当前画面' : '按 ${_cropLabel(ratio)} 裁剪当前画面',
      transformer: (source) {
        final rect = Rect.fromLTWH(
          _cropRect.left * source.width,
          _cropRect.top * source.height,
          _cropRect.width * source.width,
          _cropRect.height * source.height,
        );
        return img.copyCrop(
          source,
          x: rect.left.round(),
          y: rect.top.round(),
          width: rect.width.round().clamp(1, source.width),
          height: rect.height.round().clamp(1, source.height),
        );
      },
    );
  }

  Future<void> _applyImageTransform({
    required String lensId,
    required String lensName,
    required String tagLabel,
    required String userPrompt,
    required img.Image Function(img.Image source) transformer,
  }) async {
    final currentPath = _normalizeProjectImagePath(
      _displayedImagePath ?? _initialImagePath,
    );
    if (currentPath == null) {
      _showError(StateError('当前没有可编辑的画面'), '当前没有可编辑的画面');
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final bytes = await _loadEditableBytes(currentPath);
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw StateError('当前图片格式暂不支持编辑');
      }

      final transformed = transformer(decoded);
      final encoded = Uint8List.fromList(img.encodePng(transformed));
      final savedPath = await LocalMediaStore.persistBytes(
        encoded,
        folder: 'asset_tree',
        prefix: lensId,
        extension: '.png',
      );
      if (!mounted) return;
      setState(() {
        _displayedImagePath = savedPath;
        _currentImageSize = Size(
          transformed.width.toDouble(),
          transformed.height.toDouble(),
        );
        _hasPendingEdits = true;
        _pendingLensId = lensId;
        _pendingLensName = lensName;
        _pendingPrompt = userPrompt;
        _pendingTagLabel = tagLabel;
        _resetCropRect();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$lensName 已应用到当前草稿')),
      );
    } catch (error) {
      _showError(error, '图片处理失败');
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _selectNode(String nodeId) async {
    final project = _project;
    final tree = _tree;
    if (project == null || tree == null) return;
    final node = tree.nodeMap[nodeId];
    if (node == null) return;

    final imagePath = _normalizeProjectImagePath(node.imageUrl);
    final imageSize = await _resolveImageSize(imagePath);

    if (!mounted) return;
    setState(() {
      _currentNodeId = nodeId;
      _displayedImagePath = imagePath;
      _currentImageSize = imageSize;
      _clearPendingEdit();
      _resetCropRect();
    });
    await _syncWorkflow(nodeId);

    try {
      await ref.read(assetTreeRepositoryProvider).switchCurrentNode(
            projectId: project.projectId,
            nodeId: nodeId,
          );
    } catch (error) {
      _showError(error, '切换当前版本失败');
    }
  }

  Future<void> _openNodeSheet(String nodeId) async {
    final project = _project;
    if (project == null || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AssetTreeNodeSheet(
        projectId: project.projectId,
        nodeId: nodeId,
        rootNodeId: project.rootNodeId,
        currentNodeId: _currentNodeId,
        onSelectNode: _selectNode,
        onRefreshProject: () => _loadProject(project.projectId),
      ),
    );
  }

  Future<void> _exportToGallery() async {
    final currentPath = _normalizeProjectImagePath(
      _displayedImagePath ?? _initialImagePath,
    );
    if (currentPath == null) {
      _showError(StateError('当前没有可导出的画面'), '当前没有可导出的画面');
      return;
    }

    try {
      dynamic result;
      if (isAdaptiveLocalFilePath(currentPath)) {
        result = await ImageGallerySaverPlus.saveFile(
          normalizeAdaptiveFilePath(currentPath),
          name: 'muse_${DateTime.now().millisecondsSinceEpoch}',
        );
      } else {
        final bytes = await _loadEditableBytes(currentPath);
        result = await ImageGallerySaverPlus.saveImage(
          bytes,
          quality: 100,
          name: 'muse_${DateTime.now().millisecondsSinceEpoch}',
        );
      }

      final success = result is Map && result['isSuccess'] == true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '已导出到相册' : '导出已提交，请检查系统相册'),
        ),
      );
    } catch (error) {
      _showError(error, '导出失败');
    }
  }

  Future<void> _showAssetTreeManager() async {
    final project = _project;
    if (project == null || !mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.88,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0A0A0E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 46,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 10, 10),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '资产树',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14141A),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Text(
                            '根节点始终是你上传的原图，只有点击保存后，当前草稿才会写入版本树。',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.68),
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF101015),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: _tree == null
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: AppTheme.electricIndigo,
                                    ),
                                  )
                                : Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: ImageHistoryTree(
                                      tree: _tree!,
                                      currentNodeId: _currentNodeId,
                                      onNodeSelected: (nodeId) async {
                                        await _selectNode(nodeId);
                                      },
                                      onNodeLongPress: _openNodeSheet,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAiChat() async {
    final currentPath = _normalizeProjectImagePath(
      _displayedImagePath ?? _initialImagePath,
    );
    final launchPath = currentPath != null && isAdaptiveLocalFilePath(currentPath)
        ? normalizeAdaptiveFilePath(currentPath)
        : widget.selectedImage.path;

    if (!mounted) return;
    final draft = await Navigator.push<ConsultantDraftResult>(
      context,
      MaterialPageRoute(
        builder: (context) => ConsultantScreen(
          selectedImagePath: launchPath,
          returnDraftToPrevious: true,
        ),
      ),
    );

    if (draft == null || !mounted) return;
    final draftSize = await _resolveImageSize(draft.draftImagePath);
    if (!mounted) return;
    setState(() {
      _displayedImagePath = draft.draftImagePath;
      _currentImageSize = draftSize;
      _hasPendingEdits = true;
      _pendingLensId = draft.lensId;
      _pendingLensName = draft.lensName;
      _pendingPrompt = draft.prompt;
      _pendingTagLabel = draft.tagLabel;
      if (!_appliedLensIds.contains(draft.lensId)) {
        _appliedLensIds = <String>[..._appliedLensIds, draft.lensId];
      }
      _activeHighlightId = draft.lensId;
      _activeTool = ToolType.aiChat;
      _resetCropRect();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('AI 草稿已带回当前修图界面')));
  }

  EditorAiToolDefinition get _selectedAiToolDefinition {
    return kEditorAiToolDefinitions.firstWhere(
      (tool) => tool.lensId == _selectedAiToolId,
      orElse: () => kEditorAiToolDefinitions.first,
    );
  }

  void _handleAiToolSelected(String lensId) {
    setState(() {
      _selectedAiToolId = lensId;
      _aiToolParamValues = <String, dynamic>{};
      _aiToolControlValues = <String, dynamic>{};
      _aiToolLocalAssetPaths = <String, String>{};
      _aiToolStatusText = null;
      _aiToolStepResults = const <RouterStepResult>[];
    });
  }

  void _handleAiToolParamChanged(String key, dynamic value) {
    setState(() {
      _aiToolParamValues = <String, dynamic>{..._aiToolParamValues, key: value};
    });
  }

  void _handleAiToolControlChanged(String key, dynamic value) {
    setState(() {
      _aiToolControlValues = <String, dynamic>{..._aiToolControlValues, key: value};
    });
  }

  Future<void> _pickAiToolAsset(String assetName) async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      if (image == null) return;
      final storedPath = await LocalMediaStore.persistXFile(
        image,
        folder: 'ai_toolbox_assets',
        prefix: assetName,
      );
      if (!mounted) return;
      setState(() {
        _aiToolLocalAssetPaths = <String, String>{
          ..._aiToolLocalAssetPaths,
          assetName: storedPath,
        };
        _aiToolStatusText = '$assetName 已准备就绪';
      });
    } catch (error) {
      _showError(error, '选择参考图片失败');
    }
  }

  Future<void> _executeAiTool() async {
    if (_isGenerating) return;
    final tool = _selectedAiToolDefinition;
    setState(() {
      _isGenerating = true;
      _aiToolStatusText = '正在准备 ${tool.title}...';
      _aiToolStepResults = const <RouterStepResult>[];
    });

    try {
      final execution = await _runAiTool(tool);
      final response = execution.response;
      if (_isFatalLensExecutionError(response)) {
        throw StateError(response.executionError!);
      }

      final resultUrl = _pickBestResultUrl(response);
      if (resultUrl == null || resultUrl.trim().isEmpty) {
        throw StateError('后端已执行完成，但没有返回可预览的结果图。');
      }

      final resultPath = await _downloadResultToLocal(
        resultUrl,
        filename: _pickBestResultFilename(response),
        prefix: tool.lensId,
      );
      final resultSize = await _resolveImageSize(resultPath);
      final stepResults = execution.stepResults.isEmpty
          ? response.stepResults
          : execution.stepResults;

      if (!mounted) return;
      setState(() {
        _displayedImagePath = resultPath;
        _currentImageSize = resultSize;
        _hasPendingEdits = true;
        _pendingLensId = tool.lensId;
        _pendingLensName = tool.title;
        _pendingPrompt = _buildAiToolPromptSummary(tool);
        _pendingTagLabel = tool.title;
        if (!_appliedLensIds.contains(tool.lensId)) {
          _appliedLensIds = <String>[..._appliedLensIds, tool.lensId];
        }
        _activeHighlightId = tool.lensId;
        _aiToolStepResults = stepResults;
        _aiToolStatusText =
            execution.statusText ??
            '${tool.title} 已完成，返回 ${stepResults.length} 个结果节点';
        _resetCropRect();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${tool.title} 已应用到当前草稿')));
    } catch (error) {
      final message = _messageFromError(error, '${tool.title} 执行失败');
      if (mounted) {
        setState(() => _aiToolStatusText = message);
      }
      _showError(error, '${tool.title} 执行失败');
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<_AiToolExecutionResult> _runAiTool(
    EditorAiToolDefinition tool,
  ) async {
    switch (tool.lensId) {
      case 'lens_lora_filter':
        return _runApplyControlsAiTool(tool);
      case 'lens_style':
        return _runApplyControlsAiTool(
          tool,
          requiredAssetNames: const <String>['style_reference_image'],
        );
      case 'lens_relighting':
        return _runRelightingWorkflow(tool);
      case 'lens_depth_of_field':
        return _runDepthOfFieldWorkflow(tool);
      case 'lens_flux_inpaint':
        return _runInpaintWorkflow(tool);
      default:
        return _runDirectAiTool(tool);
    }
  }

  Future<_AiToolExecutionResult> _runDirectAiTool(
    EditorAiToolDefinition tool,
  ) async {
    final repository = ref.read(lensesRepositoryProvider);
    final assets = <String, String>{};
    if (tool.lensId != 'lens_flux_text2image') {
      assets['base_image'] = await _ensureUploadedCurrentEditorImage();
    }
    for (final slot in tool.assetSlots) {
      final rawPath = _aiToolLocalAssetPaths[slot.assetName];
      if (rawPath == null || rawPath.trim().isEmpty) {
        throw StateError('${slot.label} 还没有选择');
      }
      assets[slot.assetName] = await _ensureUploadedAssetPath(rawPath);
    }

    setState(() => _aiToolStatusText = '正在运行 ${tool.title}...');
    final response = await repository.runLens(
      lensId: tool.lensId,
      assets: assets,
      params: _resolvedAiToolParams(tool),
    );
    return _AiToolExecutionResult(
      response: response,
      statusText: '${tool.title} 已执行完成',
    );
  }

  Future<_AiToolExecutionResult> _runApplyControlsAiTool(
    EditorAiToolDefinition tool, {
    List<String> requiredAssetNames = const <String>[],
  }) async {
    final repository = ref.read(lensesRepositoryProvider);
    final assets = <String, String>{};
    if (tool.lensId != 'lens_flux_text2image') {
      assets['base_image'] = await _ensureUploadedCurrentEditorImage();
    }
    for (final assetName in requiredAssetNames) {
      final rawPath = _aiToolLocalAssetPaths[assetName];
      if (rawPath == null || rawPath.trim().isEmpty) {
        String label = assetName;
        for (final slot in tool.assetSlots) {
          if (slot.assetName == assetName) {
            label = slot.label;
            break;
          }
        }
        throw StateError('$label 还没有选择');
      }
      assets[assetName] = await _ensureUploadedAssetPath(rawPath);
    }

    final controlValues = switch (tool.lensId) {
      'lens_lora_filter' => <String, dynamic>{
          'filter_selector':
              _aiToolControlValues['filter_selector']?.toString() ?? 'ghibli',
          'filter_opacity':
              (_aiToolControlValues['filter_opacity'] as num?)?.toDouble() ??
                  0.8,
        },
      'lens_style' => <String, dynamic>{
          'style_intensity':
              (_aiToolControlValues['style_intensity'] as num?)?.toDouble() ??
                  0.8,
          'structure_preservation':
              (_aiToolControlValues['structure_preservation'] as num?)
                  ?.toDouble() ??
                  0.72,
        },
      _ => _aiToolControlValues,
    };

    setState(() => _aiToolStatusText = '正在应用 ${tool.title} 控件...');
    final response = await repository.applyControls(
      lensId: tool.lensId,
      assets: assets,
      currentParams: _resolvedAiToolParams(tool),
      controlValues: controlValues,
      execute: true,
    );
    final execution = response.execution;
    if (execution == null) {
      throw StateError('${tool.title} 控件已翻译，但后端没有返回执行结果');
    }
    return _AiToolExecutionResult(
      response: execution,
      stepResults: execution.stepResults,
      statusText: response.explanations.isEmpty
          ? '${tool.title} 已执行完成'
          : response.explanations.join(' '),
    );
  }

  Future<_AiToolExecutionResult> _runRelightingWorkflow(
    EditorAiToolDefinition tool,
  ) async {
    final repository = ref.read(lensesRepositoryProvider);
    final baseImage = await _ensureUploadedCurrentEditorImage();

    setState(() => _aiToolStatusText = '正在提取深度图...');
    final depthResult = await repository.runLens(
      lensId: 'lens_depth_extract',
      assets: <String, String>{'base_image': baseImage},
      params: const <String, dynamic>{},
    );
    if (_isFatalLensExecutionError(depthResult)) {
      throw StateError(depthResult.executionError!);
    }
    final depthMapFilename = _pickBestResultFilename(depthResult);
    if (depthMapFilename == null || depthMapFilename.trim().isEmpty) {
      throw StateError('深度提取完成，但没有拿到 depth_map 文件');
    }

    setState(() => _aiToolStatusText = '正在重塑光影关系...');
    final response = await repository.applyControls(
      lensId: tool.lensId,
      assets: <String, String>{
        'base_image': baseImage,
        'depth_map': depthMapFilename,
      },
      currentParams: <String, dynamic>{
        'prompt':
            _aiToolControlValues['scene_hint']?.toString().trim().isNotEmpty ==
                true
            ? _aiToolControlValues['scene_hint'].toString().trim()
            : 'cinematic relighting, preserve the subject and composition',
        'cfg': 1.2,
      },
      controlValues: <String, dynamic>{
        'light_orb': <String, dynamic>{
          'x': (_aiToolControlValues['light_x'] as num?)?.toDouble() ?? 0.75,
          'y': (_aiToolControlValues['light_y'] as num?)?.toDouble() ?? 0.28,
          'z': (_aiToolControlValues['light_z'] as num?)?.toDouble() ?? 0.72,
          'intensity':
              (_aiToolControlValues['light_intensity'] as num?)?.toDouble() ??
                  0.82,
          'color_temperature':
              ((_aiToolControlValues['light_temperature'] as num?)?.toDouble() ??
                      4200)
                  .round(),
          'scene_hint':
              _aiToolControlValues['scene_hint']?.toString().trim().isNotEmpty ==
                  true
              ? _aiToolControlValues['scene_hint'].toString().trim()
              : 'cinematic relighting',
        },
      },
      execute: true,
    );
    final execution = response.execution;
    if (execution == null) {
      throw StateError('光影控件已翻译，但后端没有返回执行结果');
    }
    return _AiToolExecutionResult(
      response: execution,
      stepResults: <RouterStepResult>[
        ...depthResult.stepResults,
        ...execution.stepResults,
      ],
      statusText: response.explanations.isEmpty
          ? '${tool.title} 已执行完成'
          : response.explanations.join(' '),
    );
  }

  Future<_AiToolExecutionResult> _runDepthOfFieldWorkflow(
    EditorAiToolDefinition tool,
  ) async {
    final repository = ref.read(lensesRepositoryProvider);
    final baseImage = await _ensureUploadedCurrentEditorImage();

    setState(() => _aiToolStatusText = '正在提取景深所需的深度图...');
    final depthResult = await repository.runLens(
      lensId: 'lens_depth_extract',
      assets: <String, String>{'base_image': baseImage},
      params: const <String, dynamic>{},
    );
    if (_isFatalLensExecutionError(depthResult)) {
      throw StateError(depthResult.executionError!);
    }
    final depthMapFilename = _pickBestResultFilename(depthResult);
    if (depthMapFilename == null || depthMapFilename.trim().isEmpty) {
      throw StateError('深度提取完成，但没有拿到 depth_map 文件');
    }

    setState(() => _aiToolStatusText = '正在生成镜头景深效果...');
    final response = await repository.applyControls(
      lensId: tool.lensId,
      assets: <String, String>{
        'base_image': baseImage,
        'depth_map': depthMapFilename,
      },
      currentParams: <String, dynamic>{
        'vignette_intensity': 0.16,
        'halation_strength': 0.08,
      },
      controlValues: <String, dynamic>{
        'tap_to_focus': <String, dynamic>{
          'focus_depth_value':
              (_aiToolControlValues['focus_depth_value'] as num?)?.toDouble() ??
                  0.42,
        },
        'aperture_dial': <String, dynamic>{
          'value':
              (_aiToolControlValues['aperture_value'] as num?)?.toDouble() ??
                  0.6,
        },
      },
      execute: true,
    );
    final execution = response.execution;
    if (execution == null) {
      throw StateError('景深控件已翻译，但后端没有返回执行结果');
    }
    return _AiToolExecutionResult(
      response: execution,
      stepResults: <RouterStepResult>[
        ...depthResult.stepResults,
        ...execution.stepResults,
      ],
      statusText: response.explanations.isEmpty
          ? '${tool.title} 已执行完成'
          : response.explanations.join(' '),
    );
  }

  Future<_AiToolExecutionResult> _runInpaintWorkflow(
    EditorAiToolDefinition tool,
  ) async {
    final repository = ref.read(lensesRepositoryProvider);
    final targetPrompt =
        _aiToolControlValues['target_prompt']?.toString().trim() ?? '';
    final replacementPrompt = _resolvedAiToolParams(tool)['prompt']?.toString().trim() ?? '';
    if (targetPrompt.isEmpty) {
      throw StateError('请先描述要选中的区域');
    }
    if (replacementPrompt.isEmpty) {
      throw StateError('请先描述希望重绘成什么内容');
    }

    final baseImage = await _ensureUploadedCurrentEditorImage();
    setState(() => _aiToolStatusText = '正在根据文字定位需要重绘的区域...');
    final maskResult = await repository.runLens(
      lensId: 'lens_sam2_matting',
      assets: <String, String>{'base_image': baseImage},
      params: <String, dynamic>{'prompt': targetPrompt},
    );
    if (_isFatalLensExecutionError(maskResult)) {
      throw StateError(maskResult.executionError!);
    }
    final maskFilename = _pickBestResultFilename(maskResult);
    if (maskFilename == null || maskFilename.trim().isEmpty) {
      throw StateError('遮罩提取完成，但没有拿到 mask 文件');
    }

    setState(() => _aiToolStatusText = '正在对白色遮罩区域进行局部重绘...');
    final runResult = await repository.runLens(
      lensId: tool.lensId,
      assets: <String, String>{
        'base_image': baseImage,
        'mask': maskFilename,
      },
      params: _resolvedAiToolParams(tool),
    );
    return _AiToolExecutionResult(
      response: runResult,
      stepResults: <RouterStepResult>[
        ...maskResult.stepResults,
        ...runResult.stepResults,
      ],
      statusText: '${tool.title} 已完成局部重绘',
    );
  }

  Map<String, dynamic> _resolvedAiToolParams(EditorAiToolDefinition tool) {
    final params = <String, dynamic>{..._aiToolParamValues};
    return switch (tool.lensId) {
      'lens_upscale_4x' => <String, dynamic>{
          'upscale_by': (params['upscale_by'] as num?)?.toDouble() ?? 4.0,
          'denoise': (params['denoise'] as num?)?.toDouble() ?? 0.25,
          'steps': (params['steps'] as num?)?.round() ?? 20,
          'cfg': (params['cfg'] as num?)?.toDouble() ?? 7.0,
          'tile_width': 1024,
          'tile_height': 1024,
          'prompt': params['prompt']?.toString().trim().isNotEmpty == true
              ? params['prompt'].toString().trim()
              : 'ultra sharp details, clean edges, refined textures',
        },
      'lens_flux_edit' => <String, dynamic>{
          'prompt': params['prompt']?.toString().trim().isNotEmpty == true
              ? params['prompt'].toString().trim()
              : 'refresh the background with a cinematic and polished atmosphere',
          'steps': (params['steps'] as num?)?.round() ?? 24,
          'cfg': (params['cfg'] as num?)?.toDouble() ?? 1.1,
        },
      'lens_style' => <String, dynamic>{
          'prompt': params['prompt']?.toString().trim().isNotEmpty == true
              ? params['prompt'].toString().trim()
              : 'preserve the main subject and overall composition',
          'steps': (params['steps'] as num?)?.round() ?? 24,
          'cfg': (params['cfg'] as num?)?.toDouble() ?? 1.0,
        },
      'lens_flux_inpaint' => <String, dynamic>{
          'prompt': params['prompt']?.toString().trim() ?? '',
          'steps': (params['steps'] as num?)?.round() ?? 22,
          'cfg': (params['cfg'] as num?)?.toDouble() ?? 1.0,
        },
      'lens_sam2_matting' => <String, dynamic>{
          'prompt': params['prompt']?.toString().trim() ?? '',
        },
      'lens_flux_reference' || 'lens_flux_two_reference' => <String, dynamic>{
          'prompt': params['prompt']?.toString().trim().isNotEmpty == true
              ? params['prompt'].toString().trim()
              : 'preserve the subject while following the references',
          'steps': (params['steps'] as num?)?.round() ?? 24,
          'cfg': (params['cfg'] as num?)?.toDouble() ?? 1.1,
        },
      'lens_watermark' => <String, dynamic>{
          'text': params['text']?.toString().trim().isNotEmpty == true
              ? params['text'].toString().trim()
              : 'MuseLens',
          'font_size': (params['font_size'] as num?)?.round() ?? 36,
          'align': params['align']?.toString() ?? 'bottom',
          'justify': params['justify']?.toString() ?? 'right',
          'margins': (params['margins'] as num?)?.round() ?? 28,
        },
      'lens_flux_text2image' => <String, dynamic>{
          'prompt': params['prompt']?.toString().trim().isNotEmpty == true
              ? params['prompt'].toString().trim()
              : 'a premium editorial still life photo with cinematic lighting',
          'width': (params['width'] as num?)?.round() ?? 1024,
          'height': (params['height'] as num?)?.round() ?? 1024,
          'steps': (params['steps'] as num?)?.round() ?? 28,
          'cfg': (params['cfg'] as num?)?.toDouble() ?? 1.0,
        },
      _ => params,
    };
  }

  String _buildAiToolPromptSummary(EditorAiToolDefinition tool) {
    final promptLike = <String>[
      _aiToolParamValues['prompt']?.toString() ?? '',
      _aiToolParamValues['text']?.toString() ?? '',
      _aiToolControlValues['scene_hint']?.toString() ?? '',
      _aiToolControlValues['target_prompt']?.toString() ?? '',
    ].firstWhere(
      (value) => value.trim().isNotEmpty,
      orElse: () => tool.title,
    );
    return promptLike.trim().isEmpty ? tool.title : promptLike.trim();
  }

  Future<String> _ensureUploadedCurrentEditorImage() async {
    final currentPath = _displayedImagePath ?? _initialImagePath;
    if (currentPath != null && isAdaptiveLocalFilePath(currentPath)) {
      return _ensureUploadedAssetPath(currentPath);
    }
    return _ensureUploadedAssetPath(widget.selectedImage.path);
  }

  Future<String> _ensureUploadedAssetPath(String rawPath) async {
    final localPath = await _ensureLocalUploadPath(rawPath);
    final cached = _uploadedAiAssetCache[localPath];
    if (cached != null && cached.trim().isNotEmpty) {
      return cached;
    }
    final upload = await ref
        .read(routerRepositoryProvider)
        .uploadBaseImage(filePath: localPath);
    _uploadedAiAssetCache[localPath] = upload.filename;
    return upload.filename;
  }

  Future<String> _ensureLocalUploadPath(String rawPath) async {
    final normalized = rawPath.trim();
    if (normalized.isEmpty) {
      throw StateError('没有可上传的图片');
    }
    if (isAdaptiveLocalFilePath(normalized)) {
      return normalizeAdaptiveFilePath(normalized);
    }
    if (normalized.startsWith('http')) {
      final http = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 5),
        ),
      );
      final download = await http.get<List<int>>(
        normalized,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = download.data;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('远程图片下载失败');
      }
      final savedPath = await LocalMediaStore.persistBytes(
        Uint8List.fromList(bytes),
        folder: 'ai_toolbox_downloads',
        prefix: 'remote_asset',
        extension: _guessExtension(normalized),
      );
      return normalizeAdaptiveFilePath(savedPath);
    }
    if (normalized.startsWith('assets/')) {
      throw StateError('当前图片仍是内置资源，请重新导入一张本地图片后再使用 AI 工具箱');
    }
    return normalized;
  }

  Future<String> _downloadResultToLocal(
    String resultUrl, {
    String? filename,
    required String prefix,
  }) async {
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
    if (bytes == null || bytes.isEmpty) {
      throw StateError('结果图下载失败');
    }
    return LocalMediaStore.persistBytes(
      Uint8List.fromList(bytes),
      folder: 'ai_tool_results',
      prefix: prefix,
      extension: _guessExtension(filename ?? resultUrl),
    );
  }

  String? _pickBestResultUrl(LensToolRunResponse response) {
    final direct = response.resultUrl?.trim();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    for (final step in response.stepResults.reversed) {
      for (final output in step.outputs.reversed) {
        final url = output.url?.trim();
        if (url != null && url.isNotEmpty) {
          return url;
        }
      }
    }
    return null;
  }

  String? _pickBestResultFilename(LensToolRunResponse response) {
    final direct = response.resultFilename?.trim();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    for (final step in response.stepResults.reversed) {
      for (final output in step.outputs.reversed) {
        final filename = output.filename.trim();
        if (filename.isNotEmpty) {
          return filename;
        }
      }
    }
    return null;
  }

  bool _hasUsableLensOutput(LensToolRunResponse response) {
    if (_pickBestResultUrl(response)?.trim().isNotEmpty == true) {
      return true;
    }
    if (_pickBestResultFilename(response)?.trim().isNotEmpty == true) {
      return true;
    }
    for (final step in response.stepResults) {
      if (step.outputs.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  bool _isFatalLensExecutionError(LensToolRunResponse response) {
    if (!response.hasExecutionError) {
      return false;
    }
    return !_hasUsableLensOutput(response);
  }

  String _guessExtension(String source) {
    final normalized = source.split('?').first.trim();
    final dotIndex = normalized.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == normalized.length - 1) {
      return '.png';
    }
    final extension = normalized.substring(dotIndex).toLowerCase();
    if (extension.length > 10) {
      return '.png';
    }
    return extension;
  }

  Future<AssetTreeImagePayload> _buildFilePayload(
    File file,
    String storedPath,
  ) async {
    final size = await _readImageSize(file);
    return AssetTreeImagePayload(
      imageUrl: storedPath,
      thumbnailUrl: storedPath,
      width: size?.$1,
      height: size?.$2,
      fileSize: await file.length(),
      format: _extractFormat(file.path),
      metadata: const {'source': 'upload'},
    );
  }

  Future<(int, int)?> _readImageSize(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return (frame.image.width, frame.image.height);
    } catch (_) {
      return null;
    }
  }

  String _extractFormat(String path) {
    final normalized = path.replaceAll('\\', '/');
    final dotIndex = normalized.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == normalized.length - 1) return 'jpg';
    return normalized.substring(dotIndex + 1).toLowerCase();
  }

  String _buildDefaultProjectName() => '编辑项目';

  Future<void> _seedInitialDraftIfNeeded() async {
    final draftPath = _normalizeProjectImagePath(widget.initialDraftImagePath);
    if (draftPath == null || draftPath.trim().isEmpty) return;

    final draftSize = await _resolveImageSize(draftPath);
    if (!mounted) return;
    setState(() {
      _displayedImagePath = draftPath;
      _currentImageSize = draftSize;
      _hasPendingEdits = true;
      _pendingLensId = widget.initialDraftLensId ?? 'router_generate';
      _pendingLensName = widget.initialDraftLensName ?? 'AI 修图';
      _pendingPrompt =
          widget.initialPrompt?.trim().isNotEmpty == true
              ? widget.initialPrompt!.trim()
              : 'AI 修图生成结果';
      _pendingTagLabel = widget.initialDraftTagLabel ?? 'AI 草稿';
      _activeHighlightId = widget.initialDraftLensId;
      _resetCropRect();
    });
  }

  Future<Size?> _resolveImageSize(String? path) async {
    if (path == null || path.trim().isEmpty) return null;
    if (isAdaptiveLocalFilePath(path)) {
      final file = File(normalizeAdaptiveFilePath(path));
      if (!await file.exists()) return null;
      final size = await _readImageSize(file);
      if (size == null) return null;
      return Size(size.$1.toDouble(), size.$2.toDouble());
    }
    try {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> _loadEditableBytes(String path) async {
    if (isAdaptiveLocalFilePath(path)) {
      return File(normalizeAdaptiveFilePath(path)).readAsBytes();
    }
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List();
  }

  void _resetCropRect([double? ratio]) {
    final effectiveRatio = ratio ?? _cropAspectRatio;
    Rect next = const Rect.fromLTWH(0.12, 0.1, 0.76, 0.76);
    final normalizedRatio = effectiveRatio == 0
        ? ((_currentImageSize?.width ?? 1) / (_currentImageSize?.height ?? 1))
        : effectiveRatio;
    if (normalizedRatio > 0) {
      const maxWidth = 0.82;
      const maxHeight = 0.72;
      double width = maxWidth;
      double height = width / normalizedRatio;
      if (height > maxHeight) {
        height = maxHeight;
        width = height * normalizedRatio;
      }
      next = Rect.fromLTWH(
        (1 - width) / 2,
        (1 - height) / 2,
        width,
        height,
      );
    } else if (normalizedRatio == -1) {
      next = const Rect.fromLTWH(0.1, 0.1, 0.8, 0.76);
    }
    _cropRect = next;
  }

  void _updateCropRect(Rect rect) {
    setState(() => _cropRect = rect);
  }

  void _clearPendingEdit() {
    _hasPendingEdits = false;
    _pendingLensId = null;
    _pendingLensName = null;
    _pendingPrompt = null;
    _pendingTagLabel = null;
  }

  String _cropLabel(double ratio) {
    if ((ratio - 1).abs() < 0.001) return '1:1';
    if ((ratio - (3 / 4)).abs() < 0.001) return '3:4';
    if ((ratio - (9 / 16)).abs() < 0.001) return '9:16';
    if ((ratio - (16 / 9)).abs() < 0.001) return '16:9';
    return '比例裁剪';
  }

  String? _normalizeProjectImagePath(String? path) {
    final trimmed = path?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http') ||
        trimmed.startsWith('file://') ||
        trimmed.startsWith('assets/')) {
      return trimmed;
    }
    if (isAdaptiveLocalFilePath(trimmed)) {
      return 'file://${normalizeAdaptiveFilePath(trimmed)}';
    }
    return trimmed;
  }

  String _selectedLensName() {
    return switch (_selectedLensId) {
      'template_ghibli' => '宫崎骏风格',
      'template_clean' => '背景清理',
      'template_portrait' => '人像通透',
      'template_light' => '电影光影',
      'lens_matting' => '智能抠图',
      'lens_crop' => '智能裁剪',
      'lens_upscale' => '超清修复',
      'lens_face_beauty' => '人像美化',
      'lens_replace' => '涂抹消除',
      'lens_background' => '背景替换',
      'lens_relight' => '光影重塑',
      'lens_color_grade' => '氛围调色',
      _ => 'AI 修图',
    };
  }

  String _buildPromptTag(String prompt) {
    final clean = prompt.replaceAll('\n', ' ').trim();
    if (clean.length <= 8) return clean;
    return '${clean.substring(0, 8)}...';
  }

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF14141A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            '修图提示',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            '1. 先在底部选择一个 AI 模板或工具。\n'
            '2. 再输入更具体的修图描述。\n'
            '3. 只有点击保存后，当前草稿才会写入资产树。',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              height: 1.6,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );
  }

  void _showExportHint() {
    _exportToGallery();
  }

  @override
  Widget build(BuildContext context) {
    if (_projectError != null && _tree == null && !_isBootstrapping) {
      return Scaffold(
        backgroundColor: const Color(0xFF050507),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 54,
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _projectError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _bootstrapInitialProject,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.electricIndigo,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final busy = _isBootstrapping || _isLoadingProject || _isGenerating;

    return Scaffold(
      backgroundColor: const Color(0xFF050507),
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A1324), Color(0xFF060609), Color(0xFF060609)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, 0.24, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              EditorHeader(
                onBack: () => Navigator.pop(context),
                onHelp: _showHelp,
                onOpenAssetTree: _showAssetTreeManager,
                onSave: _handleSave,
                onExport: _showExportHint,
              ),
              Expanded(
                child: EditorCanvas(
                  originalImage: widget.selectedImage,
                  currentImagePath: _displayedImagePath,
                  imagePixelSize: _currentImageSize,
                  isGenerating: busy,
                  activeTool: _activeTool,
                  onFlipHorizontal: _applyFlip,
                  onMirror: _applyMirror,
                  cropAspectRatio: _cropAspectRatio == 0 && _currentImageSize != null
                      ? _currentImageSize!.width / _currentImageSize!.height
                      : _cropAspectRatio,
                  cropRect: _cropRect,
                  onCropRectChanged: _updateCropRect,
                  onConfirmCrop: _confirmCrop,
                ),
              ),
              EditorToolsPanel(
                activeTool: _activeTool,
                aiToolboxPanel: EditorAiToolboxPanel(
                  selectedToolId: _selectedAiToolId,
                  paramValues: _aiToolParamValues,
                  controlValues: _aiToolControlValues,
                  localAssetPaths: _aiToolLocalAssetPaths,
                  isRunning: busy,
                  statusText: _aiToolStatusText,
                  stepResults: _aiToolStepResults,
                  onToolSelected: _handleAiToolSelected,
                  onParamChanged: _handleAiToolParamChanged,
                  onControlChanged: _handleAiToolControlChanged,
                  onPickAsset: _pickAiToolAsset,
                  onExecute: _executeAiTool,
                ),
                promptController: _promptController,
                isGenerating: busy,
                appliedLensIds: _appliedLensIds,
                activeHighlightId: _activeHighlightId,
                onOpenAiChat: _openAiChat,
                onToolChanged: (tool) => setState(() {
                  _activeTool = tool;
                  if (tool == ToolType.crop) {
                    _resetCropRect();
                  }
                }),
                onSendPrompt: () => _handleUserCommand(_promptController.text),
                cropAspectRatio: _cropAspectRatio,
                onCropRatioChanged: (ratio) => setState(() {
                  _cropAspectRatio = ratio;
                  _resetCropRect(ratio);
                }),
                activeAdjustParam: _activeAdjustParam,
                adjustValue: _adjustValue,
                onAdjustParamChanged: (param) => setState(() {
                  _activeAdjustParam = param;
                  _adjustValue = 0;
                }),
                onAdjustValueChanged: (value) =>
                    setState(() => _adjustValue = value),
                selectedLensId: _selectedLensId,
                onLensSelected: (id) => setState(() => _selectedLensId = id),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(Object error, String fallback) {
    final message = _messageFromError(error, fallback);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _messageFromError(Object error, String fallback) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic> && data['detail'] != null) {
        return data['detail'].toString();
      }
      if (error.message != null && error.message!.trim().isNotEmpty) {
        return error.message!;
      }
    }
    if (error is StateError) {
      return error.message;
    }
    return fallback;
  }
}

class _AiToolExecutionResult {
  const _AiToolExecutionResult({
    required this.response,
    this.stepResults = const <RouterStepResult>[],
    this.statusText,
  });

  final LensToolRunResponse response;
  final List<RouterStepResult> stepResults;
  final String? statusText;
}
