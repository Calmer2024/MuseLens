import 'package:shared_preferences/shared_preferences.dart';

class CommunityLocalStore {
  CommunityLocalStore(this._prefs);

  final SharedPreferences _prefs;

  static String _likedPostsKey(int userId) => 'community_liked_posts_$userId';
  static String _favoritePostsKey(int userId) => 'community_favorite_posts_$userId';
  static String _likedCommentsKey(int userId) => 'community_liked_comments_$userId';

  Set<int> getLikedPostIds(int userId) {
    return _prefs
        .getStringList(_likedPostsKey(userId))
        ?.map(int.tryParse)
        .whereType<int>()
        .toSet() ??
        <int>{};
  }

  Future<void> setPostLiked(int userId, int postId, bool liked) async {
    final ids = getLikedPostIds(userId);
    if (liked) {
      ids.add(postId);
    } else {
      ids.remove(postId);
    }
    await _prefs.setStringList(
      _likedPostsKey(userId),
      ids.map((item) => item.toString()).toList(),
    );
  }

  List<int> getFavoritePostIds(int userId) {
    return _prefs
            .getStringList(_favoritePostsKey(userId))
            ?.map(int.tryParse)
            .whereType<int>()
            .toList() ??
        <int>[];
  }

  Future<void> setPostFavorited(int userId, int postId, bool favorited) async {
    final ids = getFavoritePostIds(userId);
    ids.remove(postId);
    if (favorited) {
      ids.insert(0, postId);
    }
    await _prefs.setStringList(
      _favoritePostsKey(userId),
      ids.map((item) => item.toString()).toList(),
    );
  }

  Set<int> getLikedCommentIds(int userId) {
    return _prefs
        .getStringList(_likedCommentsKey(userId))
        ?.map(int.tryParse)
        .whereType<int>()
        .toSet() ??
        <int>{};
  }

  Future<void> setCommentLiked(int userId, int commentId, bool liked) async {
    final ids = getLikedCommentIds(userId);
    if (liked) {
      ids.add(commentId);
    } else {
      ids.remove(commentId);
    }
    await _prefs.setStringList(
      _likedCommentsKey(userId),
      ids.map((item) => item.toString()).toList(),
    );
  }
}
