import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

import '../../../core/providers/asset_tree_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/local_media_store.dart';
import '../../../data/models/asset_tree_models.dart';
import '../../../data/repositories/asset_tree_repository.dart';
import '../../widgets/editor/asset_tree_node_sheet.dart';
import '../../widgets/editor/editor_canvas.dart';
import '../../widgets/editor/editor_header.dart';
import '../../widgets/editor/editor_tools_panel.dart';
import '../../widgets/editor/image_history_tree.dart';
import '../../widgets/shared/adaptive_media.dart';

enum ToolType { none, crop, adjust, lens, templates }

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

  bool _isGenerating = false;
  bool _isBootstrapping = true;
  bool _isLoadingProject = false;

  String? _displayedImagePath;
  String? _initialImagePath;
  String? _projectError;
  Size? _currentImageSize;

  ToolType _activeTool = ToolType.templates;
  double _cropAspectRatio = -1;
  String _activeAdjustParam = '曝光';
  double _adjustValue = 0.0;
  String? _selectedLensId;
  Rect _cropRect = const Rect.fromLTWH(0.12, 0.1, 0.76, 0.76);

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
                promptController: _promptController,
                isGenerating: busy,
                appliedLensIds: _appliedLensIds,
                activeHighlightId: _activeHighlightId,
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
