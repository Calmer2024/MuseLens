import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../lens_tool_models.dart';
import '../../router_models.dart';
import 'api_client.dart';

class LensesApiService {
  LensesApiService() : _dio = ApiClient().dio;

  final Dio _dio;
  static const String _basePath = '/api/v1/lenses';
  static const Duration _defaultTimeout = Duration(seconds: 45);
  static const Duration _executionTimeout = Duration(minutes: 10);

  Future<List<LensToolSummary>> listLenses() async {
    final response = await _dio.get(
      _basePath,
      options: Options(
        sendTimeout: _defaultTimeout,
        receiveTimeout: _defaultTimeout,
      ),
    );
    final data = response.data as List<dynamic>? ?? const <dynamic>[];
    return data
        .map((item) => LensToolSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<LensToolDetail> getLensDetail(String lensId) async {
    final response = await _dio.get(
      '$_basePath/$lensId',
      options: Options(
        sendTimeout: _defaultTimeout,
        receiveTimeout: _defaultTimeout,
      ),
    );
    return LensToolDetail.fromJson(
      ApiConstants.normalizeLoopbackUrls(response.data as Map<String, dynamic>),
    );
  }

  Future<LensToolTweakControlsResponse> getTweakControls(String lensId) async {
    final response = await _dio.get(
      '$_basePath/$lensId/tweak-controls',
      options: Options(
        sendTimeout: _defaultTimeout,
        receiveTimeout: _defaultTimeout,
      ),
    );
    return LensToolTweakControlsResponse.fromJson(
      ApiConstants.normalizeLoopbackUrls(response.data as Map<String, dynamic>),
    );
  }

  Future<RouterStreamIdResult> createStreamId() async {
    final response = await _dio.get(
      '$_basePath/stream/new',
      options: Options(
        sendTimeout: _defaultTimeout,
        receiveTimeout: _defaultTimeout,
      ),
    );
    return RouterStreamIdResult.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<LensToolRunResponse> runLens({
    required String lensId,
    required Map<String, String> assets,
    required Map<String, dynamic> params,
    bool asyncExecution = false,
    String? streamId,
  }) async {
    final response = await _dio.post(
      '$_basePath/run',
      data: {
        'lens_id': lensId,
        'assets': assets,
        'params': params,
        'async_execution': asyncExecution,
        'stream_id': streamId,
      },
      options: Options(
        sendTimeout: _executionTimeout,
        receiveTimeout: _executionTimeout,
      ),
    );
    return LensToolRunResponse.fromJson(
      ApiConstants.normalizeLoopbackUrls(response.data as Map<String, dynamic>),
    );
  }

  Future<LensToolApplyControlsResponse> applyControls({
    required String lensId,
    required Map<String, String> assets,
    required Map<String, dynamic> currentParams,
    required Map<String, dynamic> controlValues,
    bool execute = true,
    bool asyncExecution = false,
    String? streamId,
  }) async {
    final response = await _dio.post(
      '$_basePath/$lensId/apply-controls',
      data: {
        'assets': assets,
        'current_params': currentParams,
        'control_values': controlValues,
        'execute': execute,
        'async_execution': asyncExecution,
        'stream_id': streamId,
      },
      options: Options(
        sendTimeout: _executionTimeout,
        receiveTimeout: _executionTimeout,
      ),
    );
    return LensToolApplyControlsResponse.fromJson(
      ApiConstants.normalizeLoopbackUrls(response.data as Map<String, dynamic>),
    );
  }
}
