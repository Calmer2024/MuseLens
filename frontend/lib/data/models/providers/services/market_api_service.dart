import 'package:dio/dio.dart';

import '../../market_models.dart';
import 'api_client.dart';

class MarketApiService {
  final Dio _dio = ApiClient().dio;
  static const String _basePath = '/api/v1/market';

  Future<List<MarketTag>> listTemplateTags() async {
    final response = await _dio.get('$_basePath/templates/tags');
    return (response.data as List<dynamic>)
        .map((item) => MarketTag.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<MarketLens>> listTemplates({
    String? q,
    String? tagName,
    String? category,
    String? status,
    bool? isOfficial,
    int? authorId,
    int? favoritedBy,
  }) async {
    final response = await _dio.get(
      '$_basePath/templates',
      queryParameters: {
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (tagName != null && tagName.trim().isNotEmpty)
          'tag_name': tagName.trim(),
        if (category != null && category.trim().isNotEmpty)
          'category': category.trim(),
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
        if (isOfficial != null) 'is_official': isOfficial,
        if (authorId != null) 'author_id': authorId,
        if (favoritedBy != null) 'favorited_by': favoritedBy,
      },
    );

    return (response.data as List<dynamic>)
        .map((item) => MarketLens.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> getTemplateDetail(int templateId) async {
    final response = await _dio.get('$_basePath/templates/$templateId');
    return response.data as Map<String, dynamic>;
  }

  Future<void> favoriteLens({required int lensId, required int userId}) async {
    await _dio.post(
      '$_basePath/templates/$lensId/favorite',
      data: {'user_id': userId},
    );
  }

  Future<void> unfavoriteLens({
    required int lensId,
    required int userId,
  }) async {
    await _dio.delete(
      '$_basePath/templates/$lensId/favorite',
      data: {'user_id': userId},
    );
  }

  Future<List<MarketLens>> listPublishedTemplates(int userId) async {
    final response = await _dio.get(
      '$_basePath/users/$userId/templates/published',
    );
    return (response.data as List<dynamic>)
        .map((item) => MarketLens.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<MarketLens>> listFavoriteTemplates(int userId) async {
    final response = await _dio.get(
      '$_basePath/users/$userId/templates/favorites',
    );
    return (response.data as List<dynamic>)
        .map((item) => MarketLens.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<MarketLensApplyResult> applyTemplate(
    int templateId,
    ApplyMarketLensInput input,
  ) async {
    final response = await _dio.post(
      '$_basePath/templates/$templateId/apply',
      data: input.toJson(),
    );
    return MarketLensApplyResult.fromJson(
      response.data as Map<String, dynamic>,
    );
  }
}
