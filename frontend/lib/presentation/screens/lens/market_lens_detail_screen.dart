import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/market_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/chat_models.dart';
import '../../../data/models/market_models.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/market_repository.dart';
import '../../widgets/lens/market_lens_visuals.dart';
import '../../widgets/shared/adaptive_media.dart';
import '../auth/login_screen.dart';
import '../community/chat_friend_picker_screen.dart';
import 'template_apply_sheet.dart';

class MarketLensDetailScreen extends ConsumerStatefulWidget {
  final int lensId;

  const MarketLensDetailScreen({super.key, required this.lensId});

  @override
  ConsumerState<MarketLensDetailScreen> createState() =>
      _MarketLensDetailScreenState();
}

class _MarketLensDetailScreenState
    extends ConsumerState<MarketLensDetailScreen> {
  double _splitValue = 0.5;
  int? _selectedVersionId;
  bool _isFavoriting = false;
  bool _isApplying = false;
  MarketLensApplyResult? _latestApplyResult;

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(marketLensDetailProvider(widget.lensId));

    return detailAsync.when(
      loading: () => _buildScaffold(
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => _buildScaffold(
        body: _buildStateView(
          icon: Icons.error_outline_rounded,
          title: '模板详情加载失败',
          content: '$error',
          actionLabel: '重试',
          onAction: _refreshMarketState,
        ),
      ),
      data: _buildContent,
    );
  }

  Widget _buildContent(MarketLensDetailData data) {
    final lens = data.lens;
    final visual = MarketLensVisualResolver.resolve(lens.lens);
    final version = _resolveSelectedVersion(data);

    return _buildScaffold(
      topActions: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: _buildCircleButton(
            icon: Icons.share_outlined,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatFriendPickerScreen(
                    shareDraft: ChatComposerShareDraft.marketLens(
                      lensId: lens.lens.templateId,
                      title: lens.lens.title,
                      summary: lens.lens.description.trim(),
                      coverUrl: lens.lens.primaryImageUrl,
                      authorName: lens.author.displayName,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        _buildCircleButton(
          icon: lens.isFavorited
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          foregroundColor: lens.isFavorited
              ? const Color(0xFFE55C78)
              : Colors.black87,
          onTap: _isFavoriting ? null : () => _toggleFavorite(data),
        ),
      ],
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 150),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroPreview(visual),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(lens),
                  const SizedBox(height: 18),
                  _buildStats(lens.lens),
                  if (lens.lens.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(
                      lens.lens.description,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.68),
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  _buildSectionTitle('版本'),
                  const SizedBox(height: 12),
                  if (data.versions.isEmpty)
                    _buildInfoCard(
                      title: '模板还没有可用版本',
                      content: '等作者发布版本后，就可以直接应用这个模板了。',
                    )
                  else ...[
                    _buildVersionTabs(data.versions),
                    if (version != null) ...[
                      const SizedBox(height: 14),
                      _buildVersionCard(version),
                    ],
                  ],
                  if (_latestApplyResult != null) ...[
                    const SizedBox(height: 28),
                    _buildSectionTitle('最近一次应用结果'),
                    const SizedBox(height: 12),
                    _buildApplyResultCard(_latestApplyResult!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
          child: SizedBox(
            height: 58,
            child: ElevatedButton(
              onPressed: !_isApplying && version != null
                  ? () => _openApplySheet(data, version)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: _isApplying
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      version == null ? '暂无可用版本' : '应用模板',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Scaffold _buildScaffold({
    required Widget body,
    Widget? bottomNavigationBar,
    List<Widget>? topActions,
  }) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -40,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.electricIndigo.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          body,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCircleButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    if (topActions != null) Row(children: topActions),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: bottomNavigationBar,
    );
  }

  Widget _buildHeroPreview(MarketLensVisual visual) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height * 0.48;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          buildAdaptiveImage(
            visual.afterImage,
            fit: BoxFit.cover,
            placeholder: Container(color: const Color(0xFFF1F3F6)),
            errorWidget: Container(color: const Color(0xFFF1F3F6)),
          ),
          ClipRect(
            clipper: _SliderClipper(_splitValue),
            child: buildAdaptiveImage(
              visual.beforeImage,
              fit: BoxFit.cover,
              placeholder: Container(color: const Color(0xFFF1F3F6)),
              errorWidget: Container(color: const Color(0xFFF1F3F6)),
            ),
          ),
          Positioned(
            left: width * _splitValue - 1.5,
            top: 0,
            bottom: 0,
            child: Container(width: 3, color: Colors.white),
          ),
          Positioned(
            left: width * _splitValue - 48,
            top: height / 2 - 24,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _splitValue = (details.globalPosition.dx / width).clamp(
                    0.0,
                    1.0,
                  );
                });
              },
              child: Container(
                width: 96,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('原图', style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(width: 8),
                    Icon(Icons.drag_indicator_rounded, size: 14),
                    SizedBox(width: 8),
                    Text('效果', style: TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(MarketLensView lens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                lens.lens.title,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                  height: 1.15,
                ),
              ),
            ),
            if (lens.lens.isOfficial)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  '官方',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _buildAvatar(lens.author.avatarUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lens.author.displayName,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lens.lens.publishedAtLabel.isEmpty
                        ? lens.lens.displayCategory
                        : '${lens.lens.displayCategory} · ${lens.lens.publishedAtLabel}',
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.46),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (lens.lens.tagNames.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: lens.lens.tagNames
                .map(
                  (tag) => Text(
                    '#$tag',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black.withOpacity(0.46),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildStats(MarketLens lens) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            '收藏',
            '${lens.favoriteCount}',
            Icons.favorite_border_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            '应用',
            '${lens.applyCount}',
            Icons.auto_awesome_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            '评分',
            lens.ratingCount == 0 ? '暂无' : lens.rating.toStringAsFixed(1),
            Icons.star_border_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.black.withOpacity(0.42),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionTabs(List<MarketLensVersion> versions) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: versions.map((version) {
          final selected = _selectedVersionId == null
              ? version.isLatest
              : _selectedVersionId == version.versionId;
          final label = version.isLatest
              ? '${version.version} 最新'
              : version.version;
          return Padding(
            padding: const EdgeInsets.only(right: 18),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedVersionId = version.versionId;
                });
              },
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.black : Colors.grey.shade500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildVersionCard(MarketLensVersion version) {
    return _buildInfoCard(
      title: '版本 ${version.version}',
      content: [
        if (version.changelog.trim().isNotEmpty) version.changelog.trim(),
        '来源: ${version.publishedFrom}',
        version.requiredInputs.isEmpty
            ? '应用前无需额外输入'
            : '必填输入: ${version.requiredInputs.join('、')}',
      ].join('\n'),
    );
  }

  Widget _buildApplyResultCard(MarketLensApplyResult result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.executed ? '模板已执行' : '模板已准备完成',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          if (result.resultUrl != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: 1.15,
                child: buildAdaptiveImage(
                  result.resultUrl,
                  fit: BoxFit.cover,
                  placeholder: Container(color: const Color(0xFFF1F3F6)),
                  errorWidget: Container(color: const Color(0xFFF1F3F6)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            result.resultFilename == null
                ? '本次返回了可复用 MuseDNA。'
                : '结果文件: ${result.resultFilename}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black.withOpacity(0.56),
            ),
          ),
          if (result.executionError != null &&
              result.executionError!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              result.executionError!,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.redAccent,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard({required String title, required String content}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              color: Colors.black.withOpacity(0.58),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildStateView({
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

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback? onTap,
    Color foregroundColor = Colors.black87,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black.withOpacity(0.04)),
        ),
        child: Icon(icon, color: foregroundColor, size: 20),
      ),
    );
  }

  Widget _buildAvatar(String? path) {
    final provider = resolveAdaptiveImageProvider(path);
    if (provider == null) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: Colors.black.withOpacity(0.06),
        child: const Icon(Icons.person, size: 18, color: Colors.black54),
      );
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.black.withOpacity(0.06),
      backgroundImage: provider,
    );
  }

  MarketLensVersion? _resolveSelectedVersion(MarketLensDetailData data) {
    if (data.versions.isEmpty) {
      return data.currentVersion;
    }
    if (_selectedVersionId != null) {
      for (final version in data.versions) {
        if (version.versionId == _selectedVersionId) {
          return version;
        }
      }
    }
    return data.currentVersion ??
        data.versions.firstWhere(
          (item) => item.isLatest,
          orElse: () => data.versions.first,
        );
  }

  Future<void> _toggleFavorite(MarketLensDetailData data) async {
    final user = await _requireUser();
    if (user == null) {
      return;
    }
    setState(() => _isFavoriting = true);
    try {
      await ref
          .read(marketRepositoryProvider)
          .setLensFavorited(
            lensId: data.lens.lens.templateId,
            userId: user.userId,
            favorited: !data.lens.isFavorited,
          );
      _refreshMarketState();
      _showMessage(data.lens.isFavorited ? '已取消收藏' : '收藏成功');
    } catch (error) {
      _showMessage('操作失败：$error');
    } finally {
      if (mounted) {
        setState(() => _isFavoriting = false);
      }
    }
  }

  Future<void> _openApplySheet(
    MarketLensDetailData data,
    MarketLensVersion version,
  ) async {
    final user = await _requireUser();
    if (user == null || !mounted) {
      return;
    }

    final draft = await showModalBottomSheet<TemplateApplyDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          TemplateApplySheet(title: data.lens.lens.title, version: version),
    );
    if (draft == null) {
      return;
    }

    setState(() => _isApplying = true);
    try {
      final result = await ref
          .read(marketRepositoryProvider)
          .applyTemplate(
            data.lens.lens.templateId,
            ApplyMarketLensInput(
              userId: user.userId,
              versionId: version.versionId,
              initialInputs: draft.initialInputs,
              paramOverrides: draft.paramOverrides,
              executeNow: draft.executeNow,
            ),
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _latestApplyResult = result;
      });
      _refreshMarketState();
      _showMessage(result.executed ? '模板执行完成' : '模板已准备完成');
    } catch (error) {
      _showMessage('应用失败：$error');
    } finally {
      if (mounted) {
        setState(() => _isApplying = false);
      }
    }
  }

  Future<User?> _requireUser() async {
    final user = ref.read(authProvider);
    if (user != null) {
      return user;
    }
    _showMessage('请先登录后再继续');
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
    return ref.read(authProvider);
  }

  void _refreshMarketState() {
    ref.invalidate(marketLensDetailProvider(widget.lensId));
    ref.invalidate(marketLensListProvider);
    ref.invalidate(marketFavoriteLensesProvider);
    ref.invalidate(marketAuthoredLensesProvider);
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SliderClipper extends CustomClipper<Rect> {
  final double splitValue;

  const _SliderClipper(this.splitValue);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, 0, size.width * splitValue, size.height);
  }

  @override
  bool shouldReclip(covariant _SliderClipper oldClipper) {
    return oldClipper.splitValue != splitValue;
  }
}
