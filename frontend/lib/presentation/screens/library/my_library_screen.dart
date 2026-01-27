import 'package:flutter/material.dart';
import 'dart:ui'; // 用于 ImageFilter
import '../../../core/theme/app_theme.dart';
import '../../../data/models/lens_template_mock.dart';
import '../../widgets/lens/lens_market_card.dart';

class MyLibraryScreen extends StatefulWidget {
  const MyLibraryScreen({super.key});

  @override
  State<MyLibraryScreen> createState() => _MyLibraryScreenState();
}

class _MyLibraryScreenState extends State<MyLibraryScreen> {
  // 控制 Saved / Created 切换 (0 = Saved, 1 = Created)
  int _selectedIndex = 0;

  // 模拟数据
  final List<LensTemplateMock> _savedTemplates = LensTemplateMock.getTemplates()
      .sublist(0, 6);
  final List<LensTemplateMock> _createdTemplates =
      LensTemplateMock.getTemplates().sublist(6, 9);

  @override
  Widget build(BuildContext context) {
    final currentTemplates = _selectedIndex == 0
        ? _savedTemplates
        : _createdTemplates;

    // 瀑布流逻辑
    final leftColumn = <LensTemplateMock>[];
    final rightColumn = <LensTemplateMock>[];
    for (var i = 0; i < currentTemplates.length; i++) {
      if (i % 2 == 0)
        leftColumn.add(currentTemplates[i]);
      else
        rightColumn.add(currentTemplates[i]);
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // --- 1. 固定头部区域 ---
            Container(
              color: AppTheme.background,
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1.1 导航栏
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 左侧：返回 + 标题
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Text(
                              "My Library",
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        // 右侧：设置 + 新建
                        Row(
                          children: [
                            const Icon(
                              Icons.settings_outlined,
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(width: 20),
                            Icon(
                              Icons.add,
                              color: AppTheme.electricIndigo,
                              size: 28,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 1.2 分段控制器
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildSegmentButton(0, "Saved"),
                          _buildSegmentButton(1, "Created"),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 1.3 搜索栏
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(23),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          Icon(
                            Icons.search,
                            color: Colors.white.withOpacity(0.3),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Search my collection...",
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

                  const SizedBox(height: 20),

                  // 1.4 文件夹分组
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _buildCollectionCard(
                          Icons.layers,
                          "All Lenses",
                          isActive: true,
                        ),
                        _buildCollectionCard(Icons.folder_open, "Portraits"),
                        _buildCollectionCard(Icons.folder_open, "Scenery"),
                        _buildAddGroupCard(),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // --- 2. 滚动内容区域 ---
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: leftColumn
                            .map((t) => _buildLibraryCard(t))
                            .toList(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: rightColumn
                            .map((t) => _buildLibraryCard(t))
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

  // --- 组件构建方法 ---

  Widget _buildSegmentButton(int index, String text) {
    final bool isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.electricIndigo : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionCard(
    IconData icon,
    String label, {
    bool isActive = false,
  }) {
    return Container(
      width: 80,
      height: 80,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? AppTheme.electricIndigo
              : Colors.white.withOpacity(0.1),
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppTheme.electricIndigo.withOpacity(0.2),
                  blurRadius: 8,
                ),
              ]
            : [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isActive
                ? AppTheme.electricIndigo
                : Colors.white.withOpacity(0.6),
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white.withOpacity(0.6),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddGroupCard() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: CustomPaint(
        painter: _DashedBorderPainter(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, color: AppTheme.electricIndigo, size: 28),
            const SizedBox(height: 8),
            Text(
              "New Group",
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 核心修改：库专用卡片 ---
  Widget _buildLibraryCard(LensTemplateMock template) {
    return Stack(
      children: [
        // 1. 基础卡片
        LensMarketCard(template: template),

        // 2. 左上角：Downloaded 状态 (解决遮挡问题，移到顶部)
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6), // 深色背景衬托
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.electricIndigo.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  size: 10,
                  color: AppTheme.electricIndigo,
                ),
                const SizedBox(width: 4),
                Text(
                  "Downloaded",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        // 3. 右上角：弹出菜单 (置顶/删除)
        Positioned(
          top: 6,
          right: 6,
          child: Theme(
            data: Theme.of(context).copyWith(
              // 自定义菜单样式
              cardColor: const Color(0xFF2A2A2A),
              popupMenuTheme: PopupMenuThemeData(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: const Color(0xFF2A2A2A),
                textStyle: const TextStyle(color: Colors.white),
              ),
            ),
            child: PopupMenuButton<String>(
              offset: const Offset(0, 40), // 菜单向下偏移一点
              icon: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    width: 32,
                    height: 32,
                    color: Colors.black.withOpacity(0.4),
                    child: const Icon(
                      Icons.more_horiz,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
              onSelected: (String value) {
                // TODO: 处理点击事件
                if (value == 'pin') {
                  print("Pin to top");
                } else if (value == 'delete') {
                  print("Delete template");
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'pin',
                  child: Row(
                    children: [
                      Icon(
                        Icons.push_pin_outlined,
                        color: Colors.white70,
                        size: 18,
                      ),
                      SizedBox(width: 12),
                      Text("Pin to Top", style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                const PopupMenuDivider(height: 1),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                        size: 18,
                      ),
                      SizedBox(width: 12),
                      Text(
                        "Delete",
                        style: TextStyle(fontSize: 14, color: Colors.redAccent),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(16),
        ),
      );

    Path dashPath = Path();
    double dashWidth = 5.0;
    double dashSpace = 5.0;
    double distance = 0.0;
    for (PathMetric pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
