enum RouterStatus {
  needClarification,
  ready,
  failed,
  unknown;

  static RouterStatus fromJson(String? value) {
    return switch (value) {
      'need_clarification' => RouterStatus.needClarification,
      'ready' => RouterStatus.ready,
      'failed' => RouterStatus.failed,
      _ => RouterStatus.unknown,
    };
  }
}

enum RouterQuestionType {
  text,
  singleChoice,
  multiChoice,
  slider,
  unknown;

  static RouterQuestionType fromJson(String? value) {
    return switch (value) {
      'text' => RouterQuestionType.text,
      'single_choice' => RouterQuestionType.singleChoice,
      'multi_choice' => RouterQuestionType.multiChoice,
      'slider' => RouterQuestionType.slider,
      _ => RouterQuestionType.unknown,
    };
  }
}

class RouterBaseImageUploadResult {
  const RouterBaseImageUploadResult({
    required this.filename,
    required this.originalFilename,
    required this.fileSize,
  });

  final String filename;
  final String originalFilename;
  final int fileSize;

  factory RouterBaseImageUploadResult.fromJson(Map<String, dynamic> json) {
    return RouterBaseImageUploadResult(
      filename: json['filename']?.toString() ?? '',
      originalFilename: json['original_filename']?.toString() ?? '',
      fileSize: json['file_size'] as int? ?? 0,
    );
  }
}

class RouterClarifyUiSchema {
  const RouterClarifyUiSchema({
    this.min,
    this.max,
    this.step,
    this.defaultValue,
    this.allowCustomText = false,
  });

  final double? min;
  final double? max;
  final double? step;
  final dynamic defaultValue;
  final bool allowCustomText;

  factory RouterClarifyUiSchema.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return RouterClarifyUiSchema(
      min: (data['min'] as num?)?.toDouble(),
      max: (data['max'] as num?)?.toDouble(),
      step: (data['step'] as num?)?.toDouble(),
      defaultValue: data['default'],
      allowCustomText: data['allow_custom_text'] as bool? ?? false,
    );
  }
}

class RouterQuestionBind {
  const RouterQuestionBind({
    required this.stepId,
    required this.lensId,
    required this.target,
    required this.name,
  });

  final String? stepId;
  final String? lensId;
  final String target;
  final String name;

