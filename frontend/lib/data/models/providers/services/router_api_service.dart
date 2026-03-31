import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../router_models.dart';
import 'api_client.dart';

class RouterApiService {
  RouterApiService() : _dio = ApiClient().dio;

  final Dio _dio;
  static const String _basePath = '/api/v1/router';
  static const Duration _uploadTimeout = Duration(minutes: 2);
  static const Duration _routeTimeout = Duration(seconds: 45);
  static const Duration _routeAndRunTimeout = Duration(minutes: 10);

  Future<RouterStreamIdResult> createStreamId() async {
    final response = await _dio.get(
      '$_basePath/stream/new',
      options: Options(
        sendTimeout: _routeTimeout,
        receiveTimeout: _routeTimeout,
      ),
    );
    return RouterStreamIdResult.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<RouterBaseImageUploadResult> uploadBaseImage({
    required String filePath,
  }) async {
    final response = await _dio.post(
      '$_basePath/upload-base-image',
      data: FormData.fromMap({
        'image': await MultipartFile.fromFile(
          filePath,
          filename: _extractFileName(filePath),
        ),
      }),
      options: Options(
        contentType: 'multipart/form-data',
        sendTimeout: _uploadTimeout,
        receiveTimeout: _uploadTimeout,
      ),
    );
    return RouterBaseImageUploadResult.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<RouterResponse> route({
    required String userId,
    String? sessionId,
    String? userMessage,
    String? baseImage,
    Map<String, dynamic> baseImageMeta = const <String, dynamic>{},
    Map<String, String> userAssets = const <String, String>{},
    Map<String, dynamic> answers = const <String, dynamic>{},
  }) async {
    final response = await _dio.post(
      '$_basePath/route',
      data: {
        'user_id': userId,
        'session_id': sessionId,
        'user_message': userMessage,
        'base_image': baseImage,
        'base_image_meta': baseImageMeta,
        'user_assets': userAssets,
        'answers': answers,
      },
      options: Options(
        sendTimeout: _routeTimeout,
        receiveTimeout: _routeTimeout,
      ),
    );
    return RouterResponse.fromJson(
      _normalizeLoopbackUrls(response.data as Map<String, dynamic>),
    );
  }

  Future<RouterRouteAndRunResponse> routeAndRun({
    required String userId,
    String? sessionId,
    String? userMessage,
    String? baseImage,
    Map<String, dynamic> baseImageMeta = const <String, dynamic>{},
    Map<String, String> userAssets = const <String, String>{},
    Map<String, dynamic> answers = const <String, dynamic>{},
    bool executeWhenReady = true,
    bool asyncExecution = false,
    String? streamId,
  }) async {
    final response = await _dio.post(
      '$_basePath/route_and_run',
      data: {
        'user_id': userId,
        'session_id': sessionId,
        'user_message': userMessage,
        'base_image': baseImage,
        'base_image_meta': baseImageMeta,
        'user_assets': userAssets,
        'answers': answers,
        'execute_when_ready': executeWhenReady,
        'async_execution': asyncExecution,
        'stream_id': streamId,
      },
      options: Options(
        sendTimeout: _routeAndRunTimeout,
        receiveTimeout: _routeAndRunTimeout,
      ),
    );
    return RouterRouteAndRunResponse.fromJson(
      _normalizeLoopbackUrls(response.data as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> _normalizeLoopbackUrls(Map<String, dynamic> data) {
    return _normalizeNode(data) as Map<String, dynamic>;
  }

  dynamic _normalizeNode(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value.map<String, dynamic>(
        (key, nested) => MapEntry<String, dynamic>(key, _normalizeNode(nested)),
      );
    }
    if (value is List<dynamic>) {
      return value.map<dynamic>(_normalizeNode).toList();
    }
    if (value is String) {
      return _rewriteLocalUrl(value);
    }
    return value;
  }

  String _rewriteLocalUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return raw;
    final host = uri.host.trim();
    if (host != '127.0.0.1' && host != 'localhost') {
      return raw;
    }

    final baseUri = Uri.parse(ApiConstants.baseUrl);
    final updated = uri.replace(
      host: baseUri.host,
      port: uri.hasPort ? uri.port : baseUri.port,
    );
    return updated.toString();
  }

  String _extractFileName(String filePath) {
    final normalized = filePath.replaceAll('\\', '/');
    final segments = normalized.split('/');
    return segments.isEmpty ? 'upload.png' : segments.last;
  }
}
