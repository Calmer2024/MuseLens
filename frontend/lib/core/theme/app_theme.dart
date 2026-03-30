import 'package:flutter/material.dart';

class AppTheme {
  // 1. 提取原型图颜色
  static const Color background = Color(0xFF121212); // 深色背景 (虽为浅色模式，保留变量以备用)
  static const Color cardSurface = Color(0xFF1E1E1E); // 卡片背景
  static const Color primaryPurple = Color(0xFF584CF4); // 原型图中的亮紫色
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGrey = Color(0xFFAAAAAA);
  static const Color navBarColor = Color(0xFF252525); // 底部导航栏颜色
  // Profile 界面专用的电光靛蓝
  static const Color electricIndigo = Color(0xFF6C5CE7);

  // 2. 移除 darkTheme，因为需求要求全应用白色主题

  // 3. 定义浅色模式主题
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white, // 设置为主配色白色
      primaryColor: primaryPurple,
      textTheme: ThemeData.light().textTheme,
      colorScheme: const ColorScheme.light(
        primary: primaryPurple,
        surface: Colors.white,
      ),
    );
  }
}