  factory RouterQuestionBind.fromJson(Map<String, dynamic> json) {
    return RouterQuestionBind(
      stepId: json['step_id']?.toString(),
      lensId: json['lens_id']?.toString(),
      target: json['target']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

class RouterClarifyQuestion {
  const RouterClarifyQuestion({
    required this.id,
    required this.prompt,
    required this.type,
    required this.options,
    required this.required,
    required this.binds,
    required this.uiSchema,
  });

  final String id;
  final String prompt;
  final RouterQuestionType type;
  final List<String> options;
  final bool required;
  final List<RouterQuestionBind> binds;
  final RouterClarifyUiSchema uiSchema;

  factory RouterClarifyQuestion.fromJson(Map<String, dynamic> json) {
    return RouterClarifyQuestion(
      id: json['id']?.toString() ?? '',
      prompt: json['prompt']?.toString() ?? '',
      type: RouterQuestionType.fromJson(json['type']?.toString()),
      options: (json['options'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(),
      required: json['required'] as bool? ?? true,
      binds: (json['binds'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => RouterQuestionBind.fromJson(item as Map<String, dynamic>))
          .toList(),
      uiSchema: RouterClarifyUiSchema.fromJson(
        json['ui_schema'] as Map<String, dynamic>?,
      ),
    );
  }
}

class RouterBlueprintStep {
  const RouterBlueprintStep({
    required this.stepId,
    required this.lensId,
    required this.inputLinks,
    required this.params,
  });

  final String stepId;
  final String lensId;
  final Map<String, dynamic> inputLinks;
  final Map<String, dynamic> params;

  factory RouterBlueprintStep.fromJson(Map<String, dynamic> json) {
    return RouterBlueprintStep(
      stepId: json['step_id']?.toString() ?? '',
      lensId: json['lens_id']?.toString() ?? '',
      inputLinks: Map<String, dynamic>.from(
        json['input_links'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      params: Map<String, dynamic>.from(
        json['params'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
    );
  }
}

class RouterBlueprint {
  const RouterBlueprint({
    required this.initialInputs,
    required this.steps,
  });

  final Map<String, dynamic> initialInputs;
  final List<RouterBlueprintStep> steps;

  factory RouterBlueprint.fromJson(Map<String, dynamic> json) {
    return RouterBlueprint(
      initialInputs: Map<String, dynamic>.from(
        json['initial_inputs'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      steps: (json['steps'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => RouterBlueprintStep.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RouterStepOutput {
  const RouterStepOutput({
    required this.outputName,
    required this.filename,
    required this.url,
  });

  final String outputName;
  final String filename;
  final String? url;

  factory RouterStepOutput.fromJson(Map<String, dynamic> json) {
    return RouterStepOutput(
      outputName: json['output_name']?.toString() ?? '',
      filename: json['filename']?.toString() ?? '',
      url: json['url']?.toString(),
    );
  }
}

class RouterStepResult {
  const RouterStepResult({
    required this.stepId,
    required this.lensId,
    required this.tweakControls,
    required this.outputs,
  });

  final String stepId;
  final String lensId;
  final List<Map<String, dynamic>> tweakControls;
  final List<RouterStepOutput> outputs;

  factory RouterStepResult.fromJson(Map<String, dynamic> json) {
    return RouterStepResult(
      stepId: json['step_id']?.toString() ?? '',
      lensId: json['lens_id']?.toString() ?? '',
      tweakControls: (json['tweak_controls'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (item) => Map<String, dynamic>.from(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
      outputs: (json['outputs'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => RouterStepOutput.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RouterResponse {
  const RouterResponse({
    required this.sessionId,
    required this.status,
    required this.thoughtProcess,
    required this.questions,
    required this.blueprint,
    required this.extra,
  });

  final String sessionId;
  final RouterStatus status;
  final String thoughtProcess;
  final List<RouterClarifyQuestion> questions;
  final RouterBlueprint? blueprint;
  final Map<String, dynamic> extra;

  bool get needsClarification => status == RouterStatus.needClarification;
  bool get isReady => status == RouterStatus.ready;
  bool get isFailed => status == RouterStatus.failed;

  factory RouterResponse.fromJson(Map<String, dynamic> json) {
    return RouterResponse(
      sessionId: json['session_id']?.toString() ?? '',
      status: RouterStatus.fromJson(json['status']?.toString()),
      thoughtProcess: json['thought_process']?.toString() ?? '',
      questions: (json['questions'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => RouterClarifyQuestion.fromJson(item as Map<String, dynamic>))
          .toList(),
      blueprint: json['blueprint'] is Map<String, dynamic>
          ? RouterBlueprint.fromJson(json['blueprint'] as Map<String, dynamic>)
          : null,
      extra: Map<String, dynamic>.from(
        json['extra'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
    );
  }
}

class RouterRouteAndRunResponse extends RouterResponse {
  const RouterRouteAndRunResponse({
    required super.sessionId,
    required super.status,
    required super.thoughtProcess,
    required super.questions,
    required super.blueprint,
    required super.extra,
    required this.executed,
    required this.executionContext,
    required this.resultFilename,
    required this.resultUrl,
    required this.executionError,
    required this.executionStarted,
    required this.streamId,
    required this.stepResults,
  });

  final bool executed;
  final Map<String, dynamic> executionContext;
  final String? resultFilename;
  final String? resultUrl;
  final String? executionError;
  final bool executionStarted;
  final String? streamId;
  final List<RouterStepResult> stepResults;

  bool get hasExecutionError => executionError != null && executionError!.trim().isNotEmpty;

  RouterRouteAndRunResponse copyWith({
    String? sessionId,
    RouterStatus? status,
    String? thoughtProcess,
    List<RouterClarifyQuestion>? questions,
    RouterBlueprint? blueprint,
    Map<String, dynamic>? extra,
    bool? executed,
    Map<String, dynamic>? executionContext,
    String? resultFilename,
    Object? resultUrl = _routerUnset,
    Object? executionError = _routerUnset,
    bool? executionStarted,
    Object? streamId = _routerUnset,
    List<RouterStepResult>? stepResults,
  }) {
    return RouterRouteAndRunResponse(
      sessionId: sessionId ?? this.sessionId,
      status: status ?? this.status,
      thoughtProcess: thoughtProcess ?? this.thoughtProcess,
      questions: questions ?? this.questions,
      blueprint: blueprint ?? this.blueprint,
      extra: extra ?? this.extra,
      executed: executed ?? this.executed,
      executionContext: executionContext ?? this.executionContext,
      resultFilename: resultFilename ?? this.resultFilename,
      resultUrl: identical(resultUrl, _routerUnset)
          ? this.resultUrl
          : resultUrl as String?,
      executionError: identical(executionError, _routerUnset)
          ? this.executionError
          : executionError as String?,
      executionStarted: executionStarted ?? this.executionStarted,
      streamId: identical(streamId, _routerUnset)
          ? this.streamId
          : streamId as String?,
      stepResults: stepResults ?? this.stepResults,
    );
  }

  factory RouterRouteAndRunResponse.fromJson(Map<String, dynamic> json) {
    return RouterRouteAndRunResponse(
      sessionId: json['session_id']?.toString() ?? '',
      status: RouterStatus.fromJson(json['status']?.toString()),
      thoughtProcess: json['thought_process']?.toString() ?? '',
      questions: (json['questions'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => RouterClarifyQuestion.fromJson(item as Map<String, dynamic>))
          .toList(),
      blueprint: json['blueprint'] is Map<String, dynamic>
          ? RouterBlueprint.fromJson(json['blueprint'] as Map<String, dynamic>)
          : null,
      extra: Map<String, dynamic>.from(
        json['extra'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      executed: json['executed'] as bool? ?? false,
      executionContext: Map<String, dynamic>.from(
        json['execution_context'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      resultFilename: json['result_filename']?.toString(),
      resultUrl: json['result_url']?.toString(),
      executionError: json['execution_error']?.toString(),
      executionStarted: json['execution_started'] as bool? ?? false,
      streamId: json['stream_id']?.toString(),
      stepResults: (json['step_results'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => RouterStepResult.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RouterStreamIdResult {
  const RouterStreamIdResult({required this.streamId});

  final String streamId;

  factory RouterStreamIdResult.fromJson(Map<String, dynamic> json) {
    return RouterStreamIdResult(
      streamId: json['stream_id']?.toString() ?? '',
    );
  }
}

const Object _routerUnset = Object();
