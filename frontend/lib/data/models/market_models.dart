import 'package:flutter/foundation.dart';

import 'user_model.dart';

@immutable
class MarketTag {
  final int tagId;
  final String name;
  final String description;
  final int templateCount;
  final DateTime? createdAt;

  const MarketTag({
    required this.tagId,
    required this.name,
    required this.description,
    required this.templateCount,
    required this.createdAt,
  });

  factory MarketTag.fromJson(Map<String, dynamic> json) {
    return MarketTag(
      tagId: json['tag_id'] as int? ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      templateCount: json['template_count'] as int? ?? 0,
      createdAt: _readDateTime(json['created_at']),
    );
  }
}

@immutable
class MarketLensAuthor {
  final int? userId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final bool isVerified;

  const MarketLensAuthor({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.isVerified,
  });

  factory MarketLensAuthor.fromJson(Map<String, dynamic> json) {
    final username = json['username']?.toString() ?? '';
    final nickname = json['nickname']?.toString().trim() ?? '';
    return MarketLensAuthor(
      userId: json['user_id'] as int?,
      username: username,
      displayName: nickname.isNotEmpty ? nickname : username,
      avatarUrl: json['avatar_url']?.toString(),
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }

  factory MarketLensAuthor.fromUser(User user) {
    final nickname = user.nickname?.trim();
    return MarketLensAuthor(
      userId: user.userId,
      username: user.username,
      displayName: nickname != null && nickname.isNotEmpty
          ? nickname
          : user.username,
      avatarUrl: user.avatarUrl,
      isVerified: user.isVerified,
    );
  }

  factory MarketLensAuthor.placeholder(int? userId) {
    if (userId == null) {
      return const MarketLensAuthor(
        userId: null,
        username: 'official',
        displayName: 'MuseLens 官方',
        avatarUrl: null,
        isVerified: true,
      );
    }
    return MarketLensAuthor(
      userId: userId,
      username: 'user_$userId',
      displayName: '用户$userId',
      avatarUrl: null,
      isVerified: false,
    );
  }
}

@immutable
class MarketLens {
  final int templateId;
  final String templateKey;
  final String title;
  final String description;
  final int? authorId;
  final MarketLensAuthor? author;
  final String? category;
  final bool isOfficial;
  final String status;
  final String? coverImageUrl;
  final String? originalImageUrl;
  final String? originalThumbnailUrl;
  final String? resultImageUrl;
  final String? resultThumbnailUrl;
  final String? sourceProjectId;
  final String? sourceRootNodeId;
  final String? resultAssetNodeId;
  final String? previewAssetNodeId;
  final int applyCount;
  final int favoriteCount;
  final int installCount;
  final double rating;
  final int ratingCount;
  final List<MarketTag> tags;
  final List<String> tagNames;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MarketLens({
    required this.templateId,
    required this.templateKey,
    required this.title,
    required this.description,
    required this.authorId,
    required this.author,
    required this.category,
    required this.isOfficial,
    required this.status,
    required this.coverImageUrl,
    required this.originalImageUrl,
    required this.originalThumbnailUrl,
    required this.resultImageUrl,
    required this.resultThumbnailUrl,
    required this.sourceProjectId,
    required this.sourceRootNodeId,
    required this.resultAssetNodeId,
    required this.previewAssetNodeId,
    required this.applyCount,
    required this.favoriteCount,
    required this.installCount,
    required this.rating,
    required this.ratingCount,
    required this.tags,
    required this.tagNames,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MarketLens.fromJson(Map<String, dynamic> json) {
    final tags = (json['tags'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => MarketTag.fromJson(item as Map<String, dynamic>))
        .toList();
    final tagNames = (json['tag_names'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();

    return MarketLens(
      templateId: json['template_id'] as int? ?? json['lens_id'] as int? ?? 0,
      templateKey:
          json['template_key']?.toString() ??
          json['lens_key']?.toString() ??
          '',
      title: json['title']?.toString() ?? json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      authorId: json['author_id'] as int?,
      author: json['author'] is Map<String, dynamic>
          ? MarketLensAuthor.fromJson(json['author'] as Map<String, dynamic>)
          : null,
      category: json['category']?.toString(),
      isOfficial: json['is_official'] as bool? ?? false,
      status: json['status']?.toString() ?? 'active',
      coverImageUrl: json['cover_image_url']?.toString(),
      originalImageUrl: json['original_image_url']?.toString(),
      originalThumbnailUrl: json['original_thumbnail_url']?.toString(),
      resultImageUrl: json['result_image_url']?.toString(),
      resultThumbnailUrl: json['result_thumbnail_url']?.toString(),
      sourceProjectId: json['source_project_id']?.toString(),
      sourceRootNodeId: json['source_root_node_id']?.toString(),
      resultAssetNodeId: json['result_asset_node_id']?.toString(),
      previewAssetNodeId: json['preview_asset_node_id']?.toString(),
      applyCount: json['apply_count'] as int? ?? 0,
      favoriteCount: json['favorite_count'] as int? ?? 0,
      installCount: json['install_count'] as int? ?? 0,
      rating: _readDouble(json['rating']),
      ratingCount: json['rating_count'] as int? ?? 0,
      tags: tags,
      tagNames: tagNames.isNotEmpty
          ? tagNames
          : tags.map((item) => item.name).toList(),
      createdAt: _readDateTime(json['created_at']),
      updatedAt: _readDateTime(json['updated_at']),
    );
  }

  String get primaryImageUrl =>
      resultImageUrl ??
      coverImageUrl ??
      resultThumbnailUrl ??
      originalImageUrl ??
      originalThumbnailUrl ??
      '';

  String get comparisonBeforeUrl =>
      originalImageUrl ??
      originalThumbnailUrl ??
      coverImageUrl ??
      primaryImageUrl;

  String get comparisonAfterUrl =>
      resultImageUrl ??
      resultThumbnailUrl ??
      coverImageUrl ??
      comparisonBeforeUrl;

  String get displayCategory {
    final value = category?.trim() ?? '';
    return value.isEmpty ? '未分类' : value;
  }

  String get publishedAtLabel {
    final value = updatedAt ?? createdAt;
    if (value == null) {
      return '';
    }
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  List<String> get visibleTags => tagNames.take(3).toList();

  int get lensId => templateId;
  String get lensKey => templateKey;
  String get name => title;
}

@immutable
class MarketLensVersion {
  final int versionId;
  final int templateId;
  final String version;
  final Map<String, dynamic>? musedna;
  final List<String> requiredInputs;
  final Map<String, dynamic> parameters;
  final Map<String, dynamic> uiSchema;
  final Map<String, dynamic> baseWorkflow;
  final String? sourceAssetNodeId;
  final int? sourceEpisodeId;
  final String publishedFrom;
  final String changelog;
  final bool isLatest;
  final DateTime? createdAt;

  const MarketLensVersion({
    required this.versionId,
    required this.templateId,
    required this.version,
    required this.musedna,
    required this.requiredInputs,
    required this.parameters,
    required this.uiSchema,
    required this.baseWorkflow,
    required this.sourceAssetNodeId,
    required this.sourceEpisodeId,
    required this.publishedFrom,
    required this.changelog,
    required this.isLatest,
    required this.createdAt,
  });

  factory MarketLensVersion.fromJson(Map<String, dynamic> json) {
    return MarketLensVersion(
      versionId: json['version_id'] as int? ?? 0,
      templateId: json['template_id'] as int? ?? json['lens_id'] as int? ?? 0,
      version: json['version']?.toString() ?? '',
      musedna: json['musedna'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['musedna'] as Map<String, dynamic>)
          : (json['blueprint'] is Map<String, dynamic>
                ? Map<String, dynamic>.from(
                    json['blueprint'] as Map<String, dynamic>,
                  )
                : null),
      requiredInputs: (json['required_inputs'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      parameters: Map<String, dynamic>.from(
        json['parameters'] as Map<String, dynamic>? ??
            const <String, dynamic>{},
      ),
      uiSchema: Map<String, dynamic>.from(
        json['ui_schema'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      baseWorkflow: Map<String, dynamic>.from(
        json['base_workflow'] as Map<String, dynamic>? ??
            const <String, dynamic>{},
      ),
      sourceAssetNodeId: json['source_asset_node_id']?.toString(),
      sourceEpisodeId: json['source_episode_id'] as int?,
      publishedFrom: json['published_from']?.toString() ?? '',
      changelog: json['changelog']?.toString() ?? '',
      isLatest: json['is_latest'] as bool? ?? false,
      createdAt: _readDateTime(json['created_at']),
    );
  }
}

@immutable
class LensReview {
  final int reviewId;
  final int lensId;
  final int userId;
  final int rating;
  final String content;
  final DateTime? createdAt;

  const LensReview({
    required this.reviewId,
    required this.lensId,
    required this.userId,
    required this.rating,
    required this.content,
    required this.createdAt,
  });

  factory LensReview.fromJson(Map<String, dynamic> json) {
    return LensReview(
      reviewId: json['review_id'] as int? ?? 0,
      lensId: json['lens_id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? 0,
      rating: json['rating'] as int? ?? 0,
      content: json['content']?.toString() ?? '',
      createdAt: _readDateTime(json['created_at']),
    );
  }
}

@immutable
class LensReviewView {
  final LensReview review;
  final MarketLensAuthor author;

  const LensReviewView({required this.review, required this.author});
}

@immutable
class MarketLensView {
  final MarketLens lens;
  final MarketLensAuthor author;
  final bool isFavorited;

  const MarketLensView({
    required this.lens,
    required this.author,
    required this.isFavorited,
  });

  MarketLensView copyWith({
    MarketLens? lens,
    MarketLensAuthor? author,
    bool? isFavorited,
  }) {
    return MarketLensView(
      lens: lens ?? this.lens,
      author: author ?? this.author,
      isFavorited: isFavorited ?? this.isFavorited,
    );
  }
}

@immutable
class MarketLensDetailData {
  final MarketLensView lens;
  final MarketLensVersion? currentVersion;
  final List<MarketLensVersion> versions;
  final List<LensReviewView> reviews;

  const MarketLensDetailData({
    required this.lens,
    required this.currentVersion,
    required this.versions,
    required this.reviews,
  });
}

@immutable
class MarketLensApplyStepOutput {
  final String outputName;
  final String filename;
  final String? url;

  const MarketLensApplyStepOutput({
    required this.outputName,
    required this.filename,
    required this.url,
  });

  factory MarketLensApplyStepOutput.fromJson(Map<String, dynamic> json) {
    return MarketLensApplyStepOutput(
      outputName: json['output_name']?.toString() ?? '',
      filename: json['filename']?.toString() ?? '',
      url: json['url']?.toString(),
    );
  }
}

@immutable
class MarketLensApplyStepResult {
  final String stepId;
  final String lensId;
  final List<Map<String, dynamic>> tweakControls;
  final List<MarketLensApplyStepOutput> outputs;

  const MarketLensApplyStepResult({
    required this.stepId,
    required this.lensId,
    required this.tweakControls,
    required this.outputs,
  });

  factory MarketLensApplyStepResult.fromJson(Map<String, dynamic> json) {
    return MarketLensApplyStepResult(
      stepId: json['step_id']?.toString() ?? '',
      lensId: json['lens_id']?.toString() ?? '',
      tweakControls: (json['tweak_controls'] as List<dynamic>? ?? const [])
          .map(
            (item) => Map<String, dynamic>.from(item as Map<String, dynamic>),
          )
          .toList(),
      outputs: (json['outputs'] as List<dynamic>? ?? const [])
          .map(
            (item) => MarketLensApplyStepOutput.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

@immutable
class MarketLensApplyResult {
  final MarketLens lens;
  final MarketLensVersion version;
  final Map<String, dynamic> musedna;
  final List<String> requiredInputs;
  final bool executed;
  final Map<String, dynamic> executionContext;
  final String? resultFilename;
  final String? resultUrl;
  final String? executionError;
  final bool executionStarted;
  final String? streamId;
  final List<MarketLensApplyStepResult> stepResults;

  const MarketLensApplyResult({
    required this.lens,
    required this.version,
    required this.musedna,
    required this.requiredInputs,
    required this.executed,
    required this.executionContext,
    required this.resultFilename,
    required this.resultUrl,
    required this.executionError,
    required this.executionStarted,
    required this.streamId,
    required this.stepResults,
  });

  factory MarketLensApplyResult.fromJson(Map<String, dynamic> json) {
    return MarketLensApplyResult(
      lens: MarketLens.fromJson(json['template'] as Map<String, dynamic>),
      version: MarketLensVersion.fromJson(
        json['version'] as Map<String, dynamic>,
      ),
      musedna: Map<String, dynamic>.from(
        json['musedna'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      requiredInputs: (json['required_inputs'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      executed: json['executed'] as bool? ?? false,
      executionContext: Map<String, dynamic>.from(
        json['execution_context'] as Map<String, dynamic>? ??
            const <String, dynamic>{},
      ),
      resultFilename: json['result_filename']?.toString(),
      resultUrl: json['result_url']?.toString(),
      executionError: json['execution_error']?.toString(),
      executionStarted: json['execution_started'] as bool? ?? false,
      streamId: json['stream_id']?.toString(),
      stepResults: (json['step_results'] as List<dynamic>? ?? const [])
          .map(
            (item) => MarketLensApplyStepResult.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

@immutable
class ApplyMarketLensInput {
  final int userId;
  final int? versionId;
  final Map<String, String> initialInputs;
  final Map<String, Map<String, dynamic>> paramOverrides;
  final bool executeNow;

  const ApplyMarketLensInput({
    required this.userId,
    required this.versionId,
    required this.initialInputs,
    this.paramOverrides = const <String, Map<String, dynamic>>{},
    this.executeNow = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      if (versionId != null) 'version_id': versionId,
      'initial_inputs': initialInputs,
      'param_overrides': paramOverrides,
      'execute_now': executeNow,
    };
  }
}

double _readDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _readDateTime(dynamic value) {
  final raw = value?.toString();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw);
}
