import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/asset_tree_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/asset_tree_models.dart';
import '../../../data/repositories/asset_tree_repository.dart';
import '../shared/adaptive_media.dart';

class AssetTreeNodeSheet extends ConsumerStatefulWidget {
  const AssetTreeNodeSheet({
    super.key,
    required this.projectId,
    required this.nodeId,
    required this.rootNodeId,
    required this.currentNodeId,
    required this.onSelectNode,
    required this.onRefreshProject,
  });

  final String projectId;
  final String nodeId;
  final String? rootNodeId;
  final String? currentNodeId;
  final Future<void> Function(String nodeId) onSelectNode;
  final Future<void> Function() onRefreshProject;

  @override
  ConsumerState<AssetTreeNodeSheet> createState() => _AssetTreeNodeSheetState();
}

class _AssetTreeNodeSheetState extends ConsumerState<AssetTreeNodeSheet> {
  AssetTreeNode? _node;
  AssetTreeAncestorPath? _ancestors;
  AssetTreeDescendants? _descendants;
  List<AssetTreeTag> _tags = const [];
  AssetTreeNodeCompare? _compare;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadData);
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final repository = ref.read(assetTreeRepositoryProvider);
      final node = await repository.getNode(widget.nodeId);
      final ancestors = await repository.getNodeAncestors(widget.nodeId);
      final descendants = await repository.getNodeDescendants(widget.nodeId);
      final tags = await repository.listNodeTags(widget.nodeId);

      AssetTreeNodeCompare? compare;
      if (widget.currentNodeId != null && widget.currentNodeId != widget.nodeId) {
        try {
          compare = await repository.compareNodes(
            nodeA: widget.currentNodeId!,
            nodeB: widget.nodeId,
          );
        } catch (_) {
          compare = null;
        }
      }

      if (!mounted) return;
      setState(() {
        _node = node;
        _ancestors = ancestors;
        _descendants = descendants;
        _tags = tags;
        _compare = compare;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_messageFromError(error, '加载节点详情失败'))),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _refreshAll() async {
    _invalidateCaches();
    await widget.onRefreshProject();
    await _loadData();
  }

  void _invalidateCaches() {
    ref.invalidate(assetTreeProjectDetailProvider(widget.projectId));
    ref.invalidate(assetTreeProjectTreeProvider(widget.projectId));
    ref.invalidate(assetTreeNodeDetailProvider(widget.nodeId));
    ref.invalidate(assetTreeNodeAncestorsProvider(widget.nodeId));
    ref.invalidate(assetTreeNodeDescendantsProvider(widget.nodeId));
    ref.invalidate(assetTreeNodeTagsProvider(widget.nodeId));
    if (widget.currentNodeId != null) {
      ref.invalidate(assetTreeNodeDetailProvider(widget.currentNodeId!));
      ref.invalidate(assetTreeNodeAncestorsProvider(widget.currentNodeId!));
      ref.invalidate(assetTreeNodeDescendantsProvider(widget.currentNodeId!));
      ref.invalidate(assetTreeNodeTagsProvider(widget.currentNodeId!));
    }
  }

  Future<void> _addTag() async {
    final input = await _showAddTagDialog(context);
    if (input == null) return;
    try {
      await ref
          .read(assetTreeRepositoryProvider)
          .addNodeTag(nodeId: widget.nodeId, input: input);
      await _refreshAll();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_messageFromError(error, '添加标签失败'))),
      );
    }
  }

  Future<void> _deleteTag(String tagId) async {
    try {
      await ref.read(assetTreeRepositoryProvider).deleteTag(tagId);
      await _refreshAll();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_messageFromError(error, '删除标签失败'))),
      );
    }
  }

  Future<void> _deleteNode(bool cascade) async {
    final node = _node;
    if (node == null) return;
    if (widget.nodeId == widget.rootNodeId) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂不支持直接删除根节点')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(cascade ? '删除整个分支' : '删除当前节点'),
          content: Text(
            cascade
                ? '确认删除“${node.displayLabel}”以及它下面的所有后代版本吗？'
                : '只允许删除叶子节点，确认删除“${node.displayLabel}”？',
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
      await ref
          .read(assetTreeRepositoryProvider)
          .deleteNode(nodeId: widget.nodeId, cascade: cascade);
      _invalidateCaches();
      if (!mounted) return;
      Navigator.of(context).pop(true);
      await widget.onRefreshProject();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_messageFromError(error, '删除节点失败'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final node = _node;
    final ancestors = _ancestors;
    final descendants = _descendants;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(context).padding.bottom + 20,
          ),
          child: _loading || node == null || ancestors == null || descendants == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              node.displayLabel,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _loadData,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          height: 220,
                          width: double.infinity,
                          color: const Color(0xFFF4F0FF),
                          child: buildAdaptiveImage(
                            node.previewUrl,
                            fit: BoxFit.contain,
                            errorWidget: const Center(
                              child: Icon(
                                Icons.image_outlined,
                                color: AppTheme.electricIndigo,
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _InfoPill(
                            icon: Icons.account_tree_outlined,
                            label: '深度 ${node.depth}',
                          ),
                          _InfoPill(
                            icon: Icons.settings_suggest_outlined,
                            label: node.nodeType == 'original' ? '原图' : '生成节点',
                          ),
                          _InfoPill(
                            icon: Icons.bolt_rounded,
                            label: node.status == 'generating'
                                ? '生成中'
                                : node.status == 'failed'
                                    ? '失败'
                                    : '已完成',
                            highlight: node.status != 'failed',
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const _SectionTitle('路径来源'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ancestors.ancestors
                            .map(
                              (item) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF6F3FF),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  item.displayLabel,
                                  style: const TextStyle(
                                    color: AppTheme.electricIndigo,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      if (ancestors.pathEdges.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          ancestors.pathEdges
                              .map((edge) => edge.displayName)
                              .join('  ->  '),
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.56),
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const _SectionTitle('节点标签'),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _addTag,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('添加标签'),
                          ),
                        ],
                      ),
                      if (_tags.isEmpty)
                        Text(
                          '这个节点还没有标签。',
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.46),
                            fontSize: 12,
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _tags
                              .map(
                                (tag) => InputChip(
                                  label: Text(tag.label),
                                  backgroundColor: _safeChipColor(tag.color),
                                  onDeleted: () => _deleteTag(tag.tagId),
                                ),
                              )
                              .toList(),
                        ),
                      const SizedBox(height: 18),
                      const _SectionTitle('版本信息'),
                      const SizedBox(height: 10),
                      _InfoRow(label: '节点 ID', value: _shortId(node.nodeId)),
                      _InfoRow(label: '项目 ID', value: _shortId(node.projectId)),
                      _InfoRow(
                        label: '创建时间',
                        value: _formatDateTime(node.createdAt),
                      ),
                      if (node.width != null && node.height != null)
                        _InfoRow(
                          label: '图片尺寸',
                          value: '${node.width} x ${node.height}',
                        ),
                      if (node.format != null && node.format!.trim().isNotEmpty)
                        _InfoRow(label: '格式', value: node.format!),
                      _InfoRow(
                        label: '后代数量',
                        value: '${descendants.descendants.length}',
                      ),
                      if (_compare != null) ...[
                        const SizedBox(height: 18),
                        const _SectionTitle('与当前版本比较'),
                        const SizedBox(height: 10),
                        _CompareCard(compare: _compare!),
                      ],
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: widget.currentNodeId == widget.nodeId
                                  ? null
                                  : () async {
                                      Navigator.of(context).pop();
                                      await widget.onSelectNode(widget.nodeId);
                                    },
                              icon: const Icon(Icons.my_location_outlined),
                              label: const Text('设为当前版本'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _refreshAll,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.electricIndigo,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.sync),
                              label: const Text('刷新节点'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: widget.nodeId == widget.rootNodeId
                                  ? null
                                  : () => _deleteNode(false),
                              child: const Text(
                                '删除节点',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextButton(
                              onPressed: widget.nodeId == widget.rootNodeId
                                  ? null
                                  : () => _deleteNode(true),
                              child: const Text(
                                '删除子树',
                                style: TextStyle(color: Colors.redAccent),
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

  Future<AddAssetTreeTagInput?> _showAddTagDialog(BuildContext context) async {
    final labelController = TextEditingController();
    var selectedColor = '#7C5CFF';
    const colorOptions = <String>[
      '#7C5CFF',
      '#F05D7B',
      '#4A90E2',
      '#36B37E',
      '#F0A83A',
    ];

    return showDialog<AddAssetTreeTagInput>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text('添加节点标签'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: labelController,
                    decoration: const InputDecoration(labelText: '标签名称'),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    children: colorOptions.map((color) {
                      final isSelected = color == selectedColor;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = color),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: isSelected ? 34 : 28,
                          height: isSelected ? 34 : 28,
                          decoration: BoxDecoration(
                            color: _safeChipColor(color),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.electricIndigo
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    final label = labelController.text.trim();
                    if (label.isEmpty) return;
                    Navigator.of(dialogContext).pop(
                      AddAssetTreeTagInput(label: label, color: selectedColor),
                    );
                  },
                  child: const Text('确认'),
                ),
              ],
            );
          },
        );
      },
    );
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
    return fallback;
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 15,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: highlight
            ? AppTheme.electricIndigo.withValues(alpha: 0.08)
            : const Color(0xFFF6F4FD),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: highlight ? AppTheme.electricIndigo : Colors.black54,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: highlight ? AppTheme.electricIndigo : Colors.black87,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.48),
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompareCard extends StatelessWidget {
  const _CompareCard({required this.compare});

  final AssetTreeNodeCompare compare;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F6FF),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _CompareNodePreview(
                  title: compare.nodeA.displayLabel,
                  imageUrl: compare.nodeA.previewUrl,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CompareNodePreview(
                  title: compare.nodeB.displayLabel,
                  imageUrl: compare.nodeB.previewUrl,
                ),
              ),
            ],
          ),
          if (compare.edge != null) ...[
            const SizedBox(height: 12),
            Text(
              '直接操作：${compare.edge!.displayName}',
              style: const TextStyle(
                color: AppTheme.electricIndigo,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompareNodePreview extends StatelessWidget {
  const _CompareNodePreview({
    required this.title,
    required this.imageUrl,
  });

  final String title;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              color: Colors.white,
              child: buildAdaptiveImage(
                imageUrl,
                fit: BoxFit.contain,
                errorWidget: const Center(
                  child: Icon(
                    Icons.image_outlined,
                    color: AppTheme.electricIndigo,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

Color _safeChipColor(String hex) {
  final value = hex.trim().replaceFirst('#', '');
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null || value.length != 6) {
    return const Color(0xFFECE8FF);
  }
  return (Color(0xFF000000 | parsed)).withValues(alpha: 0.18);
}

String _shortId(String id) {
  if (id.length <= 12) {
    return id;
  }
  return '${id.substring(0, 8)}...${id.substring(id.length - 4)}';
}

String _formatDateTime(DateTime time) {
  final local = time.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
