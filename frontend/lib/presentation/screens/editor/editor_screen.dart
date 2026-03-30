import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    this.initialPrompt,
  });

  final File selectedImage;
  final String? initialPrompt;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  final TextEditingController _promptController = TextEditingController();

  bool _isGenerating = false;
  bool _isBootstrapping = true;
  bool _isLoadingProject = false;

  String? _displayedImagePath;
  String? _initialImagePath;
  String? _projectError;

  ToolType _activeTool = ToolType.none;
  double _cropAspectRatio = -1;
  String _activeAdjustParam = '曝光';
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
    final rootNode = await repository.addRootNode(
      projectId: project.projectId,
      input: payload,
    );

    _initialImagePath = storedPath;
    await _loadProject(project.projectId, preferredNodeId: rootNode.nodeId);
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
        name: '${_project?.displayName ?? '编辑项目'} 副本',
        description: '由当前画面保存',
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
        _displayedImagePath = _normalizeProjectImagePath(
          node?.imageUrl ?? tree.project.coverUrl ?? _initialImagePath,
        );
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

  Future<void> _handleUserCommand(String text) async {
    final prompt = text.trim();
    FocusScope.of(context).unfocus();
    if (prompt.isEmpty) return;

    final project = _project;
    final currentNodeId = _currentNodeId;
    final currentPath = _normalizeProjectImagePath(
      _displayedImagePath ?? _initialImagePath,
    );
    if (project == null || currentNodeId == null || currentPath == null) {
      _showError(StateError('当前没有可编辑的画面'), '当前没有可编辑的画面');
      return;
    }

    setState(() {
      _isGenerating = true;
      _promptController.clear();
      final lensId = _selectedLensId ?? 'ai_prompt';
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
              imageUrl: currentPath,
              thumbnailUrl: currentPath,
              lensId: _selectedLensId ?? 'ai_prompt',
              lensName: _selectedLensName(),
              userPrompt: prompt,
              parameters: {
                'prompt': prompt,
                'tool': _activeTool.name,
              },
              generationParams: {
                'prompt': prompt,
                'tool': _activeTool.name,
                'adjust_value': _adjustValue,
              },
              metadata: const {'source': 'prompt_record'},
              status: 'completed',
            ),
          );
      await repository.addNodeTag(
        nodeId: created.node.nodeId,
        input: AddAssetTreeTagInput(label: _buildPromptTag(prompt)),
      );
      await _loadProject(project.projectId, preferredNodeId: created.node.nodeId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('本次修图指令已记录到资产树')),
      );
    } catch (error) {
      _showError(error, '记录修图指令失败');
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
      _displayedImagePath = _normalizeProjectImagePath(node.imageUrl);
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

  Future<void> _showAssetTreeManager() async {
    final project = _project;
    if (project == null || !mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DefaultTabController(
          length: 2,
          child: FractionallySizedBox(
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
                            '资产树管理',
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
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF17171D),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const TabBar(
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: AppTheme.electricIndigo,
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white70,
                      dividerColor: Colors.transparent,
                      tabs: [
                        Tab(text: '版本树'),
                        Tab(text: '项目'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TabBarView(
                      children: [
                        Padding(
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
                                child: Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 220,
                                      child: Text(
                                        '轻点版本切换当前画面，长按节点查看标签、祖先路径和删除等管理操作。',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.65,
                                          ),
                                          fontSize: 13,
                                          height: 1.45,
                                        ),
                                      ),
                                    ),
                                    FilledButton(
                                      onPressed: _handleSave,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppTheme.electricIndigo,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('保存版本'),
                                    ),
                                  ],
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
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: ChatHistoryDrawer(
                            currentProjectId: _project?.projectId,
                            onOpenProject: (projectId) async {
                              await _loadProject(projectId);
                              if (sheetContext.mounted) {
                                Navigator.of(sheetContext).pop();
                              }
                            },
                            onCreateProjectFromCurrentFrame: _createProjectFromCurrentFrame,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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

  String _buildDefaultProjectName() => '编辑项目';

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
            '3. 每次保存或发送指令后，都会记录到资产树里。',
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
    final currentPath = _normalizeProjectImagePath(_displayedImagePath);
    final message = currentPath == null ? '当前没有可导出的画面' : '导出入口已预留，当前画面已就绪';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
                onToolChanged: (tool) => setState(() {
                  _activeTool = _activeTool == tool ? ToolType.none : tool;
                }),
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
