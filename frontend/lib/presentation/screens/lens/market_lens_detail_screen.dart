import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/market_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/market_models.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/market_repository.dart';
import '../../widgets/lens/market_lens_visuals.dart';
import '../auth/login_screen.dart';
import 'market_lens_editor_screen.dart';

class MarketLensDetailScreen extends ConsumerStatefulWidget {
  final int lensId;

  const MarketLensDetailScreen({
    super.key,
    required this.lensId,
  });

  @override
  ConsumerState<MarketLensDetailScreen> createState() =>
      _MarketLensDetailScreenState();
}

class _MarketLensDetailScreenState
    extends ConsumerState<MarketLensDetailScreen> {
  double _splitValue = 0.5;
  int? _selectedVersionId;
  bool _isInstalling = false;
  bool _isFavoriting = false;

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(marketLensDetailProvider(widget.lensId));

    return detailAsync.when(
      loading: () => _buildScaffold(
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => _buildScaffold(
        body: _buildEmptyState(
          icon: Icons.error_outline_rounded,
          title: '透镜详情加载失败',
          content: '$error',
          actionLabel: '重试',
          onAction: () => ref.invalidate(marketLensDetailProvider(widget.lensId)),
        ),
      ),
      data: (data) => _buildDataScaffold(data),
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
                    AppTheme.electricIndigo.withOpacity(0.16),
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCircleButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    if (topActions != null)
                      Row(children: topActions)
                    else
                      const SizedBox.shrink(),
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

  Scaffold _buildDataScaffold(MarketLensDetailData data) {
    final lens = data.lens;
    final visual = MarketLensVisualResolver.resolve(lens.lens);
    final isAuthor = _isCurrentUserAuthor(lens.lens);
    final selectedVersion = _resolveSelectedVersion(data.versions);
    final canInstall = data.versions.isNotEmpty;

    return _buildScaffold(
      topActions: [
        if (isAuthor)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _buildCircleButton(
              icon: Icons.edit_outlined,
              onTap: () => _openEditor(lens.lens),
            ),
          ),
        _buildCircleButton(
          icon: lens.isFavorited
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          foregroundColor:
              lens.isFavorited ? const Color(0xFFF05D7B) : Colors.black87,
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
                  _buildHeader(data),
                  const SizedBox(height: 20),
                  _buildStats(data),
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
                  if (isAuthor) ...[
                    const SizedBox(height: 24),
                    _buildSectionTitle('作者工具'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _openEditor(lens.lens),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('编辑信息'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _openVersionComposer,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.rocket_launch_outlined, size: 18),
                            label: const Text('发布版本'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 28),
                  _buildSectionTitle('版本'),
                  const SizedBox(height: 12),
                  if (data.versions.isEmpty)
                    _buildInfoCard(
                      title: '还没有可用版本',
                      content: isAuthor ? '先发布一个版本后才能安装。' : '作者还未上传版本。',
                    )
                  else ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: data.versions.map((version) {
                          final selected =
                              selectedVersion?.versionId == version.versionId;
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: ChoiceChip(
                              selected: selected,
                              label: Text(
                                version.isLatest
                                    ? '${version.version} 最新'
                                    : version.version,
                              ),
                              selectedColor: Colors.black,
                              labelStyle: TextStyle(
                                color: selected ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                              onSelected: (_) {
                                setState(() {
                                  _selectedVersionId = version.versionId;
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    if (selectedVersion != null) ...[
                      const SizedBox(height: 14),
                      _buildVersionCard(selectedVersion),
                    ],
                  ],
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle('评价'),
                      TextButton.icon(
                        onPressed: () => _openReviewComposer(data),
                        icon: const Icon(Icons.edit_note_rounded, size: 20),
                        label: Text(data.currentUserReview == null ? '写评价' : '编辑评价'),
                      ),
                    ],
                  ),
                  if (data.currentUserReview != null) ...[
                    const SizedBox(height: 12),
                    _buildCurrentReviewCard(data.currentUserReview!),
                  ],
                  const SizedBox(height: 12),
                  if (data.reviews.isEmpty)
                    _buildInfoCard(
                      title: '还没有用户评价',
                      content: '安装并体验后，留下第一条反馈吧。',
                    )
                  else
                    Column(children: data.reviews.map(_buildReviewTile).toList()),
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
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 58,
                  child: ElevatedButton(
                    onPressed: !_isInstalling && canInstall
                        ? () => _toggleInstall(data, selectedVersion)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          lens.isInstalled ? Colors.white : Colors.black,
                      foregroundColor:
                          lens.isInstalled ? Colors.black87 : Colors.white,
                      side: lens.isInstalled
                          ? BorderSide(color: Colors.black.withOpacity(0.08))
                          : BorderSide.none,
                    ),
                    child: _isInstalling
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                lens.isInstalled ? Colors.black87 : Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            !canInstall
                                ? '暂无可安装版本'
                                : lens.isInstalled
                                    ? '卸载透镜'
                                    : selectedVersion == null
                                        ? '安装透镜'
                                        : '安装 ${selectedVersion.version}',
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroPreview(MarketLensVisual visual) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height * 0.52;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            visual.afterImage,
            fit: BoxFit.cover,
            color: AppTheme.electricIndigo.withOpacity(0.1),
            colorBlendMode: BlendMode.colorBurn,
          ),
          ClipRect(
            clipper: _SliderClipper(_splitValue),
            child: Image.asset(
              visual.beforeImage,
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.22),
              colorBlendMode: BlendMode.darken,
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
                  _splitValue = (details.globalPosition.dx / width).clamp(0.0, 1.0);
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

  Widget _buildHeader(MarketLensDetailData data) {
    final lens = data.lens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      lens.lens.name,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  if (lens.lens.isOfficial)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.electricIndigo,
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
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildAuthorAvatar(lens.author.avatarUrl),
                  const SizedBox(width: 10),
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
                        Text(
                          lens.author.userId == null
                              ? '官方发布'
                              : '@${lens.author.username}',
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.45),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              lens.lens.displayPrice,
              style: TextStyle(
                color: lens.lens.isFree ? AppTheme.electricIndigo : Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                lens.lens.category?.trim().isNotEmpty == true
                    ? lens.lens.category!
                    : '未分类',
                style: TextStyle(
                  color: Colors.black.withOpacity(0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStats(MarketLensDetailData data) {
    final lens = data.lens.lens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatColumn(
            value: lens.ratingCount == 0 ? '暂无' : lens.rating.toStringAsFixed(1),
            label: '评分',
          ),
          _buildDivider(),
          _buildStatColumn(value: '${lens.installCount}', label: '安装量'),
          _buildDivider(),
          _buildStatColumn(value: '${data.versions.length}', label: '版本数'),
        ],
      ),
    );
  }

  Widget _buildStatColumn({
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            color: Colors.black.withOpacity(0.45),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 28,
      color: Colors.black.withOpacity(0.08),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 19,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: Colors.black.withOpacity(0.56),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionCard(MarketLensVersion version) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'v${version.version}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              if (version.isLatest)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Latest',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _buildVersionMetricRow(
            '工作流节点',
            '${(version.baseWorkflow['nodes'] as List<dynamic>?)?.length ?? 0}',
          ),
          const SizedBox(height: 10),
          _buildVersionMetricRow('参数数量', '${version.parameters.length}'),
          const SizedBox(height: 10),
          _buildVersionMetricRow(
            'UI 字段',
            version.uiSchema.keys.isEmpty ? '未配置' : version.uiSchema.keys.join(' / '),
          ),
          if (version.changelog.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              version.changelog,
              style: TextStyle(
                color: Colors.black.withOpacity(0.62),
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVersionMetricRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.black.withOpacity(0.45),
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentReviewCard(LensReviewView reviewView) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.electricIndigo.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.electricIndigo.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '我的评价',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          _buildStarRow(reviewView.review.rating),
          if (reviewView.review.content.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              reviewView.review.content,
              style: TextStyle(
                color: Colors.black.withOpacity(0.64),
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewTile(LensReviewView reviewView) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildAuthorAvatar(reviewView.author.avatarUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reviewView.author.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      '${reviewView.review.createdAt.year}-${reviewView.review.createdAt.month.toString().padLeft(2, '0')}-${reviewView.review.createdAt.day.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStarRow(reviewView.review.rating, size: 14),
            ],
          ),
          if (reviewView.review.content.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              reviewView.review.content,
              style: TextStyle(
                color: Colors.black.withOpacity(0.62),
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStarRow(int rating, {double size = 16}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(5, (index) {
        return Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Icon(
            index < rating ? Icons.star_rounded : Icons.star_border_rounded,
            size: size,
            color: const Color(0xFFF6B74E),
          ),
        );
      }),
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
          color: Colors.white.withOpacity(0.94),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black.withOpacity(0.04)),
        ),
        child: Icon(icon, color: foregroundColor, size: 20),
      ),
    );
  }

  Widget _buildAuthorAvatar(String? path) {
    if (path == null || path.trim().isEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: Colors.black.withOpacity(0.06),
        child: const Icon(Icons.person, size: 18, color: Colors.black54),
      );
    }
    if (path.startsWith('http')) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: Colors.black.withOpacity(0.06),
        backgroundImage: CachedNetworkImageProvider(path),
      );
    }
    if (path.startsWith('file://')) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: Colors.black.withOpacity(0.06),
        backgroundImage: FileImage(File(path.substring(7))),
      );
    }
    if (path.startsWith('/')) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: Colors.black.withOpacity(0.06),
        backgroundImage: FileImage(File(path)),
      );
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: Colors.black.withOpacity(0.06),
      backgroundImage: AssetImage(path),
    );
  }

  Widget _buildEmptyState({
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
            Icon(icon, size: 58, color: Colors.black.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              content,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black.withOpacity(0.46),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
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

  MarketLensVersion? _resolveSelectedVersion(List<MarketLensVersion> versions) {
    if (versions.isEmpty) {
      return null;
    }
    if (_selectedVersionId != null) {
      for (final version in versions) {
        if (version.versionId == _selectedVersionId) {
          return version;
        }
      }
    }
    for (final version in versions) {
      if (version.isLatest) {
        return version;
      }
    }
    return versions.first;
  }

  bool _isCurrentUserAuthor(MarketLens lens) {
    final user = ref.read(authProvider);
    return user != null && lens.authorId == user.userId;
  }

  Future<void> _toggleInstall(
    MarketLensDetailData data,
    MarketLensVersion? selectedVersion,
  ) async {
    final user = await _requireUser();
    if (user == null) {
      return;
    }
    setState(() {
      _isInstalling = true;
    });
    try {
      await ref.read(marketRepositoryProvider).setLensInstalled(
            lensId: data.lens.lens.lensId,
            userId: user.userId,
            installed: !data.lens.isInstalled,
            versionId: !data.lens.isInstalled ? selectedVersion?.versionId : null,
          );
      _refreshMarketState();
      _showMessage(data.lens.isInstalled ? '已卸载透镜' : '安装成功');
    } catch (error) {
      _showMessage('操作失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isInstalling = false;
        });
      }
    }
  }

  Future<void> _toggleFavorite(MarketLensDetailData data) async {
    final user = await _requireUser();
    if (user == null) {
      return;
    }
    setState(() {
      _isFavoriting = true;
    });
    try {
      await ref.read(marketRepositoryProvider).setLensFavorited(
            lensId: data.lens.lens.lensId,
            userId: user.userId,
            favorited: !data.lens.isFavorited,
          );
      _refreshMarketState();
      _showMessage(data.lens.isFavorited ? '已取消收藏' : '收藏成功');
    } catch (error) {
      _showMessage('操作失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isFavoriting = false;
        });
      }
    }
  }

  Future<void> _openEditor(MarketLens lens) async {
    final result = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => MarketLensEditorScreen(initialLens: lens),
      ),
    );
    if (result != null) {
      _refreshMarketState();
    }
  }

  Future<void> _openVersionComposer() async {
    final result = await showModalBottomSheet<CreateMarketLensVersionInput>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _VersionComposerSheet(),
    );
    if (result == null) {
      return;
    }
    try {
      await ref.read(marketRepositoryProvider).createVersion(widget.lensId, result);
      _refreshMarketState();
      _showMessage('版本发布成功');
    } catch (error) {
      _showMessage('版本发布失败：$error');
    }
  }

  Future<void> _openReviewComposer(MarketLensDetailData data) async {
    final user = await _requireUser();
    if (user == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    final result = await showModalBottomSheet<_ReviewDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewComposerSheet(
        initialRating: data.currentUserReview?.review.rating ?? 5,
        initialContent: data.currentUserReview?.review.content ?? '',
      ),
    );
    if (result == null) {
      return;
    }
    try {
      await ref.read(marketRepositoryProvider).createOrUpdateReview(
            widget.lensId,
            CreateLensReviewInput(
              userId: user.userId,
              rating: result.rating,
              content: result.content,
            ),
          );
      _refreshMarketState();
      _showMessage('评价已提交');
    } catch (error) {
      _showMessage('评价提交失败：$error');
    }
  }

  Future<User?> _requireUser() async {
    final user = ref.read(authProvider);
    if (user != null) {
      return user;
    }
    _showMessage('请先登录后再继续');
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    return ref.read(authProvider);
  }

  void _refreshMarketState() {
    ref.invalidate(marketLensDetailProvider(widget.lensId));
    ref.invalidate(marketLensListProvider);
    ref.invalidate(marketInstalledLensesProvider);
    ref.invalidate(marketFavoriteLensesProvider);
    ref.invalidate(marketAuthoredLensesProvider);
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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

class _VersionComposerSheet extends StatefulWidget {
  const _VersionComposerSheet();

  @override
  State<_VersionComposerSheet> createState() => _VersionComposerSheetState();
}

class _VersionComposerSheetState extends State<_VersionComposerSheet> {
  final _versionController = TextEditingController(text: '1.0.0');
  final _workflowController = TextEditingController(text: '{"nodes": []}');
  final _parametersController = TextEditingController(text: '{}');
  final _uiSchemaController = TextEditingController(text: '{"layout": "slider"}');
  final _changelogController = TextEditingController();
  bool _isLatest = true;

  @override
  void dispose() {
    _versionController.dispose();
    _workflowController.dispose();
    _parametersController.dispose();
    _uiSchemaController.dispose();
    _changelogController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ModalScaffold(
      title: '发布新版本',
      child: Column(
        children: [
          _buildField(_versionController, '版本号', maxLines: 1),
          const SizedBox(height: 12),
          _buildField(_workflowController, 'base_workflow'),
          const SizedBox(height: 12),
          _buildField(_parametersController, 'parameters'),
          const SizedBox(height: 12),
          _buildField(_uiSchemaController, 'ui_schema'),
          const SizedBox(height: 12),
          _buildField(_changelogController, '更新说明', minLines: 3),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            value: _isLatest,
            activeColor: AppTheme.electricIndigo,
            contentPadding: EdgeInsets.zero,
            title: const Text('设为最新版本'),
            onChanged: (value) {
              setState(() {
                _isLatest = value;
              });
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text('确认发布'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label, {
    int minLines = 4,
    int maxLines = 8,
  }) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  void _submit() {
    try {
      Navigator.of(context).pop(
        CreateMarketLensVersionInput(
          version: _versionController.text.trim(),
          baseWorkflow: Map<String, dynamic>.from(
            jsonDecode(_workflowController.text) as Map<String, dynamic>,
          ),
          parameters: Map<String, dynamic>.from(
            jsonDecode(_parametersController.text) as Map<String, dynamic>,
          ),
          uiSchema: Map<String, dynamic>.from(
            jsonDecode(_uiSchemaController.text) as Map<String, dynamic>,
          ),
          changelog: _changelogController.text.trim(),
          isLatest: _isLatest,
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('JSON 解析失败：$error')),
      );
    }
  }
}

class _ReviewComposerSheet extends StatefulWidget {
  final int initialRating;
  final String initialContent;

  const _ReviewComposerSheet({
    required this.initialRating,
    required this.initialContent,
  });

  @override
  State<_ReviewComposerSheet> createState() => _ReviewComposerSheetState();
}

class _ReviewComposerSheetState extends State<_ReviewComposerSheet> {
  late final TextEditingController _contentController;
  late int _rating;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
    _contentController = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ModalScaffold(
      title: '写下你的评价',
      child: Column(
        children: [
          Row(
            children: List<Widget>.generate(5, (index) {
              final star = index + 1;
              return IconButton(
                onPressed: () {
                  setState(() {
                    _rating = star;
                  });
                },
                icon: Icon(
                  star <= _rating
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: const Color(0xFFF6B74E),
                  size: 30,
                ),
              );
            }),
          ),
          TextField(
            controller: _contentController,
            minLines: 4,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: '分享体验感受和建议',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(
                  _ReviewDraft(
                    rating: _rating,
                    content: _contentController.text.trim(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text('提交评价'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModalScaffold extends StatelessWidget {
  final String title;
  final Widget child;

  const _ModalScaffold({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewDraft {
  final int rating;
  final String content;

  const _ReviewDraft({
    required this.rating,
    required this.content,
  });
}
