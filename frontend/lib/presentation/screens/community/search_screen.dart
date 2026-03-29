import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  // 1. 历史记录 (保留中文，模拟用户输入习惯)
  final List<String> _historyTags = [
    "赛博朋克",
    "人像精修",
    "日系",
    "建筑摄影",
    "夜景",
    "OOTD",
  ];

  // 2. 猜你想搜 (英文)
  final List<String> _guessTags = [
    "复古胶片",
    "美食",
    "喵星人",
    "极简",
    "旅行",
    "手工",
    "插画",
  ];

  // 3. 热搜榜 (英文)
  final List<Map<String, dynamic>> _trendingList = [
    {"rank": 1, "title": "霓虹东京V2", "isHot": true},
    {"rank": 2, "title": "吉卜力风格", "isHot": true},
    {"rank": 3, "title": "冷色调", "isHot": false},
    {"rank": 4, "title": "胶片模拟", "isHot": false},
    {"rank": 5, "title": "人像精修", "isHot": false},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // --- 1. 顶部搜索栏 ---
            _buildSearchBar(context),

            // --- 2. 可滚动内容区 ---
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2.1 搜索记录
                    _buildSectionHeader("搜索历史", showDelete: true),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _historyTags
                          .map((tag) => _buildHistoryChip(tag))
                          .toList(),
                    ),

                    const SizedBox(height: 32),

                    // 2.2 猜你想搜
                    _buildSectionHeader("猜你想搜"),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _guessTags
                          .map((tag) => _buildGuessChip(tag))
                          .toList(),
                    ),

                    const SizedBox(height: 32),

                    // 2.3 热搜榜
                    _buildSectionHeader("MuseLens 热搜榜"),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: _trendingList.map((item) {
                          return _buildTrendingRow(item);
                        }).toList(),
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

  // --- 组件构建方法 ---

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // 返回按钮
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Colors.black87, size: 24),
          ),
          const SizedBox(width: 16),

          // 搜索框
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.black87, fontSize: 14),
                cursorColor: AppTheme.electricIndigo,
                decoration: InputDecoration(
                  hintText: "搜索灵感...",
                  hintStyle: TextStyle(
                    color: Colors.black38,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.white.withOpacity(0.3),
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10,
                  ), // 垂直居中
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // 搜索按钮
          Text(
            "搜索",
            style: const TextStyle(
              color: AppTheme.electricIndigo,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {bool showDelete = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 16, // 标准字号
            fontWeight: FontWeight.bold,
          ),
        ),
        if (showDelete)
          Icon(
            Icons.delete_outline,
            color: Colors.black45,
            size: 18,
          ),
      ],
    );
  }

  // 历史标签 (深灰背景)
  Widget _buildHistoryChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: Colors.black87, fontSize: 13),
      ),
    );
  }

  // 猜你想搜标签 (紫色描边)
  Widget _buildGuessChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.electricIndigo.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: const TextStyle(color: AppTheme.electricIndigo, fontSize: 13),
      ),
    );
  }

  // 热搜行
  Widget _buildTrendingRow(Map<String, dynamic> item) {
    final int rank = item['rank'];
    Color rankColor;
    if (rank == 1)
      rankColor = const Color(0xFFFFD700); // Gold
    else if (rank == 2)
      rankColor = const Color(0xFFC0C0C0); // Silver
    else if (rank == 3)
      rankColor = const Color(0xFFCD7F32); // Bronze
    else
      rankColor = Colors.black38;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: rank < 5
                ? Colors.black.withOpacity(0.05)
                : Colors.transparent,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // 排名
          SizedBox(
            width: 24,
            child: Text(
              "$rank",
              style: TextStyle(
                color: rankColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 标题
          Expanded(
            child: Text(
              item['title'],
              style: const TextStyle(color: Colors.black87, fontSize: 14),
            ),
          ),

          // Hot 图标
          if (item['isHot']) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.local_fire_department,
              color: Color(0xFFFF4757),
              size: 16,
            ),
          ],
        ],
      ),
    );
  }
}
