import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

// 定义节点模型 (如果没单独文件，就放在这)
class HistoryNode {
  final String id;
  final String? parentId; // Root 的 parentId 为 null
  final String label;
  final dynamic imageSource; // File, String(Asset), or Uint8List

  // 布局计算用
  int depth = 0;
  int childIndex = 0;

  HistoryNode({
    required this.id,
    this.parentId,
    required this.label,
    required this.imageSource,
  });
}

class ImageHistoryTree extends StatefulWidget {
  final Map<String, HistoryNode> nodes;
  final String currentNodeId;
  final Function(String) onNodeSelected;

  const ImageHistoryTree({
    super.key,
    required this.nodes,
    required this.currentNodeId,
    required this.onNodeSelected,
  });

  @override
  State<ImageHistoryTree> createState() => _ImageHistoryTreeState();
}

class _ImageHistoryTreeState extends State<ImageHistoryTree> {
  // 缓存计算好的坐标，避免每次 build 重算
  final Map<String, Offset> _nodePositions = {};

  @override
  Widget build(BuildContext context) {
    _calculateLayout(); // 计算所有节点位置

    return InteractiveViewer(
      boundaryMargin: const EdgeInsets.all(2000), // 巨大的边界允许拖拽
      minScale: 0.1,
      maxScale: 2.0,
      constrained: false, // 无限画布
      child: SizedBox(
        width: 2000, // 虚拟画布大小，根据节点数量可动态调整
        height: 1000,
        child: Stack(
          children: [
            // 1. 绘制连接线 (位于底层)
            CustomPaint(
              size: const Size(2000, 1000),
              painter: DynamicTreePainter(
                nodes: widget.nodes,
                positions: _nodePositions,
              ),
            ),

            // 2. 绘制节点
            ...widget.nodes.values.map((node) {
              final pos = _nodePositions[node.id] ?? Offset.zero;
              final bool isActive = node.id == widget.currentNodeId;

              return Positioned(
                left: pos.dx - 40, // 居中: x - width/2
                top: pos.dy - 50, // 居中: y - height/2
                child: _buildNodeWidget(node, isActive),
              );
            }),
          ],
        ),
      ),
    );
  }

  // --- 简单的树状布局算法 ---
  void _calculateLayout() {
    _nodePositions.clear();

    // 1. 找到 Root
    final root = widget.nodes.values.firstWhere((n) => n.parentId == null);

    // 2. 递归计算坐标
    // Root 放在画布中心左侧
    _placeNode(root, 100, 500, 200);
  }

  void _placeNode(
    HistoryNode node,
    double x,
    double y,
    double verticalSpacing,
  ) {
    _nodePositions[node.id] = Offset(x, y);

    // 找到所有孩子
    final children = widget.nodes.values
        .where((n) => n.parentId == node.id)
        .toList();

    if (children.isEmpty) return;

    // 计算孩子们的起始 Y 坐标，使其相对于父节点垂直居中
    double startY = y - ((children.length - 1) * verticalSpacing) / 2;

    for (int i = 0; i < children.length; i++) {
      // 这里的 180 是水平间距，verticalSpacing 是垂直间距
      // 随着层级变深，垂直间距变小，防止重叠
      _placeNode(
        children[i],
        x + 180,
        startY + (i * verticalSpacing),
        verticalSpacing * 0.8,
      );
    }
  }

  // --- 节点 UI 设计 ---
  Widget _buildNodeWidget(HistoryNode node, bool isActive) {
    return GestureDetector(
      onTap: () => widget.onNodeSelected(node.id),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 缩略图容器
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: isActive ? 90 : 80, // 选中放大
            height: isActive ? 90 : 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              // 选中时的发光边框
              border: Border.all(
                color: isActive ? AppTheme.electricIndigo : Colors.white24,
                width: isActive ? 3 : 1,
              ),
              color: Colors.black,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppTheme.electricIndigo.withOpacity(0.6),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 10,
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: _buildImage(node.imageSource),
            ),
          ),
          const SizedBox(height: 12),
          // 标签胶囊
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isActive
                  ? AppTheme.electricIndigo
                  : const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive ? Colors.white : Colors.white10,
                width: 0.5,
              ),
            ),
            child: Text(
              node.label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(dynamic source) {
    if (source is File) {
      return Image.file(source, fit: BoxFit.cover);
    } else if (source is Uint8List) {
      return Image.memory(source, fit: BoxFit.cover);
    } else if (source is String) {
      return Image.asset(source, fit: BoxFit.cover);
    }
    return Container(color: Colors.grey);
  }
}

// --- 动态连线画笔 ---
class DynamicTreePainter extends CustomPainter {
  final Map<String, HistoryNode> nodes;
  final Map<String, Offset> positions;

  DynamicTreePainter({required this.nodes, required this.positions});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final activePaint = Paint()
      ..color = AppTheme.electricIndigo.withOpacity(0.5)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    positions.forEach((id, pos) {
      final node = nodes[id];
      if (node?.parentId != null) {
        final parentPos = positions[node!.parentId];
        if (parentPos != null) {
          final path = Path();
          // 贝塞尔曲线连接：从父右侧 到 子左侧
          path.moveTo(parentPos.dx + 40, parentPos.dy); // Parent Right Center

          final midX = (parentPos.dx + 40 + pos.dx - 40) / 2;

          path.cubicTo(
            midX,
            parentPos.dy, // Control point 1
            midX,
            pos.dy, // Control point 2
            pos.dx - 40,
            pos.dy, // Child Left Center
          );

          canvas.drawPath(path, paint);
        }
      }
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true; // 每次都需要重绘
}
