import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // 1. 提取原型图颜色
  static const Color background = Color(0xFF121212); // 深色背景
  static const Color cardSurface = Color(0xFF1E1E1E); // 卡片背景
  static const Color primaryPurple = Color(0xFF584CF4); // 原型图中的亮紫色
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGrey = Color(0xFFAAAAAA);
  static const Color navBarColor = Color(0xFF252525); // 底部导航栏颜色
  // Profile 界面专用的电光靛蓝
  static const Color electricIndigo = Color(0xFF6C5CE7);

  // 2. 定义全局主题
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primaryPurple,
      textTheme: GoogleFonts.poppinsTextTheme(
        ThemeData.dark().textTheme,
      ), // 使用 Poppins 字体
      colorScheme: const ColorScheme.dark(
        primary: primaryPurple,
        surface: cardSurface,
      ),
    );
  }
}
