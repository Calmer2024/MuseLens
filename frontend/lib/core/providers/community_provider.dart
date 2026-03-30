import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/community_models.dart';
import '../../data/repositories/community_repository.dart';
import 'auth_provider.dart';

@immutable
class CommunityPostQuery {
  final int? userId;
  final String? tagName;
  final bool onlyPublic;

  const CommunityPostQuery({
    this.userId,
    this.tagName,
    this.onlyPublic = true,
  });

  @override
  bool operator ==(Object other) {
    return other is CommunityPostQuery &&
        other.userId == userId &&
        other.tagName == tagName &&
        other.onlyPublic == onlyPublic;
  }

  @override
  int get hashCode => Object.hash(userId, tagName, onlyPublic);
}

final communityTagsProvider = FutureProvider<List<CommunityTag>>((ref) async {
  final repository = ref.watch(communityRepositoryProvider);
  return repository.listTags();
});

final communityPostsProvider =
    FutureProvider.family<List<CommunityPostView>, CommunityPostQuery>((ref, query) async {
  final repository = ref.watch(communityRepositoryProvider);
  final currentUser = ref.watch(authProvider);
  return repository.listPosts(
    userId: query.userId,
    tagName: query.tagName,
    onlyPublic: query.onlyPublic,
    actingUserId: currentUser?.userId,
  );
});

final communityPostDetailProvider =
    FutureProvider.family<CommunityPostDetailData, int>((ref, postId) async {
  final repository = ref.watch(communityRepositoryProvider);
  final currentUser = ref.watch(authProvider);
  return repository.getPostDetailBundle(
    postId,
    actingUserId: currentUser?.userId,
  );
});

final communityFavoritePostsProvider = FutureProvider<List<CommunityPostView>>((ref) async {
  final repository = ref.watch(communityRepositoryProvider);
  final currentUser = ref.watch(authProvider);
  if (currentUser == null) {
    return const [];
  }
  return repository.listFavoritePosts(
    userId: currentUser.userId,
    actingUserId: currentUser.userId,
  );
});
