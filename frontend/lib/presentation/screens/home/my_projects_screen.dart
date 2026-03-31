import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers/asset_tree_provider.dart';
import '../../../data/models/asset_tree_models.dart';
import '../../../data/repositories/asset_tree_repository.dart';
import '../../screens/editor/editor_screen.dart';
import '../../widgets/editor/editor_ai_toolbox_panel.dart';
import '../../widgets/shared/adaptive_media.dart';

Future<void> _deleteProjectWithConfirm(
  BuildContext context,
  WidgetRef ref,
  AssetTreeProject project,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('删除项目'),
        content: Text('确认删除“${project.displayName}”？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              '删除',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      );
    },
  );

  if (confirmed != true) return;
  try {
    await ref.read(assetTreeRepositoryProvider).deleteProject(project.projectId);
    ref.invalidate(assetTreeProjectsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('项目已删除')));
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_dioMessage(error, '删除项目失败'))));
  }
}

String _dioMessage(Object error, String fallback) {
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

class MyProjectsScreen extends ConsumerWidget {
  const MyProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(assetTreeProjectsProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('我的项目'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
      ),
      body: projectsAsync.when(
        data: (projects) {
          if (projects.isEmpty) {
            return const Center(
              child: Text(
                '还没有项目',
                style: TextStyle(color: Colors.black54),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            itemCount: projects.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) => _HomeProjectCard(
              project: projects[index],
              compact: false,
              onOpen: () => _openProjectEditor(context, ref, projects[index]),
              onDelete: () => _deleteProject(context, ref, projects[index]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            '项目加载失败：$error',
            style: const TextStyle(color: Colors.black54),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteProject(
    BuildContext context,
    WidgetRef ref,
    AssetTreeProject project,
  ) async {
    await _deleteProjectWithConfirm(context, ref, project);
  }
}

class HomeProjectsSection extends ConsumerWidget {
  const HomeProjectsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(assetTreeProjectsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '我的项目',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E1E1E),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyProjectsScreen()),
                );
              },
              child: Row(
                children: [
                  Text(
                    '查看全部',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 10,
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        projectsAsync.when(
          data: (projects) {
            if (projects.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                ),
                child: Text(
                  '还没有项目，进入修图并保存后会显示在这里。',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.56),
                    fontSize: 13,
                  ),
                ),
              );
            }
            final visibleProjects = projects.take(6).toList();
            return SizedBox(
              height: 176,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: visibleProjects.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) => _HomeProjectCard(
                  project: visibleProjects[index],
                  compact: true,
                  onOpen: () => _openProjectEditor(
                    context,
                    ref,
                    visibleProjects[index],
                  ),
                  onDelete: () => _deleteProjectWithConfirm(
                    context,
                    ref,
                    visibleProjects[index],
                  ),
                ),
              ),
            );
          },
          loading: () => const SizedBox(
            height: 176,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => SizedBox(
            height: 176,
            child: Center(
              child: Text(
                '项目加载失败：$error',
                style: const TextStyle(color: Colors.black54),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class HomeAiToolboxSection extends StatelessWidget {
  const HomeAiToolboxSection({super.key});

  @override
  Widget build(BuildContext context) {
    final featuredItems = <_ToolboxItemConfig>[
      _ToolboxItemConfig(
        title: '背景重绘',
        icon: Icons.landscape_rounded,
        lensId: 'lens_flux_edit',
      ),
      _ToolboxItemConfig(
        title: '画质超清',
        icon: Icons.hd_outlined,
        lensId: 'lens_upscale_4x',
        badgeText: 'Hot',
      ),
      _ToolboxItemConfig(
        title: '魔法消除',
        icon: Icons.auto_fix_off_rounded,
        lensId: 'lens_flux_inpaint',
      ),
      _ToolboxItemConfig(
        title: '智能抠图',
        icon: Icons.crop_free_rounded,
        lensId: 'lens_sam2_matting',
      ),
      _ToolboxItemConfig(
        title: '光影重塑',
        icon: Icons.wb_incandescent_outlined,
        lensId: 'lens_relighting',
      ),
      _ToolboxItemConfig(
        title: '风格迁移',
        icon: Icons.photo_filter_outlined,
        lensId: 'lens_style',
      ),
      _ToolboxItemConfig(
        title: '风格滤镜',
        icon: Icons.auto_awesome_rounded,
        lensId: 'lens_lora_filter',
      ),
      const _ToolboxItemConfig(
        title: '所有工具',
        icon: Icons.grid_view_rounded,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI 工具箱',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E1E1E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '导入一张图片后，直接进入对应工具开始处理。',
          style: TextStyle(
            color: Colors.black.withValues(alpha: 0.54),
            fontSize: 12,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFEDEFF2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: featuredItems.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 4,
              childAspectRatio: 0.9,
            ),
            itemBuilder: (context, index) => _ToolboxGridButton(
              item: featuredItems[index],
              onTap: () async {
                final item = featuredItems[index];
                if (item.lensId == null) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const _AllAiToolsScreen(),
                    ),
                  );
                  return;
                }
                final tool = kEditorAiToolDefinitions.firstWhere(
                  (definition) => definition.lensId == item.lensId,
                );
                await _pickImageAndOpenTool(context, tool);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeProjectCard extends StatelessWidget {
  const _HomeProjectCard({
    required this.project,
    required this.onOpen,
    required this.onDelete,
    required this.compact,
  });

  final AssetTreeProject project;
  final Future<void> Function() onOpen;
  final Future<void> Function() onDelete;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: compact ? 150 : double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: SizedBox(
                  height: compact ? 104 : 158,
                  width: double.infinity,
                  child: project.coverUrl != null && project.coverUrl!.trim().isNotEmpty
                      ? buildAdaptiveImage(
                          project.coverUrl,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: const Color(0xFFF1F3F5),
                          child: const Icon(
                            Icons.account_tree_outlined,
                            color: Color(0xFF4E5969),
                          ),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            project.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF1E1E1E),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => onDelete(),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${project.nodeCount} 个版本',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.45),
                        fontSize: 11,
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
  }
}

class _ToolboxItemConfig {
  const _ToolboxItemConfig({
    required this.title,
    required this.icon,
    this.lensId,
    this.badgeText,
  });

  final String title;
  final IconData icon;
  final String? lensId;
  final String? badgeText;
}

class _ToolboxGridButton extends StatelessWidget {
  const _ToolboxGridButton({
    required this.item,
    required this.onTap,
  });

  final _ToolboxItemConfig item;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SizedBox(
                      width: 42,
                      height: 42,
                      child: Icon(
                        item.icon,
                        color: const Color(0xFF111418),
                        size: 33,
                      ),
                    ),
                    if (item.badgeText != null)
                      Positioned(
                        top: -6,
                        right: -20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE9DB),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.badgeText!,
                            style: const TextStyle(
                              color: Color(0xFFFF6A2A),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  item.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF4F535A),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.28,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllAiToolsScreen extends StatelessWidget {
  const _AllAiToolsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('所有工具'),
        backgroundColor: const Color(0xFFF7F8FA),
        foregroundColor: const Color(0xFF111418),
        elevation: 0,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        itemCount: kEditorAiToolDefinitions.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 12,
          crossAxisSpacing: 6,
          childAspectRatio: 0.9,
        ),
        itemBuilder: (context, index) {
          final tool = kEditorAiToolDefinitions[index];
          return _ToolboxGridButton(
            item: _ToolboxItemConfig(
              title: tool.title,
              icon: tool.icon,
              lensId: tool.lensId,
              badgeText: tool.lensId == 'lens_upscale_4x' ? 'Hot' : null,
            ),
            onTap: () => _pickImageAndOpenTool(context, tool),
          );
        },
      ),
    );
  }
}

Future<void> _pickImageAndOpenTool(
  BuildContext context,
  EditorAiToolDefinition tool,
) async {
  final picker = ImagePicker();
  final image = await picker.pickImage(source: ImageSource.gallery);
  if (image == null || !context.mounted) return;

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EditorScreen(
        selectedImage: File(image.path),
        initialActiveTool: ToolType.aiToolbox,
        initialAiToolId: tool.lensId,
      ),
    ),
  );
}

Future<void> _openProjectEditor(
  BuildContext context,
  WidgetRef ref,
  AssetTreeProject project,
) async {
  try {
    final tree = await ref
        .read(assetTreeRepositoryProvider)
        .getProjectTree(project.projectId);
    final rootNodeId = tree.project.rootNodeId;
    final rootNode = rootNodeId == null ? null : tree.nodeMap[rootNodeId];
    final rootPath = rootNode?.previewUrl ?? project.coverUrl;
    final file = _optionalProjectFile(rootPath);

    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditorScreen(
          selectedImage: file,
          existingProjectId: project.projectId,
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_dioMessage(error, '打开项目失败'))),
    );
  }
}

File? _optionalProjectFile(String? path) {
  final trimmed = path?.trim() ?? '';
  if (trimmed.isEmpty || !isAdaptiveLocalFilePath(trimmed)) {
    return null;
  }
  final normalized = normalizeAdaptiveFilePath(trimmed);
  if (normalized.isEmpty) {
    return null;
  }
  return File(normalized);
}
