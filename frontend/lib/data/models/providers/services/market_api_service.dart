import 'package:dio/dio.dart';

import '../../market_models.dart';
import 'api_client.dart';

class MarketApiService {
  final Dio _dio = ApiClient().dio;
  static const String _basePath = '/api/v1/market';

  Future<MarketLens> createLens(CreateMarketLensInput input) async {
    final response = await _dio.post(
      '$_basePath/lenses',
      data: input.toJson(),
    );
    return MarketLens.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MarketLens> updateLens(int lensId, UpdateMarketLensInput input) async {
    final response = await _dio.patch(
      '$_basePath/lenses/$lensId',
      data: input.toJson(),
    );
    return MarketLens.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<MarketLens>> listLenses({
    String? category,
    String? status,
    bool? isOfficial,
  }) async {
    final response = await _dio.get(
      '$_basePath/lenses',
      queryParameters: {
        if (category != null && category.trim().isNotEmpty)
          'category': category.trim(),
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
        if (isOfficial != null) 'is_official': isOfficial,
      },
    );

    return (response.data as List<dynamic>)
        .map((item) => MarketLens.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> getLensDetail(int lensId) async {
    final response = await _dio.get('$_basePath/lenses/$lensId');
    return response.data as Map<String, dynamic>;
  }

  Future<MarketLensVersion> createVersion(
    int lensId,
    CreateMarketLensVersionInput input,
  ) async {
    final response = await _dio.post(
      '$_basePath/lenses/$lensId/versions',
      data: input.toJson(),
    );
    return MarketLensVersion.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> installLens({
    required int lensId,
    required int userId,
    int? versionId,
  }) async {
    await _dio.post(
      '$_basePath/lenses/$lensId/install',
      data: {
        'user_id': userId,
        if (versionId != null) 'version_id': versionId,
      },
    );
  }

  Future<void> uninstallLens({
    required int lensId,
    required int userId,
  }) async {
    await _dio.delete(
      '$_basePath/lenses/$lensId/install',
      data: {'user_id': userId},
    );
  }

  Future<void> favoriteLens({
    required int lensId,
    required int userId,
  }) async {
    await _dio.post(
      '$_basePath/lenses/$lensId/favorite',
      data: {'user_id': userId},
    );
  }

  Future<void> unfavoriteLens({
    required int lensId,
    required int userId,
  }) async {
    await _dio.delete(
      '$_basePath/lenses/$lensId/favorite',
      data: {'user_id': userId},
    );
  }

  Future<LensReview> createOrUpdateReview(
    int lensId,
    CreateLensReviewInput input,
  ) async {
    final response = await _dio.post(
      '$_basePath/lenses/$lensId/reviews',
      data: input.toJson(),
    );
    return LensReview.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<MarketLens>> listInstalledLenses(int userId) async {
    final response = await _dio.get('$_basePath/users/$userId/installed');
    return (response.data as List<dynamic>)
        .map((item) => MarketLens.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<MarketLens>> listFavoriteLenses(int userId) async {
    final response = await _dio.get('$_basePath/users/$userId/favorites');
    return (response.data as List<dynamic>)
        .map((item) => MarketLens.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
