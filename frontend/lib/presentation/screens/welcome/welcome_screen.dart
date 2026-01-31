import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart'; // 引入谷歌字体库
import '../../../core/theme/app_theme.dart';
import '../../navigation/main_wrapper.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    // 3秒后跳转
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const MainWrapper(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // 纯黑背景
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(), // 顶部弹簧
            // --- 1. 核心组合：Logo + Title (左右排列) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1.1 Logo
                Container(
                      width: 60, // 稍微调小一点以匹配文字高度
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.electricIndigo.withOpacity(0.4),
                            blurRadius: 30,
                            spreadRadius: -5,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          "assets/images/app_icon.png",
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                    .animate()
                    .fade(duration: 600.ms)
                    .slideX(
                      begin: -0.2,
                      end: 0,
                      duration: 600.ms,
                      curve: Curves.easeOutBack,
                    ), // 从左侧滑入

                const SizedBox(width: 20), // 间距
                // 1.2 Title (使用更有设计感的字体)
                Text(
                      "MuseLens",
                      style: GoogleFonts.orbitron(
                        // 使用 Orbitron 字体增强科技感
                        textStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 36, // 字号放大
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    )
                    .animate()
                    .fade(duration: 600.ms, delay: 200.ms) // 稍微晚一点出现
                    .slideX(
                      begin: 0.2,
                      end: 0,
                      duration: 600.ms,
                      curve: Curves.easeOutBack,
                    ), // 从右侧滑入
              ],
            ),

            const SizedBox(height: 24),

            // --- 2. Slogan (保持高级留白感) ---
            Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "AI Powered",
                      style: GoogleFonts.montserrat(
                        // 副标题用干净的无衬线体
                        textStyle: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                          letterSpacing: 3.0, // 极宽字间距
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppTheme.electricIndigo.withOpacity(
                            0.8,
                          ), // 紫色小圆点
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Text(
                      "Awaken Your Muse",
                      style: GoogleFonts.montserrat(
                        textStyle: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                          letterSpacing: 3.0,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                )
                .animate()
                .fadeIn(delay: 600.ms, duration: 800.ms)
                .moveY(begin: 10, end: 0),

            const Spacer(), // 底部弹簧
            // --- 3. 底部版权 ---
            Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: Text(
                "© 2026 MuseLens Inc.",
                style: GoogleFonts.robotoMono(
                  // 底部用等宽字体增加极客感
                  textStyle: TextStyle(
                    color: Colors.white.withOpacity(0.2),
                    fontSize: 10,
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 1000.ms),
          ],
        ),
      ),
    );
  }
}
