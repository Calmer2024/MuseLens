import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/local_media_store.dart';
import '../../../data/models/asset_tree_models.dart';
import '../../../data/repositories/asset_tree_repository.dart';
import '../../widgets/editor/asset_tree_node_sheet.dart';
import '../../widgets/editor/chat_history_drawer.dart';
import '../../widgets/editor/editor_canvas.dart';
import '../../widgets/editor/editor_header.dart';
import '../../widgets/editor/editor_tools_panel.dart';
import '../../widgets/editor/image_history_tree.dart';
import '../../widgets/shared/adaptive_media.dart';

enum ToolType { none, crop, adjust, lens }

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({
    super.key,
    required this.selectedImage,
    this.autoStartSimulation = false,
  });

  final File selectedImage;
  final bool autoStartSimulation;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _promptController = TextEditingController();

  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;

  bool _isFlipped = false;
  bool _isGenerating = false;
  bool _isBootstrapping = true;
  bool _isLoadingProject = false;

  Uint8List? _resultImage;
  String? _displayedImagePath;
  String? _initialImagePath;
  String? _projectError;

  ToolType _activeTool = ToolType.none;
  double _cropAspectRatio = -1;
  String _activeAdjustParam = 'Exposure';
  double _adjustValue = 0.0;
  String? _selectedLensId;

  List<String> _appliedLensIds = <String>[];
  String? _activeHighlightId;

  AssetTreeProject? _project;
  AssetTreeProjectTree? _tree;
  String? _currentNodeId;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );
    Future<void>.microtask(_bootstrapInitialProject);
  }

  @override
  void dispose() {
    _promptController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  Future<void> _bootstrapInitialProject() async {
    setState(() {
      _projectError = null;
      _isBootstrapping = true;
    });

    try {
      await _createProjectFromFile(
        widget.selectedImage,
        runAutoSimulation: widget.autoStartSimulation,
      );
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

  Future<void> _createProjectFromFile(
    File source, {
    bool runAutoSimulation = false,
  }) async {
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
        description: '从编辑器创建的修图资产树项目',
      ),
    );
    final rootNode = await repository.addRootNode(
      projectId: project.projectId,
      input: payload,
    );

    _initialImagePath = storedPath;
    await _loadProject(project.projectId, preferredNodeId: rootNode.nodeId);
    if (runAutoSimulation && mounted) {
      unawaited(_runSimulationSequence());
    }
  }

  Future<void> _createProjectFromCurrentFrame() async {
    final currentPath = _normalizeProjectImagePath(
      _displayedImagePath ?? _initialImagePath,
    );
    if (currentPath == null) {
      throw StateError('当前没有可保存的画面');
    }

    final repository = ref.read(assetTreeRepositoryProvider);
    final project = await repository.createProject(
      CreateAssetTreeProjectInput(
        name: '${_project?.displayName ?? '新项目'} 副本',
        description: '从当前画面另存的新项目',
      ),
    );
    await repository.addRootNode(
      projectId: project.projectId,
      input: AssetTreeImagePayload(
        imageUrl: currentPath,
        thumbnailUrl: currentPath,
        metadata: const {'source': 'duplicate'},
      ),
    );
    await _loadProject(project.projectId);
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

      if (!mounted) return;
      setState(() {
        _project = tree.project;
        _tree = tree;
        _currentNodeId = nodeId;
        _displayedImagePath =
            node?.imageUrl ?? tree.project.coverUrl ?? _initialImagePath;
        _projectError = null;
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

  Future<void> _runSimulationSequence() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _activeTool = ToolType.lens);

    await _generateNode(
      lensId: 'lens_face_beauty',
      lensName: '美颜',
      resultImagePath: 'assets/images/simulation/beauty.png',
      tagLabel: '美颜',
      prompt: '提升人物面部质感',
    );
    await _generateNode(
      lensId: 'lens_background',
      lensName: '背景替换',
      resultImagePath: 'assets/images/simulation/scenery.png',
      tagLabel: '背景替换',
      prompt: '把背景替换成海边黄昏',
    );
    await _generateNode(
      lensId: 'lens_relight',
      lensName: '光影重塑',
      resultImagePath: 'assets/images/simulation/lighting.png',
      tagLabel: '光影重塑',
      prompt: '补充夕阳暖光',
    );
  }

  Future<void> _handleUserCommand(String text) async {
    final prompt = text.trim();
    FocusScope.of(context).unfocus();
    _promptController.clear();
    if (prompt.isEmpty) return;

    if (prompt.contains('背景') || prompt.contains('埃菲尔')) {
      await _generateNode(
        lensId: 'lens_background',
        lensName: '背景替换',
        resultImagePath: 'assets/images/simulation/branch2.png',
        tagLabel: '埃菲尔背景',
        prompt: prompt,
      );
      return;
    }

    await _generateNode(
      lensId: _selectedLensId ?? 'lens_relight',
      lensName: 'AI 调整',
      resultImagePath: 'assets/images/simulation/branch1.png',
      tagLabel: '指令调整',
      prompt: prompt,
    );
  }

  Future<void> _generateNode({
    required String lensId,
    required String lensName,
    required String resultImagePath,
    required String tagLabel,
    required String prompt,
  }) async {
    final project = _project;
    final currentNodeId = _currentNodeId;
    if (project == null || currentNodeId == null) return;

    setState(() {
      _isGenerating = true;
      if (!_appliedLensIds.contains(lensId)) {
        _appliedLensIds = [..._appliedLensIds, lensId];
      }
      _activeHighlightId = lensId;
    });

    try {
      final repository = ref.read(assetTreeRepositoryProvider);
      final created = await repository.createChildNode(
            projectId: project.projectId,
            input: CreateAssetTreeChildNodeInput(
              parentNodeId: currentNodeId,
              imageUrl: resultImagePath,
              thumbnailUrl: resultImagePath,
              lensId: lensId,
              lensName: lensName,
              userPrompt: prompt,
              parameters: {'prompt': prompt},
              generationParams: {'prompt': prompt},
              museDna: {
                'steps': [
                  {'lens_id': lensId, 'prompt': prompt},
                ],
              },
              status: 'generating',
              metadata: const {'source': 'generation'},
            ),
          );
      await _loadProject(project.projectId, preferredNodeId: created.node.nodeId);
      await Future<void>.delayed(const Duration(seconds: 2));
      await repository.updateNodeStatus(
        nodeId: created.node.nodeId,
        input: UpdateAssetTreeNodeStatusInput(
          status: 'completed',
          imageUrl: resultImagePath,
          thumbnailUrl: resultImagePath,
          executionTimeMs: 2000,
        ),
      );
      await repository.addNodeTag(
        nodeId: created.node.nodeId,
        input: AddAssetTreeTagInput(label: tagLabel),
      );
      await _loadProject(project.projectId, preferredNodeId: created.node.nodeId);
    } catch (error) {
      _showError(error, '生成节点失败');
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
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
      final created = await repository.createChildNode(
            projectId: project.projectId,
            input: CreateAssetTreeChildNodeInput(
              parentNodeId: currentNodeId,
              imageUrl: currentPath,
              thumbnailUrl: currentPath,
              lensId: 'manual_save',
              lensName: '手动存档',
              userPrompt: '用户手动保存当前画面',
              generationParams: const {'mode': 'manual_save'},
              status: 'completed',
              metadata: const {'source': 'manual_save'},
            ),
          );
      await repository.addNodeTag(
        nodeId: created.node.nodeId,
        input: const AddAssetTreeTagInput(label: '手动存档'),
      );
      await _loadProject(project.projectId, preferredNodeId: created.node.nodeId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已保存到资产树历史版本')));
    } catch (error) {
      _showError(error, '保存到资产树失败');
    }
  }

  Future<void> _selectNode(String nodeId) async {
    final project = _project;
    final tree = _tree;
    if (project == null || tree == null) return;
    final node = tree.nodeMap[nodeId];
    if (node == null) return;

    setState(() {
      _currentNodeId = nodeId;
      _displayedImagePath = node.imageUrl;
      _resultImage = null;
    });
    if (_isFlipped) _toggleFlip();
    unawaited(_syncWorkflow(nodeId));

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

  String _buildDefaultProjectName() {
    final now = DateTime.now();
    return '修图项目 ${now.month}/${now.day} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
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

  void _toggleFlip() {
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() => _isFlipped = !_isFlipped);
  }

  @override
  Widget build(BuildContext context) {
    if (_projectError != null && _tree == null && !_isBootstrapping) {
      return Scaffold(
        backgroundColor: Colors.white,
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
                    color: Colors.black.withValues(alpha: 0.18),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _projectError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: _bootstrapInitialProject,
                    style: ElevatedButton.styleFrom(
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

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      drawer: ChatHistoryDrawer(
        currentProjectId: _project?.projectId,
        onOpenProject: _loadProject,
        onCreateProjectFromCurrentFrame: _createProjectFromCurrentFrame,
      ),
      body: SafeArea(
        child: GestureDetector(
          onLongPress: _toggleFlip,
          child: AnimatedBuilder(
            animation: _flipAnimation,
            builder: (context, child) {
              final angle = _flipAnimation.value * math.pi;
              final transform = Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(angle);
              return Transform(
                transform: transform,
                alignment: Alignment.center,
                child: _flipAnimation.value < 0.5
                    ? _buildFrontSide()
                    : Transform(
                        transform: Matrix4.identity()..rotateY(math.pi),
                        alignment: Alignment.center,
                        child: _buildBackSide(),
                      ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFrontSide() {
    final busy = _isBootstrapping || _isLoadingProject || _isGenerating;
    return Column(
      children: [
        EditorHeader(
          onBack: () => Navigator.pop(context),
          onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
          onUndo: () {},
          onRedo: () {},
          onSave: _handleSave,
          onExport: () {},
        ),
        if (_project != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _project!.displayName,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${_project!.nodeCount} 个版本',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.42),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: EditorCanvas(
            originalImage: widget.selectedImage,
            currentImagePath: _displayedImagePath,
            resultImage: _resultImage,
            isGenerating: busy,
            activeTool: _activeTool,
            onFlipHorizontal: () {},
            onMirror: () {},
          ),
        ),
        EditorToolsPanel(
          activeTool: _activeTool,
          promptController: _promptController,
          isGenerating: busy,
          appliedLensIds: _appliedLensIds,
          activeHighlightId: _activeHighlightId,
          onToolChanged: (tool) => setState(
            () => _activeTool = tool == _activeTool ? ToolType.none : tool,
          ),
          onSendPrompt: () => _handleUserCommand(_promptController.text),
          onClosePanel: () => setState(() => _activeTool = ToolType.none),
          cropAspectRatio: _cropAspectRatio,
          onCropRatioChanged: (ratio) =>
              setState(() => _cropAspectRatio = ratio),
          activeAdjustParam: _activeAdjustParam,
          adjustValue: _adjustValue,
          onAdjustParamChanged: (param) => setState(() {
            _activeAdjustParam = param;
            _adjustValue = 0;
          }),
          onAdjustValueChanged: (value) => setState(() => _adjustValue = value),
          selectedLensId: _selectedLensId,
          onLensSelected: (id) => setState(() => _selectedLensId = id),
        ),
      ],
    );
  }

  Widget _buildBackSide() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _project?.displayName ?? '历史版本',
                        style: GoogleFonts.orbitron(
                          textStyle: const TextStyle(
                            color: Colors.black87,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '轻点切换版本，长按节点查看详情。',
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.48),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black87),
                  onPressed: _toggleFlip,
                ),
              ],
            ),
          ),
          const Divider(color: Colors.black12),
          Expanded(
            child: _tree == null
                ? const Center(child: CircularProgressIndicator())
                : ImageHistoryTree(
                    tree: _tree!,
                    currentNodeId: _currentNodeId,
                    onNodeSelected: _selectNode,
                    onNodeLongPress: _openNodeSheet,
                  ),
          ),
        ],
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
