import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_provider.dart';
import '../models/community_models.dart';
import '../models/providers/services/community_api_service.dart';
import '../models/providers/services/community_local_store.dart';
import '../models/providers/services/user_api_service.dart';

final communityApiServiceProvider = Provider<CommunityApiService>((ref) {
  return CommunityApiService();
});

final communityLocalStoreProvider = Provider<CommunityLocalStore>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return CommunityLocalStore(prefs);
});

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return CommunityRepository(
    apiService: ref.watch(communityApiServiceProvider),
    userApiService: ref.watch(userApiServiceProvider),
    localStore: ref.watch(communityLocalStoreProvider),
  );
});

class CommunityRepository {
  CommunityRepository({
    required CommunityApiService apiService,
    required UserApiService userApiService,
    required CommunityLocalStore localStore,
  }) : _apiService = apiService,
       _userApiService = userApiService,
       _localStore = localStore;

  final CommunityApiService _apiService;
  final UserApiService _userApiService;
  final CommunityLocalStore _localStore;

  Future<List<CommunityTag>> listTags() {
    return _apiService.listTags();
  }

  Future<List<CommunityPostView>> listPosts({
    int? userId,
    String? tagName,
    bool onlyPublic = true,
    int? actingUserId,
  }) async {
    final posts = await _apiService.listPosts(
      userId: userId,
      tagName: tagName,
      onlyPublic: onlyPublic,
    );
    return _hydratePosts(posts, actingUserId: actingUserId);
  }

  Future<CommunityPostDetailData> getPostDetailBundle(
    int postId, {
    int? actingUserId,
  }) async {
    final results = await Future.wait<dynamic>([
      _apiService.getPostDetail(postId),
      _apiService.listComments(postId),
    ]);
    final post = results[0] as CommunityPost;
    final comments = results[1] as List<CommunityComment>;
    final hydratedPost = (await _hydratePosts([
      post,
    ], actingUserId: actingUserId)).first;
    final hydratedComments = await _hydrateComments(
      comments,
      actingUserId: actingUserId,
    );
    return CommunityPostDetailData(
      post: hydratedPost,
      comments: hydratedComments,
    );
  }

  Future<CommunityPostView> createPost(
    CreatePostInput input, {
    int? actingUserId,
  }) async {
    final post = await _apiService.createPost(input);
    return (await _hydratePosts([
      post,
    ], actingUserId: actingUserId ?? input.userId)).first;
  }

  Future<void> deletePost({required int postId, required int userId}) async {
    await _apiService.deletePost(postId: postId, userId: userId);
    await _localStore.removePostState(userId, postId);
  }

  Future<void> setPostLiked({
    required int postId,
    required int userId,
    required bool liked,
  }) async {
    if (liked) {
      await _apiService.likePost(postId: postId, userId: userId);
    } else {
      await _apiService.unlikePost(postId: postId, userId: userId);
    }
    await _localStore.setPostLiked(userId, postId, liked);
  }

  Future<void> setPostFavorited({
    required int postId,
    required int userId,
    required bool favorited,
  }) async {
    if (favorited) {
      await _apiService.favoritePost(postId: postId, userId: userId);
    } else {
      await _apiService.unfavoritePost(postId: postId, userId: userId);
    }
    await _localStore.setPostFavorited(userId, postId, favorited);
  }

  Future<void> setCommentLiked({
    required int commentId,
    required int userId,
    required bool liked,
  }) async {
    if (liked) {
      await _apiService.likeComment(commentId: commentId, userId: userId);
    } else {
      await _apiService.unlikeComment(commentId: commentId, userId: userId);
    }
    await _localStore.setCommentLiked(userId, commentId, liked);
  }

  Future<CommunityComment> createComment({
    required int postId,
    required int userId,
    required String content,
    int? parentId,
  }) {
    return _apiService.createComment(
      postId: postId,
      userId: userId,
      content: content,
      parentId: parentId,
    );
  }

