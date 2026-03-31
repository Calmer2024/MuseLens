import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_provider.dart';
import '../models/market_models.dart';
import '../models/providers/services/market_api_service.dart';
import '../models/providers/services/user_api_service.dart';

final marketApiServiceProvider = Provider<MarketApiService>((ref) {
  return MarketApiService();
});

final marketRepositoryProvider = Provider<MarketRepository>((ref) {
  return MarketRepository(
    apiService: ref.watch(marketApiServiceProvider),
    userApiService: ref.watch(userApiServiceProvider),
  );
});

class MarketRepository {
  MarketRepository({
    required MarketApiService apiService,
    required UserApiService userApiService,
  }) : _apiService = apiService,
       _userApiService = userApiService;

  final MarketApiService _apiService;
  final UserApiService _userApiService;
  final Map<int, MarketLensAuthor> _authorCache = <int, MarketLensAuthor>{};

  Future<List<MarketTag>> listTemplateTags() {
    return _apiService.listTemplateTags();
  }

  Future<List<MarketLensView>> listLenses({
    String? category,
    String? status,
    bool? isOfficial,
    String? keyword,
    String? tagName,
    int? actingUserId,
  }) async {
    final templates = await _apiService.listTemplates(
      q: keyword,
      tagName: tagName,
      category: category,
      status: status,
      isOfficial: isOfficial,
    );
    final favoritedIds = actingUserId != null
        ? await _loadFavoriteIds(actingUserId)
        : const <int>{};
    return _buildViews(templates, favoritedIds: favoritedIds, keyword: keyword);
  }

  Future<MarketLensDetailData> getLensDetailBundle(
    int lensId, {
    int? actingUserId,
  }) async {
    final detailJson = await _apiService.getTemplateDetail(lensId);
    final lens = MarketLens.fromJson(detailJson);
    final versions = (detailJson['versions'] as List<dynamic>? ?? const [])
        .map((item) => MarketLensVersion.fromJson(item as Map<String, dynamic>))
        .toList();
    final reviews = (detailJson['reviews'] as List<dynamic>? ?? const [])
        .map((item) => LensReview.fromJson(item as Map<String, dynamic>))
        .toList();
    final authorIds = <int>{
      if (lens.authorId != null) lens.authorId!,
      ...reviews.map((item) => item.userId),
    };
    final authors = await _loadAuthors(authorIds);
    final favoritedIds = actingUserId != null
        ? await _loadFavoriteIds(actingUserId)
        : const <int>{};

    final lensAuthor =
        lens.author ??
        (lens.authorId == null
            ? MarketLensAuthor.placeholder(null)
            : authors[lens.authorId!] ??
                  MarketLensAuthor.placeholder(lens.authorId));

    final reviewViews = reviews
        .map(
          (review) => LensReviewView(
            review: review,
            author:
                authors[review.userId] ??
                MarketLensAuthor.placeholder(review.userId),
          ),
        )
        .toList();

    MarketLensVersion? currentVersion;
    if (detailJson['current_version'] is Map<String, dynamic>) {
      currentVersion = MarketLensVersion.fromJson(
        detailJson['current_version'] as Map<String, dynamic>,
      );
    } else if (versions.isNotEmpty) {
      currentVersion = versions.firstWhere(
        (item) => item.isLatest,
        orElse: () => versions.first,
      );
    }

    return MarketLensDetailData(
      lens: MarketLensView(
        lens: lens,
        author: lensAuthor,
        isFavorited: favoritedIds.contains(lens.templateId),
      ),
      currentVersion: currentVersion,
      versions: versions,
      reviews: reviewViews,
    );
  }

  Future<List<MarketLensView>> listFavoriteLenses({
    required int userId,
    String? keyword,
  }) async {
    final templates = await _apiService.listFavoriteTemplates(userId);
    final favoriteIds = templates.map((item) => item.templateId).toSet();
    return _buildViews(templates, favoritedIds: favoriteIds, keyword: keyword);
  }

  Future<List<MarketLensView>> listAuthoredLenses({
    required int userId,
    String? keyword,
  }) async {
    final templates = await _apiService.listPublishedTemplates(userId);
    final favoriteIds = await _loadFavoriteIds(userId);
    return _buildViews(templates, favoritedIds: favoriteIds, keyword: keyword);
  }

  Future<void> setLensFavorited({
    required int lensId,
    required int userId,
    required bool favorited,
  }) async {
    if (favorited) {
      await _apiService.favoriteLens(lensId: lensId, userId: userId);
      return;
    }

    await _apiService.unfavoriteLens(lensId: lensId, userId: userId);
  }

  Future<MarketLensApplyResult> applyTemplate(
    int lensId,
    ApplyMarketLensInput input,
  ) {
    return _apiService.applyTemplate(lensId, input);
  }

  Future<List<MarketLensView>> _buildViews(
    List<MarketLens> lenses, {
    required Set<int> favoritedIds,
    String? keyword,
  }) async {
    final authors = await _loadAuthors(
      lenses.map((item) => item.authorId).whereType<int>(),
    );

    final views = lenses.map((lens) {
      final author =
          lens.author ??
          (lens.authorId == null
              ? MarketLensAuthor.placeholder(null)
              : authors[lens.authorId!] ??
                    MarketLensAuthor.placeholder(lens.authorId));
      return MarketLensView(
        lens: lens,
        author: author,
        isFavorited: favoritedIds.contains(lens.templateId),
      );
    }).toList();

    return _filterViewsByKeyword(views, keyword);
  }

  List<MarketLensView> _filterViewsByKeyword(
    List<MarketLensView> views,
    String? keyword,
  ) {
    final normalizedKeyword = keyword?.trim().toLowerCase();
    if (normalizedKeyword == null || normalizedKeyword.isEmpty) {
      return views;
    }

    return views.where((item) {
      final haystack = <String>[
        item.lens.title,
        item.lens.description,
        item.lens.templateKey,
        item.lens.category ?? '',
        item.author.displayName,
        item.author.username,
        ...item.lens.tagNames,
      ].join(' ').toLowerCase();
      return haystack.contains(normalizedKeyword);
    }).toList();
  }

  Future<Set<int>> _loadFavoriteIds(int userId) async {
    try {
      final favorites = await _apiService.listFavoriteTemplates(userId);
      return favorites.map((item) => item.templateId).toSet();
    } catch (_) {
      return <int>{};
    }
  }

  Future<Map<int, MarketLensAuthor>> _loadAuthors(Iterable<int> userIds) async {
    final uniqueIds = userIds.toSet().toList();
    if (uniqueIds.isEmpty) {
      return const {};
    }

    final missingIds = uniqueIds
        .where((id) => !_authorCache.containsKey(id))
        .toList();

    if (missingIds.isNotEmpty) {
      final fetched = await Future.wait(
        missingIds.map((userId) async {
          try {
            final user = await _userApiService.getUserById(userId);
            return MapEntry(userId, MarketLensAuthor.fromUser(user));
          } catch (_) {
            return MapEntry(userId, MarketLensAuthor.placeholder(userId));
          }
        }),
      );
      _authorCache.addEntries(fetched);
    }

    return Map<int, MarketLensAuthor>.fromEntries(
      uniqueIds.map(
        (userId) => MapEntry(
          userId,
          _authorCache[userId] ?? MarketLensAuthor.placeholder(userId),
        ),
      ),
    );
  }
}
