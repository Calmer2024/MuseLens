import 'package:dio/dio.dart';

import '../../community_models.dart';
import 'api_client.dart';

class CommunityApiService {
  final Dio _dio = ApiClient().dio;
  static const String _basePath = '/api/v1/community';

  Future<CommunityPost> createPost(CreatePostInput input) async {
    final response = await _dio.post('$_basePath/posts', data: input.toJson());
    return CommunityPost.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<CommunityPost>> listPosts({
    int? userId,
    String? tagName,
    bool onlyPublic = true,
  }) async {
    final response = await _dio.get(
      '$_basePath/posts',
      queryParameters: {
        if (userId != null) 'user_id': userId,
        if (tagName != null && tagName.trim().isNotEmpty)
          'tag_name': tagName.trim(),
        'only_public': onlyPublic,
      },
    );
    return (response.data as List<dynamic>)
        .map((item) => CommunityPost.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<CommunityPost> getPostDetail(int postId) async {
    final response = await _dio.get('$_basePath/posts/$postId');
    return CommunityPost.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deletePost({required int postId, required int userId}) async {
    await _dio.delete('$_basePath/posts/$postId', data: {'user_id': userId});
  }

  Future<CommunityComment> createComment({
    required int postId,
    required int userId,
    required String content,
    int? parentId,
  }) async {
    final response = await _dio.post(
      '$_basePath/posts/$postId/comments',
      data: {
        'user_id': userId,
        'content': content.trim(),
        if (parentId != null) 'parent_id': parentId,
      },
    );
    return CommunityComment.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<CommunityComment>> listComments(int postId) async {
    final response = await _dio.get('$_basePath/posts/$postId/comments');
    final data = response.data as Map<String, dynamic>;
    return (data['comments'] as List<dynamic>? ?? const [])
        .map((item) => CommunityComment.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> likePost({required int postId, required int userId}) async {
    await _dio.post('$_basePath/posts/$postId/like', data: {'user_id': userId});
  }

  Future<void> unlikePost({required int postId, required int userId}) async {
    await _dio.delete(
      '$_basePath/posts/$postId/like',
      data: {'user_id': userId},
    );
  }

  Future<void> favoritePost({required int postId, required int userId}) async {
    await _dio.post(
      '$_basePath/posts/$postId/favorite',
      data: {'user_id': userId},
    );
  }

  Future<void> unfavoritePost({
    required int postId,
    required int userId,
  }) async {
    await _dio.delete(
      '$_basePath/posts/$postId/favorite',
      data: {'user_id': userId},
    );
  }

  Future<void> likeComment({
    required int commentId,
    required int userId,
  }) async {
    await _dio.post(
      '$_basePath/comments/$commentId/like',
      data: {'user_id': userId},
    );
  }

  Future<void> unlikeComment({
    required int commentId,
    required int userId,
  }) async {
    await _dio.delete(
      '$_basePath/comments/$commentId/like',
      data: {'user_id': userId},
    );
  }

  Future<List<CommunityTag>> listTags() async {
    final response = await _dio.get('$_basePath/tags');
    return (response.data as List<dynamic>)
        .map((item) => CommunityTag.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
