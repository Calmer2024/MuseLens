// 在 main.dart 中
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
// 引入欢迎页
import 'presentation/screens/welcome/welcome_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MuseLens',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme, // 确保使用深色主题
      // 将 home 设置为 WelcomeScreen
      home: const WelcomeScreen(),
    );
  }
}
