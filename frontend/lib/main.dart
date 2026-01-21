import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'presentation/navigation/main_wrapper.dart';

void main() {
  // 设置状态栏透明，使应用沉浸式
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const NanoBananaApp());
}

class NanoBananaApp extends StatelessWidget {
  const NanoBananaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nano Banana',
      debugShowCheckedModeBanner: false, // 去掉 Debug 标签
      theme: AppTheme.darkTheme, // 应用我们定义的主题
      home: const MainWrapper(), // 启动主导航页
    );
  }
}
