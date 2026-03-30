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
  })  : _apiService = apiService,
        _userApiService = userApiService;

  final MarketApiService _apiService;
  final UserApiService _userApiService;
  final Map<int, MarketLensAuthor> _authorCache = <int, MarketLensAuthor>{};

  Future<List<MarketLensView>> listLenses({
    String? category,
    String? status,
    bool? isOfficial,
    String? keyword,
    int? actingUserId,
  }) async {
    final lenses = await _apiService.listLenses(
      category: category,
      status: status,
      isOfficial: isOfficial,
    );
    return _hydrateLenses(
      lenses,
      actingUserId: actingUserId,
      keyword: keyword,
    );
  }

  Future<MarketLensDetailData> getLensDetailBundle(
    int lensId, {
    int? actingUserId,
  }) async {
    final detailJson = await _apiService.getLensDetail(lensId);
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
    final userState = actingUserId != null
        ? await _loadUserLensState(actingUserId)
        : const _UserLensState();

    final lensView = MarketLensView(
      lens: lens,
      author: lens.authorId == null
          ? MarketLensAuthor.placeholder(null)
          : (authors[lens.authorId!] ??
              MarketLensAuthor.placeholder(lens.authorId)),
      isInstalled: userState.installedIds.contains(lens.lensId),
      isFavorited: userState.favoritedIds.contains(lens.lensId),
    );

    final reviewViews = reviews
        .map(
          (review) => LensReviewView(
            review: review,
            author: authors[review.userId] ??
                MarketLensAuthor.placeholder(review.userId),
          ),
        )
        .toList();

    LensReviewView? currentUserReview;
    if (actingUserId != null) {
      for (final item in reviewViews) {
        if (item.review.userId == actingUserId) {
          currentUserReview = item;
          break;
        }
      }
    }

    return MarketLensDetailData(
      lens: lensView,
      versions: versions,
      reviews: reviewViews,
      currentUserReview: currentUserReview,
    );
  }

  Future<List<MarketLensView>> listInstalledLenses({
    required int userId,
    String? keyword,
  }) async {
    final lenses = await _apiService.listInstalledLenses(userId);
    return _hydrateLenses(
      lenses,
      actingUserId: userId,
      keyword: keyword,
    );
  }

  Future<List<MarketLensView>> listFavoriteLenses({
    required int userId,
    String? keyword,
  }) async {
    final lenses = await _apiService.listFavoriteLenses(userId);
    return _hydrateLenses(
      lenses,
      actingUserId: userId,
      keyword: keyword,
    );
  }

  Future<List<MarketLensView>> listAuthoredLenses({
    required int userId,
    String? status,
    String? keyword,
  }) async {
    final lenses = await _apiService.listLenses(status: status);
    final authored = lenses.where((item) => item.authorId == userId).toList();
    return _hydrateLenses(
      authored,
      actingUserId: userId,
      keyword: keyword,
    );
  }

  Future<MarketLens> createLens(CreateMarketLensInput input) {
    return _apiService.createLens(input);
  }

  Future<MarketLens> updateLens(int lensId, UpdateMarketLensInput input) {
    return _apiService.updateLens(lensId, input);
  }

  Future<MarketLensVersion> createVersion(
    int lensId,
    CreateMarketLensVersionInput input,
  ) {
    return _apiService.createVersion(lensId, input);
  }

  Future<void> setLensInstalled({
    required int lensId,
    required int userId,
    required bool installed,
    int? versionId,
  }) async {
    if (installed) {
      await _apiService.installLens(
        lensId: lensId,
        userId: userId,
        versionId: versionId,
      );
      return;
    }

    await _apiService.uninstallLens(
      lensId: lensId,
      userId: userId,
    );
  }

  Future<void> setLensFavorited({
    required int lensId,
    required int userId,
    required bool favorited,
  }) async {
    if (favorited) {
      await _apiService.favoriteLens(
        lensId: lensId,
        userId: userId,
      );
      return;
    }

    await _apiService.unfavoriteLens(
      lensId: lensId,
      userId: userId,
    );
  }

  Future<LensReview> createOrUpdateReview(
    int lensId,
    CreateLensReviewInput input,
  ) {
    return _apiService.createOrUpdateReview(lensId, input);
  }

  Future<List<MarketLensView>> _hydrateLenses(
    List<MarketLens> lenses, {
    int? actingUserId,
    String? keyword,
  }) async {
    final authors = await _loadAuthors(
      lenses
          .map((item) => item.authorId)
          .whereType<int>(),
    );
    final userState = actingUserId != null
        ? await _loadUserLensState(actingUserId)
        : const _UserLensState();

    var views = lenses
        .map(
          (lens) => MarketLensView(
            lens: lens,
            author: lens.authorId == null
                ? MarketLensAuthor.placeholder(null)
                : (authors[lens.authorId!] ??
                    MarketLensAuthor.placeholder(lens.authorId)),
            isInstalled: userState.installedIds.contains(lens.lensId),
            isFavorited: userState.favoritedIds.contains(lens.lensId),
          ),
        )
        .toList();

    final normalizedKeyword = keyword?.trim().toLowerCase();
    if (normalizedKeyword != null && normalizedKeyword.isNotEmpty) {
      views = views.where((item) {
        final haystack = <String>[
          item.lens.name,
          item.lens.description,
          item.lens.lensKey,
          item.lens.category ?? '',
          item.author.displayName,
          item.author.username,
        ].join(' ').toLowerCase();
        return haystack.contains(normalizedKeyword);
      }).toList();
    }

    return views;
  }

  Future<_UserLensState> _loadUserLensState(int userId) async {
    final results = await Future.wait<dynamic>([
      _apiService.listInstalledLenses(userId),
      _apiService.listFavoriteLenses(userId),
    ]);

    final installed = results[0] as List<MarketLens>;
    final favorites = results[1] as List<MarketLens>;

    return _UserLensState(
      installedIds: installed.map((item) => item.lensId).toSet(),
      favoritedIds: favorites.map((item) => item.lensId).toSet(),
    );
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

class _UserLensState {
  final Set<int> installedIds;
  final Set<int> favoritedIds;

  const _UserLensState({
    this.installedIds = const <int>{},
    this.favoritedIds = const <int>{},
  });
}
