import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/community_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/community_models.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({
    super.key,
    this.initialKeyword,
  });

  final String? initialKeyword;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _searchController;
  final List<String> _history = ['夜景', '人像', '建筑', '胶片', '赛博朋克'];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialKeyword ?? '');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(communityTagsProvider);
    final keyword = _searchController.text.trim();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: tagsAsync.when(
                data: (tags) {
                  final filtered = keyword.isEmpty
                      ? tags
                      : tags
                          .where((tag) => tag.name.toLowerCase().contains(keyword.toLowerCase()))
                          .toList();
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('搜索历史', showClear: _history.isNotEmpty),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _history.map((tag) => _buildChip(tag, onTap: () => _submit(tag))).toList(),
                        ),
                        const SizedBox(height: 28),
                        _buildSectionHeader('热门标签'),
                        const SizedBox(height: 12),
                        if (tags.isEmpty)
                          Text(
                            '还没有可用标签',
                            style: TextStyle(color: Colors.black.withOpacity(0.4)),
                          )
                        else
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: tags.take(10).map((tag) {
                              return _buildOutlineChip(
                                '#${tag.name}',
                                suffix: '${tag.postCount}',
                                onTap: () => _submit(tag.name),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 28),
                        _buildSectionHeader(keyword.isEmpty ? 'MuseLens 热门榜' : '搜索结果'),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.black.withOpacity(0.05)),
                          ),
                          child: filtered.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Text(
                                    '没有找到与“$keyword”相关的标签',
                                    style: TextStyle(
                                      color: Colors.black.withOpacity(0.48),
                                      fontSize: 13,
                                    ),
                                  ),
                                )
                              : Column(
                                  children: filtered.asMap().entries.map((entry) {
                                    return _buildTrendingRow(entry.key + 1, entry.value);
                                  }).toList(),
                                ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '标签加载失败：$error',
                      style: TextStyle(color: Colors.black.withOpacity(0.5)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Colors.black87, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(999),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                onSubmitted: _submit,
                cursorColor: AppTheme.electricIndigo,
                style: const TextStyle(color: Colors.black87, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '搜索标签，如 夜景 / 人像',
                  hintStyle: TextStyle(color: Colors.black.withOpacity(0.35)),
                  prefixIcon: const Icon(Icons.search, color: Colors.black45, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          GestureDetector(
            onTap: () => _submit(_searchController.text),
            child: const Text(
              '搜索',
              style: TextStyle(
                color: AppTheme.electricIndigo,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {bool showClear = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (showClear)
          GestureDetector(
            onTap: () => setState(_history.clear),
            child: const Icon(Icons.delete_outline, color: Colors.black45, size: 18),
          ),
      ],
    );
  }

  Widget _buildChip(String label, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.black87, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildOutlineChip(
    String label, {
    String? suffix,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.electricIndigo.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(color: AppTheme.electricIndigo, fontSize: 13),
            ),
            if (suffix != null) ...[
              const SizedBox(width: 6),
              Text(
                suffix,
                style: const TextStyle(color: Colors.black45, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingRow(int rank, CommunityTag tag) {
    final color = switch (rank) {
      1 => const Color(0xFFFFA502),
      2 => const Color(0xFF9AA0A6),
      3 => const Color(0xFFCD7F32),
      _ => Colors.black38,
    };

    return InkWell(
      onTap: () => _submit(tag.name),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.black.withOpacity(0.05)),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '$rank',
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${tag.name}',
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${tag.postCount} 条帖子',
                    style: TextStyle(color: Colors.black.withOpacity(0.42), fontSize: 11),
                  ),
                ],
              ),
            ),
            if (rank <= 2)
              const Icon(
                Icons.local_fire_department,
                color: Color(0xFFFF4757),
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  void _submit(String value) {
    final keyword = value.trim().replaceFirst('#', '');
    if (keyword.isEmpty) {
      Navigator.pop(context, '');
      return;
    }
    setState(() {
      _history.remove(keyword);
      _history.insert(0, keyword);
      if (_history.length > 8) {
        _history.removeLast();
      }
    });
    Navigator.pop(context, keyword);
  }
}
