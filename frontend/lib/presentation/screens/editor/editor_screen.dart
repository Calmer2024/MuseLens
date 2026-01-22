import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart'; // 假设你有svg图标，没有就用Icon
import '../../../core/theme/app_theme.dart';

class EditorScreen extends StatefulWidget {
  final File selectedImage;

  const EditorScreen({super.key, required this.selectedImage});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background, // 保持深色背景
      body: SafeArea(
        child: Column(
          children: [
            // --- 1. Top Header (Back, Title, Save) ---
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "Back",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontFamily: 'Poppins', // 假设用了Poppins
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Title
                  const Text(
                    "Editor",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  // Save Button (White Pill)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "Save",
                      style: TextStyle(
                        color: Colors.black, // 黑字白底
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // --- 2. Main Image Canvas ---
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    image: DecorationImage(
                      image: FileImage(widget.selectedImage),
                      fit: BoxFit.cover, // 或者 contain，看你想怎么展示
                    ),
                  ),
                ),
              ),
            ),

            // --- 3. Bottom Chat Interface ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30), // 底部留多点白
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E), // 深灰色底板
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mock User Message Bubble
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF333333), // 气泡深灰
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "Make it look like a rainy day",
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ),

                  // AI Listening Waveform (模拟图中的紫色声波)
                  // 这里用一个简单的紫色Icon或者自定义绘制模拟
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Icon(
                      Icons.graphic_eq,
                      color: AppTheme.electricIndigo.withOpacity(0.8),
                      size: 40,
                    ),
                  ),

                  // Input Bar
                  Row(
                    children: [
                      // Mic Button
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: AppTheme.electricIndigo, // 紫色
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.mic, color: Colors.white),
                      ),
                      const SizedBox(width: 12),

                      // Text Field
                      Expanded(
                        child: Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF000000), // 输入框纯黑背景
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Ask the AI...",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Send Button
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.electricIndigo,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: const Text(
                          "Send",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
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
    );
  }
}
