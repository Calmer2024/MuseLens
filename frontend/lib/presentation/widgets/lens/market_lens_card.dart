import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/market_models.dart';
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 1 / visual.aspectRatio,
                child: Container(
                  color: Colors.grey.shade100,
                  child: _buildAssetImage(
                    visual.beforeImage,
                    color: Colors.black.withOpacity(0.26),
                    blendMode: BlendMode.darken,
                  ),
                ),
              ),
              ClipPath(
                clipper: visual.splitStyle == MarketLensSplitStyle.vertical
                    ? _VerticalSplitClipper()
                    : _DiagonalSplitClipper(),
                child: AspectRatio(
                  aspectRatio: 1 / visual.aspectRatio,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.electricIndigo.withOpacity(0.08),
                          Colors.cyan.withOpacity(0.1),
                        ],
                      ),
                    ),
                    child: _buildAssetImage(
                      visual.afterImage,
                      color: AppTheme.electricIndigo.withOpacity(0.18),
                      blendMode: BlendMode.colorBurn,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: visual.splitStyle == MarketLensSplitStyle.vertical
                        ? _VerticalLinePainter()
                        : _DiagonalLinePainter(),
                  ),
                ),
              ),
              if (lens.lens.isOfficial)
                Positioned(
                  top: 14,
                  left: 14,
                  child: _buildGlassTag(
                    icon: Icons.verified_rounded,
                    text: '官方',
                    iconColor: Colors.white,
                    textColor: Colors.white,
                    background: AppTheme.electricIndigo,
                  ),
                ),
              if (bannerText != null)
                Positioned(
                  top: lens.lens.isOfficial ? 52 : 14,
                  left: 14,
                  child: _buildGlassTag(
                    icon: bannerIcon ?? Icons.star_rounded,
                    text: bannerText!,
                    iconColor: AppTheme.electricIndigo,
                    textColor: Colors.black87,
                    background: Colors.white.withOpacity(0.92),
                  ),
                ),
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black.withOpacity(0.04)),
                  ),
                  child: Icon(
                    lens.isFavorited
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 20,
                    color: lens.isFavorited
                        ? const Color(0xFFF05D7B)
                        : Colors.black54,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 36, 14, 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0),
                        Colors.white.withOpacity(0.84),
                        Colors.white,
                      ],
                      stops: const [0, 0.55, 1],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lens.lens.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            lens.lens.displayPrice,
                            style: TextStyle(
                              color: lens.lens.isFree
                                  ? AppTheme.electricIndigo
                                  : Colors.black87,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lens.lens.description.trim().isEmpty
                            ? '适用于 ${lens.lens.category ?? '灵感创作'} 场景'
                            : lens.lens.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.58),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildAvatar(lens.author.avatarUrl),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              lens.author.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.download_rounded,
                            size: 14,
                            color: Colors.black45,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _compactNumber(lens.lens.installCount),
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: Color(0xFFF6B74E),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            lens.lens.ratingCount == 0
                                ? '新上架'
                                : lens.lens.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassTag({
    required IconData icon,
    required String text,
    required Color iconColor,
    required Color textColor,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetImage(
    String path, {
    Color? color,
    BlendMode? blendMode,
  }) {
    return Image.asset(
      path,
      fit: BoxFit.cover,
      color: color,
      colorBlendMode: blendMode,
      errorBuilder: (context, error, stackTrace) {
        return Container(color: const Color(0xFFF1F2F6));
      },
    );
  }

  Widget _buildAvatar(String? path) {
    if (path == null || path.trim().isEmpty) {
      return CircleAvatar(
        radius: 10,
        backgroundColor: Colors.black.withOpacity(0.06),
        child: const Icon(Icons.person, size: 12, color: Colors.black54),
      );
    }

    if (path.startsWith('http')) {
      return CircleAvatar(
        radius: 10,
        backgroundColor: Colors.black.withOpacity(0.06),
        backgroundImage: CachedNetworkImageProvider(path),
      );
    }

    if (path.startsWith('file://')) {
      return CircleAvatar(
        radius: 10,
        backgroundColor: Colors.black.withOpacity(0.06),
        backgroundImage: FileImage(File(path.substring(7))),
      );
    }

    if (path.startsWith('/')) {
      return CircleAvatar(
        radius: 10,
        backgroundColor: Colors.black.withOpacity(0.06),
        backgroundImage: FileImage(File(path)),
      );
    }

    return CircleAvatar(
      radius: 10,
      backgroundColor: Colors.black.withOpacity(0.06),
      backgroundImage: AssetImage(path),
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

class _DiagonalSplitClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.28, size.height)
      ..lineTo(size.width * 0.68, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _VerticalSplitClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..addRect(
        Rect.fromLTRB(size.width * 0.5, 0, size.width, size.height),
      );
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _DiagonalLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.72)
      ..strokeWidth = 1.7
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(size.width * 0.68, 0),
      Offset(size.width * 0.28, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _VerticalLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.72)
      ..strokeWidth = 1.7
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(size.width * 0.5, 0),
      Offset(size.width * 0.5, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
