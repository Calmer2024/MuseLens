import 'package:flutter/material.dart';

/// 自定义右滑过渡路由
/// - 进入时：新页面从右侧滑入，前页面轻微向左位移（视差感）
/// - 退出时：当前页面向右滑出，前页面从左侧恢复
class SlideRightRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SlideRightRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // 主页面：从右侧滑入 / 向右滑出
            final slideTween = Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ));

            // 可选：前一个页面的轻微向左位移（视差效果）
            final secondaryTween = Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-0.25, 0.0),
            ).animate(CurvedAnimation(
              parent: secondaryAnimation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ));

            return SlideTransition(
              position: secondaryTween,
              child: SlideTransition(
                position: slideTween,
                child: child,
              ),
            );
          },
        );
}
