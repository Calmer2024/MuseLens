import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/asset_tree_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/asset_tree_models.dart';
import '../../../data/repositories/asset_tree_repository.dart';
import '../shared/adaptive_media.dart';

class ChatHistoryDrawer extends ConsumerWidget {
  const ChatHistoryDrawer({
    super.key,
    required this.currentProjectId,
    required this.onOpenProject,
    required this.onCreateProjectFromCurrentFrame,
  });

  final String? currentProjectId;
  final Future<void> Function(String projectId) onOpenProject;
  final Future<void> Function() onCreateProjectFromCurrentFrame;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(assetTreeProjectsProvider);

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '项目资产树',
                          style: GoogleFonts.orbitron(
                            textStyle: const TextStyle(
                              color: Colors.black87,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => ref.invalidate(assetTreeProjectsProvider),
                        icon: const Icon(Icons.refresh_rounded),
                        color: Colors.black54,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '在这里切换历史项目、重命名项目，或者把当前画面另存为一个新项目。',
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.54),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _createProjectFromCurrentFrame(context, ref),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.electricIndigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('当前画面另存为项目'),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.black12),
            Expanded(
              child: projectsAsync.when(
                data: (projects) {
                  if (projects.isEmpty) {
                    return _DrawerEmptyState(
                      onCreatePressed: () => _createProjectFromCurrentFrame(
                        context,
                        ref,
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    itemCount: projects.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final project = projects[index];
                      final isCurrent = project.projectId == currentProjectId;
                      return _ProjectCard(
                        project: project,
                        isCurrent: isCurrent,
                        onTap: () => _openProject(context, project.projectId),
                        onRename: () => _renameProject(context, ref, project),
                        onDelete: isCurrent
                            ? null
                            : () => _deleteProject(context, ref, project),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '项目列表加载失败：$error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openProject(BuildContext context, String projectId) async {
    await onOpenProject(projectId);
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _createProjectFromCurrentFrame(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      await onCreateProjectFromCurrentFrame();
      ref.invalidate(assetTreeProjectsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已创建新项目')));
      Navigator.of(context).pop();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_dioMessage(error, '创建项目失败'))),
      );
    }
  }

  Future<void> _renameProject(
    BuildContext context,
    WidgetRef ref,
    AssetTreeProject project,
  ) async {
    final nameController = TextEditingController(text: project.name);
    final descriptionController = TextEditingController(text: project.description);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text('编辑项目'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '项目名称'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: '项目描述'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await ref.read(assetTreeRepositoryProvider).updateProject(
            projectId: project.projectId,
            input: UpdateAssetTreeProjectInput(
              name: nameController.text,
              description: descriptionController.text,
            ),
          );
      ref.invalidate(assetTreeProjectsProvider);
      ref.invalidate(assetTreeProjectDetailProvider(project.projectId));
      ref.invalidate(assetTreeProjectTreeProvider(project.projectId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('项目信息已更新')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_dioMessage(error, '更新项目失败'))),
      );
    }
  }

  Future<void> _deleteProject(
    BuildContext context,
    WidgetRef ref,
    AssetTreeProject project,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text('删除项目'),
          content: Text('确认删除“${project.displayName}”？项目下的全部历史节点都会一起移除。'),
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
      ref.invalidate(assetTreeProjectDetailProvider(project.projectId));
      ref.invalidate(assetTreeProjectTreeProvider(project.projectId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('项目已删除')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_dioMessage(error, '删除项目失败'))),
      );
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
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.isCurrent,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final AssetTreeProject project;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final subtitle = project.description.trim().isNotEmpty
        ? project.description.trim()
        : '${project.nodeCount} 个版本 · ${project.branchCount} 个分支';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isCurrent
                  ? AppTheme.electricIndigo
                  : Colors.black.withValues(alpha: 0.06),
              width: isCurrent ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 70,
                  height: 84,
                  color: const Color(0xFFF2EEFF),
                  child: project.coverUrl != null &&
                          project.coverUrl!.trim().isNotEmpty
                      ? buildAdaptiveImage(
                          project.coverUrl,
                          fit: BoxFit.cover,
                          width: 70,
                          height: 84,
                          errorWidget: const _ProjectCoverFallback(),
                        )
                      : const _ProjectCoverFallback(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
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
                              color: Colors.black87,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isCurrent)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.electricIndigo.withValues(
                                alpha: 0.08,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              '当前',
                              style: TextStyle(
                                color: AppTheme.electricIndigo,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.56),
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _CountPill(
                          icon: Icons.account_tree_outlined,
                          label: '${project.nodeCount}',
                        ),
                        const SizedBox(width: 8),
                        _CountPill(
                          icon: Icons.alt_route_rounded,
                          label: '${project.branchCount}',
                        ),
                        const Spacer(),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'rename') {
                              onRename();
                            } else if (value == 'delete' && onDelete != null) {
                              onDelete!();
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'rename',
                              child: Text('编辑项目'),
                            ),
                            if (onDelete != null)
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  '删除项目',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ),
                          ],
                          child: Icon(
                            Icons.more_horiz_rounded,
                            color: Colors.black.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
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

class _CountPill extends StatelessWidget {
  const _CountPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F4FD),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.electricIndigo),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.electricIndigo,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectCoverFallback extends StatelessWidget {
  const _ProjectCoverFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.auto_awesome_motion_rounded,
        color: AppTheme.electricIndigo,
        size: 24,
      ),
    );
  }
}

class _DrawerEmptyState extends StatelessWidget {
  const _DrawerEmptyState({required this.onCreatePressed});

  final VoidCallback onCreatePressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_tree_outlined,
              size: 54,
              color: Colors.black.withValues(alpha: 0.16),
            ),
            const SizedBox(height: 14),
            const Text(
              '还没有资产树项目',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '先在编辑器里导入一张图，或者把当前画面另存为一个新的项目。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.5),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onCreatePressed,
              icon: const Icon(Icons.add),
              label: const Text('创建项目'),
            ),
          ],
        ),
      ),
    );
  }
}
