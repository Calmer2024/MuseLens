import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/lens_tool_models.dart';
import '../models/providers/services/lenses_api_service.dart';
import '../models/router_models.dart';

final lensesApiServiceProvider = Provider<LensesApiService>((ref) {
  return LensesApiService();
});

final lensesRepositoryProvider = Provider<LensesRepository>((ref) {
  return LensesRepository(apiService: ref.watch(lensesApiServiceProvider));
});

class LensesRepository {
  LensesRepository({required LensesApiService apiService}) : _apiService = apiService;

  final LensesApiService _apiService;

  Future<List<LensToolSummary>> listLenses() => _apiService.listLenses();

  Future<LensToolDetail> getLensDetail(String lensId) => _apiService.getLensDetail(lensId);

  Future<LensToolTweakControlsResponse> getTweakControls(String lensId) =>
      _apiService.getTweakControls(lensId);

  Future<RouterStreamIdResult> createStreamId() => _apiService.createStreamId();

  Future<LensToolRunResponse> runLens({
    required String lensId,
    required Map<String, String> assets,
    required Map<String, dynamic> params,
    bool asyncExecution = false,
    String? streamId,
  }) {
    return _apiService.runLens(
      lensId: lensId,
      assets: assets,
      params: params,
      asyncExecution: asyncExecution,
      streamId: streamId,
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
  }) {
    return _apiService.applyControls(
      lensId: lensId,
      assets: assets,
      currentParams: currentParams,
      controlValues: controlValues,
      execute: execute,
      asyncExecution: asyncExecution,
      streamId: streamId,
    );
  }
}
