import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/providers/services/router_api_service.dart';
import '../models/router_models.dart';

final routerApiServiceProvider = Provider<RouterApiService>((ref) {
  return RouterApiService();
});

final routerRepositoryProvider = Provider<RouterRepository>((ref) {
  return RouterRepository(apiService: ref.watch(routerApiServiceProvider));
});

class RouterRepository {
  RouterRepository({required RouterApiService apiService}) : _apiService = apiService;

  final RouterApiService _apiService;

  Future<RouterBaseImageUploadResult> uploadBaseImage({
    required String filePath,
  }) {
    return _apiService.uploadBaseImage(filePath: filePath);
  }

  Future<RouterStreamIdResult> createStreamId() {
    return _apiService.createStreamId();
  }

  Future<RouterResponse> route({
    required String userId,
    String? sessionId,
    String? userMessage,
    String? baseImage,
    Map<String, dynamic> baseImageMeta = const <String, dynamic>{},
    Map<String, String> userAssets = const <String, String>{},
    Map<String, dynamic> answers = const <String, dynamic>{},
  }) {
    return _apiService.route(
      userId: userId,
      sessionId: sessionId,
      userMessage: userMessage,
      baseImage: baseImage,
      baseImageMeta: baseImageMeta,
      userAssets: userAssets,
      answers: answers,
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
  }) {
    return _apiService.routeAndRun(
      userId: userId,
      sessionId: sessionId,
      userMessage: userMessage,
      baseImage: baseImage,
      baseImageMeta: baseImageMeta,
      userAssets: userAssets,
      answers: answers,
      executeWhenReady: executeWhenReady,
      asyncExecution: asyncExecution,
      streamId: streamId,
    );
  }
}
