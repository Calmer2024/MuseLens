import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../screens/editor/editor_screen.dart';

class HeroCreateCard extends StatelessWidget {
  const HeroCreateCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(30),
        // 模拟原型图中右下角的抽象紫色图形背景
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.cardSurface,
            AppTheme.cardSurface,
            AppTheme.primaryPurple.withOpacity(0.2),
            AppTheme.primaryPurple.withOpacity(0.5),
          ],
          stops: const [0.0, 0.6, 0.8, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // 装饰性背景图 (模拟右下角的抽象几何)
          Positioned(
            right: -20,
            bottom: -20,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withOpacity(0.3),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryPurple.withOpacity(0.4),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          ),

          // 内容区域
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Start Creating",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "AI-powered photo editing &\nstyle transfer.",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.6),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                // New Project 按钮
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      // 1. 调用相册
                      final ImagePicker picker = ImagePicker();
                      final XFile? image = await picker.pickImage(
                        source: ImageSource.gallery,
                      );

                      // 2. 如果用户选了图，跳转到 EditorScreen
                      if (image != null && context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditorScreen(
                              selectedImage: File(image.path), // 传参
                            ),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryPurple.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Text(
                        "New Project +",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
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
