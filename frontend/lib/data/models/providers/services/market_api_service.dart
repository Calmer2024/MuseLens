import 'package:dio/dio.dart';

import '../../market_models.dart';
import 'api_client.dart';

class MarketApiService {
  final Dio _dio = ApiClient().dio;
  static const String _basePath = '/api/v1/market';

  Future<List<MarketTag>> listTemplateTags() async {
    try {
      final response = await _dio.get('$_basePath/templates/tags');
      return (response.data as List<dynamic>)
          .map((item) => MarketTag.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (error) {
      return const <MarketTag>[];
    }
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
    final queryParameters = {
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      if (tagName != null && tagName.trim().isNotEmpty)
        'tag_name': tagName.trim(),
      if (category != null && category.trim().isNotEmpty)
        'category': category.trim(),
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      if (isOfficial != null) 'is_official': isOfficial,
      if (authorId != null) 'author_id': authorId,
      if (favoritedBy != null) 'favorited_by': favoritedBy,
    };

    try {
      final response = await _dio.get(
        '$_basePath/templates',
        queryParameters: queryParameters,
      );
      return (response.data as List<dynamic>)
          .map((item) => MarketLens.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      try {
        final response = await _dio.get(
          '$_basePath/lenses',
          queryParameters: queryParameters,
        );
        return (response.data as List<dynamic>)
            .map((item) => MarketLens.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (fallbackError) {
        return const <MarketLens>[];
      }
    }
  }

  Future<Map<String, dynamic>> getTemplateDetail(int templateId) async {
    try {
      final response = await _dio.get('$_basePath/templates/$templateId');
      return response.data as Map<String, dynamic>;
    } catch (_) {
      try {
        final response = await _dio.get('$_basePath/lenses/$templateId');
        return response.data as Map<String, dynamic>;
      } catch (fallbackError) {
        rethrow;
      }
    }
  }

  Future<void> favoriteLens({required int lensId, required int userId}) async {
    try {
      await _dio.post(
        '$_basePath/templates/$lensId/favorite',
        data: {'user_id': userId},
      );
    } catch (_) {
      try {
        await _dio.post(
          '$_basePath/lenses/$lensId/favorite',
          data: {'user_id': userId},
        );
      } catch (fallbackError) {
        rethrow;
      }
    }
  }

  Future<void> unfavoriteLens({
    required int lensId,
    required int userId,
  }) async {
    try {
      await _dio.delete(
        '$_basePath/templates/$lensId/favorite',
        data: {'user_id': userId},
      );
    } catch (_) {
      try {
        await _dio.delete(
          '$_basePath/lenses/$lensId/favorite',
          data: {'user_id': userId},
        );
      } catch (fallbackError) {
        rethrow;
      }
    }
  }

  Future<List<MarketLens>> listPublishedTemplates(int userId) async {
    try {
      final response = await _dio.get(
        '$_basePath/users/$userId/templates/published',
      );
      return (response.data as List<dynamic>)
          .map((item) => MarketLens.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return listTemplates(authorId: userId);
    }
  }

  Future<List<MarketLens>> listFavoriteTemplates(int userId) async {
    try {
      final response = await _dio.get(
        '$_basePath/users/$userId/templates/favorites',
      );
      return (response.data as List<dynamic>)
          .map((item) => MarketLens.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      try {
        final response = await _dio.get('$_basePath/users/$userId/favorites');
        return (response.data as List<dynamic>)
            .map((item) => MarketLens.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (fallbackError) {
        return const <MarketLens>[];
      }
    }
  }

  Future<MarketLensApplyResult> applyTemplate(
    int templateId,
    ApplyMarketLensInput input,
  ) async {
    try {
      final response = await _dio.post(
        '$_basePath/templates/$templateId/apply',
        data: input.toJson(),
      );
      return MarketLensApplyResult.fromJson(
        response.data as Map<String, dynamic>,
      );
    } catch (_) {
      try {
        final response = await _dio.post(
          '$_basePath/lenses/$templateId/apply',
          data: input.toJson(),
        );
        final legacy = response.data as Map<String, dynamic>;
        final templateJson = Map<String, dynamic>.from(
          legacy['template'] as Map<String, dynamic>? ??
              legacy['lens'] as Map<String, dynamic>? ??
              const <String, dynamic>{},
        );
        final versionJson = Map<String, dynamic>.from(
          legacy['version'] as Map<String, dynamic>? ?? const <String, dynamic>{},
        );

        return MarketLensApplyResult.fromJson({
          ...legacy,
          'template': templateJson,
          'version': versionJson,
          'musedna': legacy['musedna'] ?? legacy['blueprint'] ?? const {},
        });
      } catch (fallbackError) {
        rethrow;
      }
    }
  }

  bool _isNotFound(DioException error) => error.response?.statusCode == 404;
}
