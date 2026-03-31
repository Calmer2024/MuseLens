import 'router_models.dart';

class LensToolAsset {
  const LensToolAsset({
    required this.name,
    required this.type,
    required this.description,
  });

  final String name;
  final String type;
  final String description;

  factory LensToolAsset.fromJson(Map<String, dynamic> json) {
    return LensToolAsset(
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
    );
  }
}

class LensToolParam {
  const LensToolParam({
    required this.name,
    required this.type,
    required this.description,
  });

  final String name;
  final String type;
  final String description;

  factory LensToolParam.fromJson(Map<String, dynamic> json) {
    return LensToolParam(
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
    );
  }
}

class LensToolSummary {
  const LensToolSummary({
    required this.lensId,
    required this.layer,
    required this.description,
    required this.workflowFilePath,
  });

  final String lensId;
  final String layer;
  final String description;
  final String workflowFilePath;

  factory LensToolSummary.fromJson(Map<String, dynamic> json) {
    return LensToolSummary(
      lensId: json['lens_id']?.toString() ?? '',
      layer: json['layer']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      workflowFilePath: json['workflow_file_path']?.toString() ?? '',
    );
  }
}

class LensToolDetail extends LensToolSummary {
  const LensToolDetail({
    required super.lensId,
    required super.layer,
    required super.description,
    required super.workflowFilePath,
    required this.inputs,
    required this.outputs,
    required this.params,
    required this.tweakControls,
  });

  final List<LensToolAsset> inputs;
  final List<LensToolAsset> outputs;
  final List<LensToolParam> params;
  final List<Map<String, dynamic>> tweakControls;

  factory LensToolDetail.fromJson(Map<String, dynamic> json) {
    return LensToolDetail(
      lensId: json['lens_id']?.toString() ?? '',
      layer: json['layer']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      workflowFilePath: json['workflow_file_path']?.toString() ?? '',
      inputs: (json['inputs'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => LensToolAsset.fromJson(item as Map<String, dynamic>))
          .toList(),
      outputs: (json['outputs'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => LensToolAsset.fromJson(item as Map<String, dynamic>))
          .toList(),
      params: (json['params'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => LensToolParam.fromJson(item as Map<String, dynamic>))
          .toList(),
      tweakControls: (json['tweak_controls'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => Map<String, dynamic>.from(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class LensToolRunResponse {
  const LensToolRunResponse({
    required this.lensId,
    required this.blueprint,
    required this.executed,
    required this.executionStarted,
    required this.streamId,
    required this.executionContext,
    required this.resultFilename,
    required this.resultUrl,
    required this.executionError,
    required this.stepResults,
  });

  final String lensId;
  final RouterBlueprint blueprint;
  final bool executed;
  final bool executionStarted;
  final String? streamId;
  final Map<String, dynamic> executionContext;
  final String? resultFilename;
  final String? resultUrl;
  final String? executionError;
  final List<RouterStepResult> stepResults;

  bool get hasExecutionError => executionError != null && executionError!.trim().isNotEmpty;

  factory LensToolRunResponse.fromJson(Map<String, dynamic> json) {
    return LensToolRunResponse(
      lensId: json['lens_id']?.toString() ?? '',
      blueprint: RouterBlueprint.fromJson(
        json['blueprint'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      executed: json['executed'] as bool? ?? false,
      executionStarted: json['execution_started'] as bool? ?? false,
      streamId: json['stream_id']?.toString(),
      executionContext: Map<String, dynamic>.from(
        json['execution_context'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      resultFilename: json['result_filename']?.toString(),
      resultUrl: json['result_url']?.toString(),
      executionError: json['execution_error']?.toString(),
      stepResults: (json['step_results'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => RouterStepResult.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class LensToolApplyControlsResponse {
  const LensToolApplyControlsResponse({
    required this.lensId,
    required this.translatedParams,
    required this.translatedAssets,
    required this.mergedParams,
    required this.mergedAssets,
    required this.explanations,
    required this.execution,
  });

  final String lensId;
  final Map<String, dynamic> translatedParams;
  final Map<String, String> translatedAssets;
  final Map<String, dynamic> mergedParams;
  final Map<String, String> mergedAssets;
  final List<String> explanations;
  final LensToolRunResponse? execution;

  factory LensToolApplyControlsResponse.fromJson(Map<String, dynamic> json) {
    return LensToolApplyControlsResponse(
      lensId: json['lens_id']?.toString() ?? '',
      translatedParams: Map<String, dynamic>.from(
        json['translated_params'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      translatedAssets: Map<String, String>.from(
        json['translated_assets'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      mergedParams: Map<String, dynamic>.from(
        json['merged_params'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      mergedAssets: Map<String, String>.from(
        json['merged_assets'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      explanations: (json['explanations'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(),
      execution: json['execution'] is Map<String, dynamic>
          ? LensToolRunResponse.fromJson(json['execution'] as Map<String, dynamic>)
          : null,
    );
  }
}

class LensToolTweakControlsResponse {
  const LensToolTweakControlsResponse({
    required this.lensId,
    required this.tweakControls,
  });

  final String lensId;
  final List<Map<String, dynamic>> tweakControls;

  factory LensToolTweakControlsResponse.fromJson(Map<String, dynamic> json) {
    return LensToolTweakControlsResponse(
      lensId: json['lens_id']?.toString() ?? '',
      tweakControls: (json['tweak_controls'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => Map<String, dynamic>.from(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
