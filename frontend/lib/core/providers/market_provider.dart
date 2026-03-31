import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/market_models.dart';
import '../../data/repositories/market_repository.dart';
import 'auth_provider.dart';

@immutable
class MarketLensQuery {
  final String? category;
  final String? status;
  final bool? isOfficial;
  final String? keyword;
  final String? tagName;

  const MarketLensQuery({
    this.category,
    this.status,
    this.isOfficial,
    this.keyword,
    this.tagName,
  });

  @override
  bool operator ==(Object other) {
    return other is MarketLensQuery &&
        other.category == category &&
        other.status == status &&
        other.isOfficial == isOfficial &&
        other.keyword == keyword &&
        other.tagName == tagName;
  }

  @override
  int get hashCode =>
      Object.hash(category, status, isOfficial, keyword, tagName);
}

final marketTemplateTagsProvider = FutureProvider<List<MarketTag>>((ref) async {
  final repository = ref.watch(marketRepositoryProvider);
  return repository.listTemplateTags();
});

final marketLensListProvider =
    FutureProvider.family<List<MarketLensView>, MarketLensQuery>((
      ref,
      query,
    ) async {
      final repository = ref.watch(marketRepositoryProvider);
      final currentUser = ref.watch(authProvider);

      return repository.listLenses(
        category: query.category,
        status: query.status,
        isOfficial: query.isOfficial,
        keyword: query.keyword,
        tagName: query.tagName,
        actingUserId: currentUser?.userId,
      );
    });

final marketLensDetailProvider =
    FutureProvider.family<MarketLensDetailData, int>((ref, lensId) async {
      final repository = ref.watch(marketRepositoryProvider);
      final currentUser = ref.watch(authProvider);

      return repository.getLensDetailBundle(
        lensId,
        actingUserId: currentUser?.userId,
      );
    });

final marketFavoriteLensesProvider = FutureProvider<List<MarketLensView>>((
  ref,
) async {
  final repository = ref.watch(marketRepositoryProvider);
  final currentUser = ref.watch(authProvider);
  if (currentUser == null) {
    return const [];
  }

  return repository.listFavoriteLenses(userId: currentUser.userId);
});

final marketAuthoredLensesProvider = FutureProvider<List<MarketLensView>>((
  ref,
) async {
  final repository = ref.watch(marketRepositoryProvider);
  final currentUser = ref.watch(authProvider);
  if (currentUser == null) {
    return const [];
  }

  return repository.listAuthoredLenses(userId: currentUser.userId);
});
