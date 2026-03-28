import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../screens/home/home_screen.dart';
import '../screens/lens/lens_library_screen.dart';
import '../screens/community/community_screen.dart';
import '../screens/profile/profile_screen.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeScreen(),
    const LensLibraryScreen(),
    const CommunityScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // 使用 Stack 让导航栏浮动在页面上方 (类似参考图的半透明效果)
      body: Stack(
        children: [
          // 1. 页面内容
          IndexedStack(index: _currentIndex, children: _pages),

          // 2. 自定义底部导航栏
          Positioned(
            left: 20,
            right: 20,
            bottom: 30, // 距离底部有一些悬浮感
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(35), // 胶囊圆角
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
                // 增加一个极细的边框提升质感
                border: Border.all(
                  color: Colors.black.withOpacity(0.1),
                  width: 0.5,
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = constraints.maxWidth / 4;
                  return Stack(
                    children: [
                      // 发光点移动动画
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.fastOutSlowIn,
                        left: _currentIndex * itemWidth,
                        width: itemWidth,
                        bottom: 12, // 图标下方
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      // 导航项
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildNavItem(0, Icons.home_rounded),
                          _buildNavItem(1, Icons.camera_enhance_rounded),
                          _buildNavItem(2, Icons.people_rounded),
                          _buildNavItem(3, Icons.person_rounded),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 核心：光点移动式导航项 ---
  Widget _buildNavItem(int index, IconData icon) {
    final bool isSelected = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.fastOutSlowIn,
              transform: Matrix4.identity()
                ..translate(
                  0.0,
                  isSelected ? -4.0 : 0.0, // 选中时图标稍微向上浮动
                ),
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 400),
                curve: Curves.fastOutSlowIn,
                tween: Tween<double>(end: isSelected ? 1.0 : 0.5),
                builder: (context, opacity, child) {
                  return Icon(
                    icon,
                    color: Colors.black.withOpacity(opacity),
                    size: 26,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
