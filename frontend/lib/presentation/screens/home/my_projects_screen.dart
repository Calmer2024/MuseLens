import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/asset_tree_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/asset_tree_models.dart';
import '../../../data/repositories/asset_tree_repository.dart';
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

class _HomeProjectCard extends StatelessWidget {
  const _HomeProjectCard({
    required this.project,
    required this.onDelete,
    required this.compact,
  });

  final AssetTreeProject project;
  final Future<void> Function() onDelete;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                      color: const Color(0xFFF3F0FF),
                      child: const Icon(
                        Icons.account_tree_outlined,
                        color: AppTheme.electricIndigo,
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
    );
  }
}
