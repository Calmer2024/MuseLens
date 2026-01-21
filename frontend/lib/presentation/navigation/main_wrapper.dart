import 'package:flutter/material.dart';
import '../screens/home/home_screen.dart';
import '../../core/theme/app_theme.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeScreen(),
    const Center(child: Text("Edit Tools")), // 占位
    const Center(child: Text("Community")), // 占位
    const Center(child: Text("Profile")), // 占位
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. 页面内容
          _pages[_currentIndex],

          // 2. 底部悬浮导航栏 (还原原型图效果)
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: AppTheme.navBarColor.withOpacity(0.95),
                borderRadius: BorderRadius.circular(35),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(0, Icons.home_rounded, "Home"),
                  _buildNavItem(1, Icons.tune_rounded, "Edit Tools"),
                  _buildNavItem(2, Icons.bubble_chart_rounded, "Community"),
                  _buildNavItem(3, Icons.person_rounded, "Profile"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? AppTheme.primaryPurple : Colors.grey,
            size: 28,
          ),
          const SizedBox(height: 4),
          if (isSelected) // 原型图中选中状态下可能不显示文字，或者显示高亮文字，这里做微调
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.primaryPurple : Colors.grey,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}
