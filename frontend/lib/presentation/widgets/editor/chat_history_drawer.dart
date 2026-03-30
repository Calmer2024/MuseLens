import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '项目管理',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              onPressed: () => ref.invalidate(assetTreeProjectsProvider),
              icon: const Icon(Icons.refresh_rounded),
              color: Colors.white70,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF14141A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: Text(
                  '把当前画面另存为一个新的项目分支。',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
              FilledButton.tonal(
                onPressed: () => _createProjectFromCurrentFrame(context, ref),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.electricIndigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                child: const Text('新建项目'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
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
                padding: EdgeInsets.zero,
                itemCount: projects.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final project = projects[index];
                  return _ProjectCard(
                    project: project,
                    isCurrent: project.projectId == currentProjectId,
                    onTap: () => _openProject(project.projectId),
                    onRename: () => _renameProject(context, ref, project),
                    onDelete: project.projectId == currentProjectId
                        ? null
                        : () => _deleteProject(context, ref, project),
                  );
                },
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.electricIndigo),
            ),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '项目列表加载失败：$error',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.66),
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openProject(String projectId) async {
    await onOpenProject(projectId);
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
          backgroundColor: const Color(0xFF14141A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            '编辑项目',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('项目名称'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                minLines: 2,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('项目描述'),
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
              name: nameController.text.trim(),
              description: descriptionController.text.trim(),
            ),
          );
      ref.invalidate(assetTreeProjectsProvider);
      ref.invalidate(assetTreeProjectDetailProvider(project.projectId));
      ref.invalidate(assetTreeProjectTreeProvider(project.projectId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('项目已更新')));
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
          backgroundColor: const Color(0xFF14141A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            '删除项目',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            '确认删除“${project.displayName}”？项目下的全部版本都会一起移除。',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              height: 1.45,
            ),
          ),
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

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
      filled: true,
      fillColor: const Color(0xFF1D1D25),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
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
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF111117),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isCurrent
                  ? AppTheme.electricIndigo
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 60,
                  height: 74,
                  child: project.coverUrl != null &&
                          project.coverUrl!.trim().isNotEmpty
                      ? buildAdaptiveImage(
                          project.coverUrl,
                          fit: BoxFit.cover,
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
                              color: Colors.white,
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
                                alpha: 0.18,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              '当前',
                              style: TextStyle(
                                color: Colors.white,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.56),
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 8),
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
                          color: const Color(0xFF202028),
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
                            color: Colors.white.withValues(alpha: 0.6),
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
        color: AppTheme.electricIndigo.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
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
    return Container(
      color: const Color(0xFF1A1A21),
      alignment: Alignment.center,
      child: const Icon(
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
              color: Colors.white.withValues(alpha: 0.18),
            ),
            const SizedBox(height: 14),
            const Text(
              '还没有项目',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '先把当前画面保存成项目，资产树就会开始记录你的修图版本。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.54),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onCreatePressed,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.electricIndigo,
                foregroundColor: Colors.white,
              ),
              child: const Text('创建项目'),
            ),
          ],
        ),
      ),
    );
  }
}
