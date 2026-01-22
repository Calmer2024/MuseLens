import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class CommunitySearchBar extends StatelessWidget {
  const CommunitySearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.cardSurface, // 深灰色背景
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(Icons.search, color: Colors.white.withOpacity(0.5)),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Explore Recipes & Creators",
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // 筛选按钮
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppTheme.cardSurface,
            borderRadius: BorderRadius.circular(16), // 方形圆角
            border: Border.all(color: Colors.white10),
          ),
          child: Icon(Icons.tune_rounded, color: Colors.white.withOpacity(0.7)),
        ),
      ],
    );
  }
}
