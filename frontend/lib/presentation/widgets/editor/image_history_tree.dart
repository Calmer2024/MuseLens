import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/asset_tree_models.dart';
import '../shared/adaptive_media.dart';

class ImageHistoryTree extends StatefulWidget {
  const ImageHistoryTree({
    super.key,
    required this.tree,
    required this.currentNodeId,
    required this.onNodeSelected,
    this.onNodeLongPress,
  });

  final AssetTreeProjectTree tree;
  final String? currentNodeId;
  final ValueChanged<String> onNodeSelected;
  final ValueChanged<String>? onNodeLongPress;

  @override
  State<ImageHistoryTree> createState() => _ImageHistoryTreeState();
}

class _ImageHistoryTreeState extends State<ImageHistoryTree> {
  final Map<String, Offset> _nodePositions = <String, Offset>{};

  static const double _nodeWidth = 104;
  static const double _nodeHeight = 146;
  static const double _horizontalSpacing = 188;
  static const double _initialX = 120;

  @override
  Widget build(BuildContext context) {
    final rootId = widget.tree.project.rootNodeId;
    if (rootId == null || !widget.tree.nodeMap.containsKey(rootId)) {
      return const Center(
        child: Text(
          '这个项目还没有根节点',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    _calculateLayout(rootId);
    final canvasSize = _calculateCanvasSize();

    return InteractiveViewer(
      boundaryMargin: const EdgeInsets.all(1600),
      minScale: 0.18,
      maxScale: 2.4,
      constrained: false,
      child: SizedBox(
        width: canvasSize.width,
        height: canvasSize.height,
        child: Stack(
          children: [
            CustomPaint(
              size: canvasSize,
              painter: _DynamicTreePainter(
                tree: widget.tree,
                positions: _nodePositions,
                currentNodeId: widget.currentNodeId,
              ),
            ),
            ...widget.tree.nodes.map((node) {
              final position = _nodePositions[node.nodeId];
              if (position == null) {
                return const SizedBox.shrink();
              }
              return Positioned(
                left: position.dx - (_nodeWidth / 2),
                top: position.dy - (_nodeHeight / 2),
                child: _TreeNodeCard(
                  node: node,
                  isActive: node.nodeId == widget.currentNodeId,
                  onTap: () => widget.onNodeSelected(node.nodeId),
                  onLongPress: widget.onNodeLongPress == null
                      ? null
                      : () => widget.onNodeLongPress!(node.nodeId),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _calculateLayout(String rootId) {
    _nodePositions.clear();
    final tree = widget.tree;
    final rootNode = tree.nodeMap[rootId];
    if (rootNode == null) {
      return;
    }
    _placeNode(
      rootNode,
      _initialX,
      math.max(340.0, tree.nodes.length * 82 / 2),
      math.max(170.0, tree.nodes.length * 48),
    );
  }

  void _placeNode(
    AssetTreeNodeSummary node,
    double x,
    double y,
    double verticalSpacing,
  ) {
    _nodePositions[node.nodeId] = Offset(x, y);
    final children = widget.tree
        .childrenOf(node.nodeId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    if (children.isEmpty) {
      return;
    }

    final nextSpacing = math.max(108.0, verticalSpacing * 0.68);
    final startY = y - ((children.length - 1) * nextSpacing) / 2;

    for (var index = 0; index < children.length; index++) {
      _placeNode(
        children[index],
        x + _horizontalSpacing,
        startY + (index * nextSpacing),
        nextSpacing,
      );
    }
  }

  Size _calculateCanvasSize() {
    final maxDepth = widget.tree.nodes.fold<int>(
      0,
      (currentMax, node) => math.max(currentMax, node.depth),
    );
    final width = math.max(1000, 320 + ((maxDepth + 1) * 220));
    final height = math.max(900, 240 + (widget.tree.nodes.length * 130));
    return Size(width.toDouble(), height.toDouble());
  }
}

class _TreeNodeCard extends StatelessWidget {
  const _TreeNodeCard({
    required this.node,
    required this.isActive,
    required this.onTap,
    this.onLongPress,
  });

  final AssetTreeNodeSummary node;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (node.status) {
      'failed' => Colors.redAccent,
      'generating' => const Color(0xFFF0A83A),
      _ => AppTheme.electricIndigo,
    };

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: _ImageHistoryTreeState._nodeWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: isActive ? 96 : 88,
              height: isActive ? 104 : 96,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isActive
                      ? AppTheme.electricIndigo
                      : Colors.black.withValues(alpha: 0.08),
                  width: isActive ? 1.8 : 1,
                ),
                gradient: isActive
                    ? const LinearGradient(
                        colors: [Color(0xFFF7F1FF), Colors.white],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      )
                    : null,
                color: isActive ? null : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: isActive
                        ? AppTheme.electricIndigo.withValues(alpha: 0.24)
                        : Colors.black.withValues(alpha: 0.08),
                    blurRadius: isActive ? 20 : 12,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      color: const Color(0xFFF3F0FF),
                      child: buildAdaptiveImage(
                        node.previewUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorWidget: const _NodeFallback(),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                  if (node.tags.isNotEmpty)
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.62),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          node.tags.first.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _safeColorFromHex(node.tags.first.color),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              node.displayLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.86),
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              node.status == 'generating'
                  ? '生成中'
                  : node.createdAt.toLocal().toString().substring(5, 16),
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.42),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DynamicTreePainter extends CustomPainter {
  _DynamicTreePainter({
    required this.tree,
    required this.positions,
    required this.currentNodeId,
  });

  final AssetTreeProjectTree tree;
  final Map<String, Offset> positions;
  final String? currentNodeId;

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final activePaint = Paint()
      ..color = AppTheme.electricIndigo.withValues(alpha: 0.45)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    for (final edge in tree.edges) {
      final source = positions[edge.sourceNodeId];
      final target = positions[edge.targetNodeId];
      if (source == null || target == null) {
        continue;
      }

      final path = Path()
        ..moveTo(source.dx + 44, source.dy)
        ..cubicTo(
          (source.dx + target.dx) / 2,
          source.dy,
          (source.dx + target.dx) / 2,
          target.dy,
          target.dx - 44,
          target.dy,
        );

      final paint = edge.targetNodeId == currentNodeId ? activePaint : basePaint;
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DynamicTreePainter oldDelegate) {
    return oldDelegate.tree != tree ||
        oldDelegate.positions != positions ||
        oldDelegate.currentNodeId != currentNodeId;
  }
}

class _NodeFallback extends StatelessWidget {
  const _NodeFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.image_outlined,
        color: AppTheme.electricIndigo,
        size: 26,
      ),
    );
  }
}

Color _safeColorFromHex(String hex) {
  final value = hex.trim().replaceFirst('#', '');
  if (value.length != 6) {
    return Colors.white;
  }
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) {
    return Colors.white;
  }
  return Color(0xFF000000 | parsed);
}