  Future<List<CommunityPostView>> listFavoritePosts({
    required int userId,
    int? actingUserId,
  }) async {
    final favoriteIds = _localStore.getFavoritePostIds(userId);
    if (favoriteIds.isEmpty) {
      return const [];
    }

    final listedPosts = await _apiService.listPosts(onlyPublic: true);
    final listedById = <int, CommunityPost>{
      for (final post in listedPosts) post.postId: post,
    };

    final missingIds = favoriteIds
        .where((id) => !listedById.containsKey(id))
        .toList();
    for (final postId in missingIds) {
      try {
        listedById[postId] = await _apiService.getPostDetail(postId);
      } catch (_) {
        continue;
      }
    }

    final availablePosts = favoriteIds
        .map((postId) => listedById[postId])
        .whereType<CommunityPost>()
        .toList();
    final hydratedPosts = await _hydratePosts(
      availablePosts,
      actingUserId: actingUserId ?? userId,
    );

    final orderMap = <int, int>{
      for (var i = 0; i < favoriteIds.length; i++) favoriteIds[i]: i,
    };
    hydratedPosts.sort(
      (a, b) => (orderMap[a.post.postId] ?? 99999).compareTo(
        orderMap[b.post.postId] ?? 99999,
      ),
    );
    return hydratedPosts;
  }

  Future<List<CommunityPostView>> _hydratePosts(
    List<CommunityPost> posts, {
    int? actingUserId,
  }) async {
    final authors = await _loadAuthors(posts.map((item) => item.userId));
    final likedPosts = actingUserId != null
        ? _localStore.getLikedPostIds(actingUserId)
        : const <int>{};
    final favoritedPosts = actingUserId != null
        ? _localStore.getFavoritePostIds(actingUserId).toSet()
        : const <int>{};

    return posts
        .map(
          (post) => CommunityPostView(
            post: post,
            author:
                authors[post.userId] ??
                CommunityAuthor.placeholder(post.userId),
            isLiked: likedPosts.contains(post.postId),
            isFavorited: favoritedPosts.contains(post.postId),
          ),
        )
        .toList();
  }

  Future<List<CommunityCommentView>> _hydrateComments(
    List<CommunityComment> comments, {
    int? actingUserId,
  }) async {
    final authors = await _loadAuthors(comments.map((item) => item.userId));
    final likedComments = actingUserId != null
        ? _localStore.getLikedCommentIds(actingUserId)
        : const <int>{};

    final replyMap = <int, List<CommunityCommentView>>{};
    final roots = <CommunityCommentView>[];

    for (final comment in comments) {
      final view = CommunityCommentView(
        comment: comment,
        author:
            authors[comment.userId] ??
            CommunityAuthor.placeholder(comment.userId),
        isLiked: likedComments.contains(comment.commentId),
        replies: const [],
      );

      if (comment.parentId == null) {
        roots.add(view);
      } else {
        replyMap
            .putIfAbsent(comment.parentId!, () => <CommunityCommentView>[])
            .add(view);
      }
    }

    return roots
        .map(
          (item) => item.copyWith(
            replies: replyMap[item.comment.commentId] ?? const [],
          ),
        )
        .toList();
  }

  Future<Map<int, CommunityAuthor>> _loadAuthors(Iterable<int> userIds) async {
    final uniqueIds = userIds.toSet().toList();
    if (uniqueIds.isEmpty) {
      return const {};
    }

    final userResults = await Future.wait(
      uniqueIds.map((userId) async {
        try {
          final user = await _userApiService.getUserById(userId);
          return MapEntry(userId, CommunityAuthor.fromUser(user));
        } catch (_) {
          return MapEntry(userId, CommunityAuthor.placeholder(userId));
        }
      }),
    );

    return Map<int, CommunityAuthor>.fromEntries(userResults);
  }
}
