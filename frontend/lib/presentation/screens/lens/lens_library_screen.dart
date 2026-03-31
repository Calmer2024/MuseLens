import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../core/providers/market_provider.dart';
import '../../../data/models/market_models.dart';
import '../../widgets/lens/market_lens_card.dart';
import '../library/my_library_screen.dart';
import 'market_lens_detail_screen.dart';

class LensLibraryScreen extends ConsumerStatefulWidget {
  const LensLibraryScreen({super.key});

  @override
  ConsumerState<LensLibraryScreen> createState() => _LensLibraryScreenState();
}

class _LensLibraryScreenState extends ConsumerState<LensLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedTagName;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = MarketLensQuery(
      status: 'active',
      keyword: _searchController.text.trim(),
      tagName: _selectedTagName,
    );
    final templatesAsync = ref.watch(marketLensListProvider(query));
    final tagsAsync = ref.watch(marketTemplateTagsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: '搜索模板、作者或标签',
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: Colors.black.withOpacity(0.08),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(color: Colors.black),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildCircleButton(
                        icon: Icons.bookmark_outline_rounded,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const MyLibraryScreen(),
                            ),
                          );
                          _refreshProviders();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: tagsAsync.when(
                      loading: () => const SizedBox(
                        height: 24,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      error: (_, __) => _buildTagRow(const <MarketTag>[]),
                      data: _buildTagRow,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: templatesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _buildFeedbackState(
                  icon: Icons.error_outline_rounded,
                  title: '模板市场加载失败',
                  content: '$error',
                  actionLabel: '重试',
                  onAction: _refreshProviders,
                ),
                data: (templates) {
                  if (templates.isEmpty) {
                    return _buildFeedbackState(
                      icon: Icons.auto_awesome_mosaic_outlined,
                      title: '没有找到匹配模板',
                      content: '换个关键词或者切换标签再试试看。',
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async => _refreshProviders(),
                    child: MasonryGridView.count(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                      itemCount: templates.length,
                      itemBuilder: (context, index) {
                        final lens = templates[index];
                        return MarketLensCard(
                          lens: lens,
                          onTap: () => _openDetail(lens),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagRow(List<MarketTag> tags) {
    final entries = <String?>[null, ...tags.map((item) => item.name)];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: entries.map((tagName) {
          final isSelected = _selectedTagName == tagName;
          final label = tagName ?? '全部';
          return Padding(
            padding: const EdgeInsets.only(right: 18),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTagName = tagName;
                });
              },
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.black : Colors.grey.shade500,
                ),
                child: Text(label),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        child: Icon(icon, color: Colors.black87),
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
        builder: (_) => MarketLensDetailScreen(lensId: lens.lens.templateId),
      ),
    );
    _refreshProviders();
  }

  void _refreshProviders() {
    ref.invalidate(marketLensListProvider);
    ref.invalidate(marketLensDetailProvider);
    ref.invalidate(marketTemplateTagsProvider);
    ref.invalidate(marketFavoriteLensesProvider);
    ref.invalidate(marketAuthoredLensesProvider);
  }
}
