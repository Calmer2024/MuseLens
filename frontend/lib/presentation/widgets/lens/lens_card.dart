import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/lens_tool_mock.dart';

class LensCard extends StatelessWidget {
  final LensToolMock tool;

  const LensCard({super.key, required this.tool});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // 深炭色背景
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.05), // 微弱的边框
          width: 1,
        ),
        boxShadow: [
          // 只有微弱的阴影，保持扁平感
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),

          // --- 核心：发光图标 ---
          Stack(
            alignment: Alignment.center,
            children: [
              // 1. 背景光晕 (模拟原型图图标背后的光)
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      tool.glowColors.first.withOpacity(0.4),
                      Colors.transparent,
                    ],
                    radius: 0.8,
                  ),
                ),
              ),

              // 2. 渐变图标
              ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: tool.glowColors,
                  ).createShader(bounds);
                },
                child: Icon(
                  tool.icon,
                  size: 56, // 大图标
                  color: Colors.white, // ShaderMask 需要白色底
                ),
              ),

              // 3. (可选) 添加一些微小的装饰点缀，模拟原型图的星光
              Positioned(
                top: 0,
                right: 0,
                child: Icon(
                  Icons.auto_awesome,
                  size: 12,
                  color: tool.glowColors.last.withOpacity(0.8),
                ),
              ),
            ],
          ),

          const Spacer(flex: 1),

          // --- 标题 ---
          Text(
            tool.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(height: 6),

          // --- 副标题 ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              tool.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 11, // 小字体
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
