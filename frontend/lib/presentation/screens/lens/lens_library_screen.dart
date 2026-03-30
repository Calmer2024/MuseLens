import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/market_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/market_models.dart';
import '../../../data/models/user_model.dart';
import '../../widgets/lens/market_lens_card.dart';
import '../auth/login_screen.dart';
import '../library/my_library_screen.dart';
import 'market_lens_detail_screen.dart';
import 'market_lens_editor_screen.dart';

class LensLibraryScreen extends ConsumerStatefulWidget {
  const LensLibraryScreen({super.key});

  @override
  ConsumerState<LensLibraryScreen> createState() => _LensLibraryScreenState();
}

class _LensLibraryScreenState extends ConsumerState<LensLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();

  static const List<MapEntry<String, String>> _categories = [
    MapEntry('all', '推荐'),
    MapEntry('portrait', '人像'),
    MapEntry('anime', '二次元'),
    MapEntry('cyberpunk', '赛博朋克'),
    MapEntry('product', '电商'),
    MapEntry('sketch', '素描'),
    MapEntry('food', '美食'),
  ];

  String _selectedCategory = 'all';
  String _selectedStatus = 'active';
  bool _officialOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = MarketLensQuery(
      category: _selectedCategory == 'all' ? null : _selectedCategory,
      status: _selectedStatus,
      isOfficial: _officialOnly ? true : null,
      keyword: _searchController.text.trim(),
    );
    final lensesAsync = ref.watch(marketLensListProvider(query));
    final currentUser = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '透镜市场',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '浏览、安装、收藏并发布你的工作流透镜',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black.withOpacity(0.46),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildHeaderButton(
                        icon: Icons.bookmarks_outlined,
                        label: '我的库',
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const MyLibraryScreen()),
                          );
                          _refreshProviders();
                        },
                      ),
                      const SizedBox(width: 10),
                      _buildCircleButton(
                        icon: Icons.add_rounded,
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        onTap: () => _openEditor(currentUser),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: '搜索风格、作者、分类或 lens_key',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: AppTheme.electricIndigo),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _categories.map((entry) {
                              final selected = _selectedCategory == entry.key;
                              return Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: ChoiceChip(
                                  selected: selected,
                                  label: Text(entry.value),
                                  selectedColor: Colors.black,
                                  labelStyle: TextStyle(
                                    color: selected ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  onSelected: (_) {
                                    setState(() {
                                      _selectedCategory = entry.key;
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilterChip(
                        selected: _officialOnly,
                        label: const Text('官方'),
                        onSelected: (value) {
                          setState(() {
                            _officialOnly = value;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          setState(() {
                            _selectedStatus = value;
                          });
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'active', child: Text('active')),
                          PopupMenuItem(value: 'deprecated', child: Text('deprecated')),
                          PopupMenuItem(value: 'removed', child: Text('removed')),
                        ],
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black.withOpacity(0.06)),
                          ),
                          child: const Icon(Icons.tune_rounded, size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: lensesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _buildFeedbackState(
                  icon: Icons.error_outline_rounded,
                  title: '市场加载失败',
                  content: '$error',
                  actionLabel: '重试',
                  onAction: () => ref.invalidate(marketLensListProvider(query)),
                ),
                data: (lenses) {
                  if (lenses.isEmpty) {
                    return _buildFeedbackState(
                      icon: Icons.auto_awesome_mosaic_outlined,
                      title: '没有符合条件的透镜',
                      content: '试试切换分类、关闭官方筛选，或者搜索别的关键词。',
                    );
                  }

                  return MasonryGridView.count(
                    physics: const BouncingScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                    itemCount: lenses.length,
                    itemBuilder: (context, index) {
                      final lens = lenses[index];
                      return MarketLensCard(
                        lens: lens,
                        onTap: () => _openDetail(lens),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.black87),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: foregroundColor),
      ),
    );
  }

  Widget _buildFeedbackState({
    required IconData icon,
    required String title,
    required String content,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.black.withOpacity(0.18)),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black.withOpacity(0.46),
                height: 1.45,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openDetail(MarketLensView lens) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MarketLensDetailScreen(lensId: lens.lens.lensId),
      ),
    );
    _refreshProviders();
  }

  Future<void> _openEditor(User? currentUser) async {
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录后再发布透镜')),
      );
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    final result = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => const MarketLensEditorScreen()),
    );
    if (result != null && mounted) {
      _refreshProviders();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MarketLensDetailScreen(lensId: result),
        ),
      );
      _refreshProviders();
    }
  }

  void _refreshProviders() {
    ref.invalidate(marketLensListProvider);
    ref.invalidate(marketInstalledLensesProvider);
    ref.invalidate(marketFavoriteLensesProvider);
    ref.invalidate(marketAuthoredLensesProvider);
  }
}
