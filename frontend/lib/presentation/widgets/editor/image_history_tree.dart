import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class ImageHistoryTree extends StatelessWidget {
  final File originalImage;
  final Function(String) onNodeSelected;

  const ImageHistoryTree({
    super.key,
    required this.originalImage,
    required this.onNodeSelected,
  });

  @override
  Widget build(BuildContext context) {
    // 使用 InteractiveViewer 实现缩放和平移
    return InteractiveViewer(
      boundaryMargin: const EdgeInsets.all(500), // 允许拖拽出边界的范围
      minScale: 0.1, // 最小缩放
      maxScale: 4.0, // 最大缩放
      constrained: false, // 解除约束，允许子组件无限大
      child: Container(
        // 给整个树状图一个较大的固定容器，确保居中和绘制
        width: 800,
        height: 800,
        // 这里可以加一个极淡的网格背景增加科技感(可选)
        decoration: BoxDecoration(
          color: const Color(0xFF181818), // 比背景稍深的颜色，区分画布
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Stack(
          alignment: Alignment.center, // 默认居中对齐
          children: [
            // --- 连接线 (CustomPaint 绘制) ---
            CustomPaint(
              size: const Size(800, 800),
              painter: TreeConnectorPainter(),
            ),

            // --- 节点 1: Root (Original) ---
            // 坐标需要重新规划以适应 800x800 的中心
            Positioned(
              top: 100,
              left: 360, // (800 - 80)/2
              child: _buildNode("Root", "Original", true),
            ),

            // --- 节点 2: Level 1 (Filter Applied) ---
            Positioned(
              top: 300,
              left: 360,
              child: _buildNode("V1", "Cyberpunk", false),
            ),

            // --- 节点 3: Level 2 Left (Crop) ---
            Positioned(
              top: 500,
              left: 200, // 向左偏移
              child: _buildNode("V2.1", "Cropped", false),
            ),

            // --- 节点 4: Level 2 Right (Relight) ---
            Positioned(
              top: 500,
              left: 520, // 向右偏移
              child: _buildNode("V2.2", "Relight", false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNode(String id, String label, bool isRoot) {
    return GestureDetector(
      onTap: () => onNodeSelected(id),
      child: Column(
        children: [
          // 节点外框
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isRoot ? AppTheme.electricIndigo : Colors.white30,
                width: isRoot ? 2 : 1,
              ),
              color: Colors.black,
              boxShadow: [
                BoxShadow(
                  color: isRoot
                      ? AppTheme.electricIndigo.withOpacity(0.4)
                      : Colors.black.withOpacity(0.5),
                  blurRadius: 15,
                  spreadRadius: isRoot ? 2 : 0,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              // 实际开发中这里应该是不同版本的图片缓存
              child: Image.file(originalImage, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 12),
          // 节点标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isRoot ? AppTheme.electricIndigo : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 画树的连接线
class TreeConnectorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();

    // 坐标计算：
    // Node Size: 80x80
    // Node Center X offset: +40
    // Node Center Y offset (connection point): Top=0, Bottom=80

    // Root (360, 100) -> Bottom: (400, 180)
    // V1 (360, 300)   -> Top: (400, 300), Bottom: (400, 380)
    // V2.1 (200, 500) -> Top: (240, 500)
    // V2.2 (520, 500) -> Top: (560, 500)

    // Line 1: Root -> V1
    path.moveTo(400, 180);
    path.lineTo(400, 300);

    // Line 2: V1 -> V2.1 (Left)
    path.moveTo(400, 380);
    // 贝塞尔曲线连接
    path.cubicTo(400, 440, 240, 440, 240, 500);

    // Line 3: V1 -> V2.2 (Right)
    path.moveTo(400, 380);
    path.cubicTo(400, 440, 560, 440, 560, 500);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
