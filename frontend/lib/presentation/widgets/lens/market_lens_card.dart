import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/market_models.dart';
import '../shared/adaptive_media.dart';
import 'market_lens_visuals.dart';

class MarketLensCard extends StatelessWidget {
  final MarketLensView lens;
  final VoidCallback? onTap;
  final String? bannerText;
  final IconData? bannerIcon;

  const MarketLensCard({
    super.key,
    required this.lens,
    this.onTap,
    this.bannerText,
    this.bannerIcon,
  });

  @override
  Widget build(BuildContext context) {
    final visual = MarketLensVisualResolver.resolve(lens.lens);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                child: Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: visual.aspectRatio,
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildPreviewImage(
                              visual.beforeImage,
                              label: '原图',
                            ),
                          ),
                          Expanded(
                            child: _buildPreviewImage(
                              visual.afterImage,
                              label: '效果',
                              accent: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 14,
                      left: 14,
                      child: Row(
                        children: [
                          if (lens.lens.isOfficial)
                            _buildBadge(
                              text: '官方',
                              icon: Icons.verified_rounded,
                              background: Colors.black,
                              foreground: Colors.white,
                            ),
                          if (bannerText != null) ...[
                            if (lens.lens.isOfficial) const SizedBox(width: 8),
                            _buildBadge(
                              text: bannerText!,
                              icon: bannerIcon ?? Icons.bookmark_rounded,
                              background: Colors.white.withOpacity(0.94),
                              foreground: Colors.black87,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            lens.lens.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                              height: 1.25,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              lens.isFavorited
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 16,
                              color: lens.isFavorited
                                  ? const Color(0xFFE55C78)
                                  : Colors.black54,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _compactNumber(lens.lens.favoriteCount),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (lens.lens.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        lens.lens.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: Colors.black.withOpacity(0.56),
                        ),
                      ),
                    ],
                    if (lens.lens.visibleTags.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        children: lens.lens.visibleTags
                            .map(
                              (tag) => Text(
                                '#$tag',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black.withOpacity(0.42),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _buildAvatar(lens.author.avatarUrl),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lens.author.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                lens.lens.displayCategory,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.black.withOpacity(0.42),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${lens.lens.applyCount}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              '应用',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.black.withOpacity(0.42),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewImage(
    String path, {
    required String label,
    bool accent = false,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        buildAdaptiveImage(
          path,
          fit: BoxFit.cover,
          placeholder: Container(color: const Color(0xFFF2F3F5)),
          errorWidget: Container(color: const Color(0xFFF2F3F5)),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(accent ? 0.08 : 0.18),
                Colors.transparent,
                Colors.black.withOpacity(accent ? 0.18 : 0.08),
              ],
            ),
          ),
        ),
        Positioned(
          left: 10,
          bottom: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: accent
                  ? AppTheme.electricIndigo.withOpacity(0.92)
                  : Colors.white.withOpacity(0.94),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: accent ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadge({
    required String text,
    required IconData icon,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: foreground),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? path) {
    final provider = resolveAdaptiveImageProvider(path);
    if (provider == null) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: Colors.black.withOpacity(0.06),
        child: const Icon(Icons.person, size: 14, color: Colors.black54),
      );
    }

    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.black.withOpacity(0.06),
      backgroundImage: provider,
    );
  }

  static String _compactNumber(int value) {
    if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}w';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return '$value';
  }
}
