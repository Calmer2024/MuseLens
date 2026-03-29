import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:image_picker/image_picker.dart';
// 根据你的实际路径引入意向顾问界面
import '../../screens/create/consultant_screen.dart';

class HeroCreateCard extends StatefulWidget {
  const HeroCreateCard({super.key});

  @override
  State<HeroCreateCard> createState() => _HeroCreateCardState();
}

class _HeroCreateCardState extends State<HeroCreateCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 动画时长设为 12 秒，营造缓慢流动的质感
    _controller = AnimationController(
      duration: const Duration(seconds: 12),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // 减小卡片整体高度
      height: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF584CF4).withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // === 1. 动态网格渐变层 (背景色块) ===
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = _controller.value * 2 * math.pi;
              return Stack(
                children: [
                  // 基础底色：柔和的淡紫/粉色
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFE8D5FF), Color(0xFFFFF0F5)],
                      ),
                    ),
                  ),
                  // 光块 1：深紫色 (右上向左下运动)
                  Positioned(
                    top: -50 + 40 * math.sin(t),
                    right: -50 + 30 * math.cos(t),
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFA855F7),
                      ),
                    ),
                  ),
                  // 光块 2：亮金色/黄色 (左侧中间向右运动)
                  Positioned(
                    top: 80 + 30 * math.cos(t + math.pi / 2),
                    left: -60 + 50 * math.sin(t),
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFFD700),
                      ),
                    ),
                  ),
                  // 光块 3：洋红色/粉红 (中间偏下)
                  Positioned(
                    bottom: 100 + 40 * math.sin(t + math.pi),
                    right: 40 + 40 * math.cos(t),
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFF7EB3),
                      ),
                    ),
                  ),
                  // === 2. 强力高斯模糊层，将色块融合成流体 ===
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 50.0, sigmaY: 50.0),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  // === 3. 玻璃折射高光曲线 ===
                  Positioned.fill(
                    child: CustomPaint(
                      painter: GlassHighlightPainter(
                        animationValue: _controller.value,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // === 4. 底部白色内容与平滑渐变过渡区域 ===
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              width: double.infinity,
              // 使用渐变替代原本的纯白底色
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.0), // 顶部完全透明，融入背景
                    Colors.white.withOpacity(0.85), // 中间半透明白色过渡
                    Colors.white, // 底部纯白，保证文字清晰度
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
              // 增加了 top 的 padding 以便为渐变留出过渡空间
              padding: const EdgeInsets.only(
                left: 24.0,
                right: 24.0,
                top: 50.0,
                bottom: 20.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // --- 左侧：缩小后的文本 ---
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "开始创作",
                        style: TextStyle(
                          fontSize: 24, // 字号减小
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E1E1E),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "强大的AI图像编辑\n与智能修图神器。",
                        style: TextStyle(
                          fontSize: 12, // 描述字号减小
                          color: const Color(0xFF1E1E1E).withOpacity(0.5),
                          height: 1.4,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),

                  // --- 右侧：胶囊状按钮 ---
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(50), // 胶囊点击水波纹圆角
                      onTap: () async {
                        final ImagePicker picker = ImagePicker();
                        final XFile? image = await picker.pickImage(
                          source: ImageSource.gallery,
                        );

                        if (image != null && context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ConsultantScreen(
                                selectedImagePath: image.path,
                              ),
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 10.0,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E), // 深色胶囊背景
                          borderRadius: BorderRadius.circular(50), // 胶囊形状
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1E1E1E).withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "导入图片",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.add, size: 16, color: Colors.white),
                          ],
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
    );
  }
}

// === 绘制玻璃边缘的高光折射曲线 (保持不变) ===
class GlassHighlightPainter extends CustomPainter {
  final double animationValue;

  GlassHighlightPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final t = animationValue * 2 * math.pi;

    final Paint strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final double w = size.width;
    final double h = size.height * 0.7;

    final Path path1 = Path();
    path1.moveTo(-w * 0.2, h * 0.7 + 20 * math.cos(t));
    path1.cubicTo(
      w * 0.3,
      h * 0.8 + 30 * math.sin(t),
      w * 0.6,
      h * 0.2 + 20 * math.cos(t + math.pi),
      w * 1.2,
      -h * 0.1,
    );
    strokePaint.shader = ui.Gradient.linear(
      const Offset(0, 0),
      Offset(w, h),
      [
        Colors.white.withOpacity(0.0),
        Colors.white.withOpacity(0.6),
        const Color(0xFF584CF4).withOpacity(0.3),
        Colors.white.withOpacity(0.0),
      ],
      [0.0, 0.4, 0.7, 1.0],
    );
    canvas.drawPath(path1, strokePaint);

    final Path path2 = Path();
    path2.moveTo(-w * 0.1, h * 0.85 + 15 * math.sin(t + math.pi / 2));
    path2.cubicTo(
      w * 0.4,
      h * 0.9 + 20 * math.cos(t),
      w * 0.8,
      h * 0.4 + 25 * math.sin(t + math.pi),
      w * 1.1,
      h * 0.1,
    );
    strokePaint.shader = ui.Gradient.linear(
      Offset(w, 0),
      Offset(0, h),
      [
        Colors.white.withOpacity(0.0),
        Colors.white.withOpacity(0.4),
        Colors.white.withOpacity(0.0),
      ],
      [0.0, 0.5, 1.0],
    );
    strokePaint.strokeWidth = 1.5;
    canvas.drawPath(path2, strokePaint);

    final Path path3 = Path();
    path3.moveTo(w * 0.2, -h * 0.2);
    path3.cubicTo(
      w * 0.4,
      h * 0.2 + 10 * math.sin(t),
      w * 0.1,
      h * 0.6 + 15 * math.cos(t),
      w * 0.9,
      h * 0.9 + 20 * math.sin(t),
    );
    strokePaint.shader = ui.Gradient.linear(
      const Offset(0, 0),
      Offset(w, h),
      [
        const Color(0xFFA855F7).withOpacity(0.0),
        const Color(0xFFA855F7).withOpacity(0.2),
        Colors.white.withOpacity(0.0),
      ],
      [0.0, 0.6, 1.0],
    );
    strokePaint.strokeWidth = 3.0;
    canvas.drawPath(path3, strokePaint);
  }

  @override
  bool shouldRepaint(covariant GlassHighlightPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
