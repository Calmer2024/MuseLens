import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/market_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/market_models.dart';
import '../auth/login_screen.dart';
import '../lens/market_lens_detail_screen.dart';
import '../lens/market_lens_editor_screen.dart';
import '../../widgets/lens/market_lens_card.dart';

class MyLibraryScreen extends ConsumerStatefulWidget {
  const MyLibraryScreen({super.key});

  @override
  ConsumerState<MyLibraryScreen> createState() => _MyLibraryScreenState();
}

class _MyLibraryScreenState extends ConsumerState<MyLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _tabIndex = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.white,
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
                      _buildCircleButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          '我的透镜',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      _buildCircleButton(
                        icon: Icons.add_rounded,
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        onTap: () => _openEditor(currentUser != null),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentUser == null
                        ? '登录后查看你的安装、收藏和已发布透镜'
                        : '管理你安装、收藏以及发布到市场的全部透镜',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black.withOpacity(0.46),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        _buildTabButton(0, '已安装'),
                        _buildTabButton(1, '已收藏'),
                        _buildTabButton(2, '我发布的'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: '搜索名称、作者、分类',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(color: AppTheme.electricIndigo),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: currentUser == null
                  ? _buildGuestState()
                  : _buildMarketCollection(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 58,
              color: Colors.black.withOpacity(0.16),
            ),
            const SizedBox(height: 16),
            const Text(
              '登录后即可同步透镜库',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '安装、收藏和你发布到市场的透镜都会汇总在这里。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black.withOpacity(0.46),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text('去登录'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketCollection() {
    final asyncValue = switch (_tabIndex) {
      0 => ref.watch(marketInstalledLensesProvider),
      1 => ref.watch(marketFavoriteLensesProvider),
      _ => ref.watch(marketAuthoredLensesProvider),
    };

    return asyncValue.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _buildFeedbackState(
        icon: Icons.error_outline_rounded,
        title: '透镜库加载失败',
        content: '$error',
        actionLabel: '重试',
        onAction: _refreshProviders,
      ),
      data: (lenses) {
        final filtered = _filterByKeyword(lenses);
        if (filtered.isEmpty) {
          return _buildFeedbackState(
            icon: Icons.auto_awesome_mosaic_outlined,
            title: _tabIndex == 2 ? '还没有发布透镜' : '这里还是空的',
            content: _tabIndex == 2
                ? '创建一个市场透镜后，就会显示在这里。'
                : '试试去市场安装或收藏一些透镜吧。',
            actionLabel: _tabIndex == 2 ? '发布透镜' : null,
            onAction: _tabIndex == 2 ? () => _openEditor(true) : null,
          );
        }

        return MasonryGridView.count(
          physics: const BouncingScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final lens = filtered[index];
            return MarketLensCard(
              lens: lens,
              bannerText: _tabBannerText,
              bannerIcon: _tabBannerIcon,
              onTap: () => _openDetail(lens),
            );
          },
        );
      },
    );
  }

  List<MarketLensView> _filterByKeyword(List<MarketLensView> lenses) {
    final keyword = _searchController.text.trim().toLowerCase();
    if (keyword.isEmpty) {
      return lenses;
    }
    return lenses.where((lens) {
      final text = [
        lens.lens.name,
        lens.lens.description,
        lens.lens.category ?? '',
        lens.author.displayName,
      ].join(' ').toLowerCase();
      return text.contains(keyword);
    }).toList();
  }

  Widget _buildTabButton(int index, String label) {
    final selected = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _tabIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.black : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    Color backgroundColor = Colors.white,
    Color foregroundColor = Colors.black87,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black.withOpacity(0.06)),
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

  String get _tabBannerText => switch (_tabIndex) {
        0 => '已安装',
        1 => '已收藏',
        _ => '已发布',
      };

  IconData get _tabBannerIcon => switch (_tabIndex) {
        0 => Icons.download_done_rounded,
        1 => Icons.favorite_rounded,
        _ => Icons.publish_rounded,
      };

  Future<void> _openDetail(MarketLensView lens) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MarketLensDetailScreen(lensId: lens.lens.lensId),
      ),
    );
    _refreshProviders();
  }

  Future<void> _openEditor(bool isLoggedIn) async {
    if (!isLoggedIn) {
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
    if (result != null) {
      _refreshProviders();
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MarketLensDetailScreen(lensId: result),
        ),
      );
      _refreshProviders();
    }
  }

  void _refreshProviders() {
    ref.invalidate(marketInstalledLensesProvider);
    ref.invalidate(marketFavoriteLensesProvider);
    ref.invalidate(marketAuthoredLensesProvider);
    ref.invalidate(marketLensListProvider);
  }
}
