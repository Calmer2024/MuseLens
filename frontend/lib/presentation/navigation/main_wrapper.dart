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
      backgroundColor: AppTheme.background,
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
                color: const Color(0xFF1E1E1E).withOpacity(0.9), // 半透明深炭色
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
                  color: Colors.white.withOpacity(0.1),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(0, Icons.home_rounded, "Home"),
                  _buildNavItem(
                    1,
                    Icons.camera_enhance_rounded,
                    "Lens",
                  ), // 使用更像光圈的图标
                  _buildNavItem(2, Icons.people_rounded, "Community"),
                  _buildNavItem(3, Icons.person_rounded, "Profile"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 核心：胶囊式导航项 ---
  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: isSelected
            ? const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
            : const EdgeInsets.all(12),
        decoration: BoxDecoration(
          // 选中时显示紫色发光胶囊，未选中透明
          color: isSelected ? AppTheme.electricIndigo : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          // 选中时的光晕效果
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.electricIndigo.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图标
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
              size: 24,
            ),

            // 选中时显示的文字 (水平对齐)
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
