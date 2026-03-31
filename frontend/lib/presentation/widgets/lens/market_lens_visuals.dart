import '../../../data/models/market_models.dart';

enum MarketLensSplitStyle { diagonal, vertical }

class MarketLensVisual {
  final String beforeImage;
  final String afterImage;
  final double aspectRatio;
  final MarketLensSplitStyle splitStyle;

  const MarketLensVisual({
    required this.beforeImage,
    required this.afterImage,
    required this.aspectRatio,
    required this.splitStyle,
  });
}

class MarketLensVisualResolver {
  static const List<MarketLensVisual> _fallbacks = [
    MarketLensVisual(
      beforeImage: 'assets/images/lens_market/SoftGlamour_before.jpg',
      afterImage: 'assets/images/lens_market/SoftGlamour_after.jpg',
      aspectRatio: 1.0,
      splitStyle: MarketLensSplitStyle.vertical,
    ),
    MarketLensVisual(
      beforeImage: 'assets/images/lens_market/NeonTokyo_before.jpg',
      afterImage: 'assets/images/lens_market/NeonTokyo_after.jpg',
      aspectRatio: 1.12,
      splitStyle: MarketLensSplitStyle.diagonal,
    ),
    MarketLensVisual(
      beforeImage: 'assets/images/lens_market/GhibliBreeze_before.jpg',
      afterImage: 'assets/images/lens_market/GhibliBreeze_after.jpg',
      aspectRatio: 1.08,
      splitStyle: MarketLensSplitStyle.vertical,
    ),
    MarketLensVisual(
      beforeImage: 'assets/images/lens_market/StudioMinimal_before.png',
      afterImage: 'assets/images/lens_market/StudioMinimal_after.png',
      aspectRatio: 1.0,
      splitStyle: MarketLensSplitStyle.vertical,
    ),
    MarketLensVisual(
      beforeImage: 'assets/images/lens_market/CharcoalSketch_before.jpg',
      afterImage: 'assets/images/lens_market/CharcoalSketch_after.jpg',
      aspectRatio: 1.05,
      splitStyle: MarketLensSplitStyle.vertical,
    ),
  ];

  static MarketLensVisual resolve(MarketLens lens) {
    final fallback = _pickFallback(lens);
    return MarketLensVisual(
      beforeImage: _pickBeforeImage(lens, fallback),
      afterImage: _pickAfterImage(lens, fallback),
      aspectRatio: fallback.aspectRatio,
      splitStyle: fallback.splitStyle,
    );
  }

  static String _pickBeforeImage(MarketLens lens, MarketLensVisual fallback) {
    return _firstNonEmpty(<String?>[
          lens.originalImageUrl,
          lens.originalThumbnailUrl,
          lens.coverImageUrl,
          lens.resultThumbnailUrl,
          lens.resultImageUrl,
        ]) ??
        fallback.beforeImage;
  }

  static String _pickAfterImage(MarketLens lens, MarketLensVisual fallback) {
    return _firstNonEmpty(<String?>[
          lens.resultImageUrl,
          lens.resultThumbnailUrl,
          lens.coverImageUrl,
          lens.originalThumbnailUrl,
          lens.originalImageUrl,
        ]) ??
        fallback.afterImage;
  }

  static MarketLensVisual _pickFallback(MarketLens lens) {
    final haystack = [
      lens.templateKey,
      lens.title,
      lens.category ?? '',
      lens.description,
      ...lens.tagNames,
    ].join(' ').toLowerCase();

    if (_containsAny(haystack, const [
      'portrait',
      'beauty',
      'glamour',
      '人像',
      '柔光',
      '奶油',
      '清透',
    ])) {
      return _fallbacks[0];
    }

    if (_containsAny(haystack, const ['cyber', 'neon', 'tokyo', '赛博', '霓虹'])) {
      return _fallbacks[1];
    }

    if (_containsAny(haystack, const [
      'anime',
      'ghibli',
      'cartoon',
      '二次元',
      '动漫',
    ])) {
      return _fallbacks[2];
    }

    if (_containsAny(haystack, const [
      'studio',
      'product',
      'ecommerce',
      '电商',
      '商品',
    ])) {
      return _fallbacks[3];
    }

    if (_containsAny(haystack, const ['sketch', 'charcoal', '素描', '手绘'])) {
      return _fallbacks[4];
    }

    return _fallbacks[lens.templateId % _fallbacks.length];
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  static bool _containsAny(String source, List<String> keywords) {
    for (final keyword in keywords) {
      if (source.contains(keyword)) {
        return true;
      }
    }
    return false;
  }
}
