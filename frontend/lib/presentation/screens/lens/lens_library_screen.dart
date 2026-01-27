import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/lens_template_mock.dart';
import '../../widgets/lens/lens_market_card.dart';

class LensLibraryScreen extends StatelessWidget {
  const LensLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 获取数据 (确保 LensTemplateMock 已修复)
    final templates = LensTemplateMock.getTemplates();

    // 简单的瀑布流逻辑：将列表分为左右两列
    final leftColumn = <LensTemplateMock>[];
    final rightColumn = <LensTemplateMock>[];

    for (var i = 0; i < templates.length; i++) {
      if (i % 2 == 0) {
        leftColumn.add(templates[i]);
      } else {
        rightColumn.add(templates[i]);
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // --- 1. Header (Title & My Library) ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center, // 确保垂直居中
                  children: [
                    const Text(
                      "Lens Market",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Row(
                      children: [
                        // My Library Button
                        GestureDetector(
                          onTap: () {
                            // TODO: 跳转到我的库
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: const [
                                Icon(
                                  Icons.bookmarks_outlined,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  "My Library",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Search Icon Circle
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.electricIndigo.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.electricIndigo.withOpacity(0.5),
                            ),
                          ),
                          child: const Icon(
                            Icons.search,
                            color: AppTheme.electricIndigo,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // --- 2. Search Bar ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: AppTheme.electricIndigo.withOpacity(0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.electricIndigo.withOpacity(0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Icon(Icons.search, color: Colors.white.withOpacity(0.3)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Find style, effect, or creator...",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // --- 3. Filter Chips ---
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    _buildFilterChip("Recommended", isActive: true),
                    _buildFilterChip("Portrait"),
                    _buildFilterChip("Cyberpunk"),
                    _buildFilterChip("Film"),
                    _buildFilterChip("Anime"),
                    _buildFilterChip("Scenery"),
                  ],
                ),
              ),
            ),

            // --- 4. Masonry Grid (Waterfall Layout) ---
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 100), // 底部留白给导航栏
              sliver: SliverToBoxAdapter(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 左列
                    Expanded(
                      child: Column(
                        children: leftColumn
                            .map((t) => LensMarketCard(template: t))
                            .toList(),
                      ),
                    ),
                    const SizedBox(width: 16), // 列间距
                    // 右列
                    Expanded(
                      child: Column(
                        children: rightColumn
                            .map((t) => LensMarketCard(template: t))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, {bool isActive = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.electricIndigo : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? Colors.transparent : Colors.white.withOpacity(0.2),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.white : Colors.white.withOpacity(0.6),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}
