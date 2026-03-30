import 'package:flutter/foundation.dart';

@immutable
class AssetTreeTag {
  const AssetTreeTag({
    required this.tagId,
    required this.nodeId,
    required this.label,
    required this.color,
    required this.createdAt,
  });

  final String tagId;
  final String nodeId;
  final String label;
  final String color;
  final DateTime createdAt;

  factory AssetTreeTag.fromJson(Map<String, dynamic> json) {
    return AssetTreeTag(
      tagId: json['tag_id']?.toString() ?? '',
      nodeId: json['node_id']?.toString() ?? '',
      label: json['label'] as String? ?? '',
      color: json['color'] as String? ?? '#4A90E2',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

@immutable
class AssetTreeProject {
  const AssetTreeProject({
    required this.projectId,
    required this.name,
    required this.description,
    required this.coverUrl,
    required this.rootNodeId,
    required this.currentNodeId,
    required this.nodeCount,
    required this.branchCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String projectId;
  final String name;
  final String description;
  final String? coverUrl;
  final String? rootNodeId;
  final String? currentNodeId;
  final int nodeCount;
  final int branchCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AssetTreeProject.fromJson(Map<String, dynamic> json) {
    return AssetTreeProject(
      projectId: json['project_id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      coverUrl: json['cover_url'] as String?,
      rootNodeId: json['root_node_id']?.toString(),
      currentNodeId: json['current_node_id']?.toString(),
      nodeCount: json['node_count'] as int? ?? 0,
      branchCount: json['branch_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  String get displayName {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '未命名项目' : trimmed;
  }
}

@immutable
class AssetTreeNodeSummary {
  const AssetTreeNodeSummary({
    required this.nodeId,
    required this.imageUrl,
    required this.thumbnailUrl,
    required this.nodeType,
    required this.depth,
    required this.status,
    required this.label,
    required this.tags,
    required this.createdAt,
  });

  final String nodeId;
  final String imageUrl;
  final String? thumbnailUrl;
  final String nodeType;
  final int depth;
  final String status;
  final String? label;
  final List<AssetTreeTag> tags;
  final DateTime createdAt;

  factory AssetTreeNodeSummary.fromJson(Map<String, dynamic> json) {
    return AssetTreeNodeSummary(
      nodeId: json['node_id']?.toString() ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String?,
      nodeType: json['node_type'] as String? ?? 'generated',
      depth: json['depth'] as int? ?? 0,
      status: json['status'] as String? ?? 'completed',
      label: json['label'] as String?,
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((item) => AssetTreeTag.fromJson(item as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String? get previewUrl {
    final thumbnail = thumbnailUrl?.trim();
    if (thumbnail != null && thumbnail.isNotEmpty) {
      return thumbnail;
    }
    final image = imageUrl.trim();
    if (image.isNotEmpty) {
      return image;
    }
    return null;
  }

  String get displayLabel {
    final trimmed = label?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    if (tags.isNotEmpty) {
      final tagLabel = tags.first.label.trim();
      if (tagLabel.isNotEmpty) {
        return tagLabel;
      }
    }
    if (nodeType == 'original') {
      return '原图';
    }
    if (status == 'generating') {
      return '生成中';
    }
    return '版本 ${nodeId.substring(0, nodeId.length >= 6 ? 6 : nodeId.length)}';
  }
}

@immutable
class AssetTreeNode extends AssetTreeNodeSummary {
  const AssetTreeNode({
    required super.nodeId,
    required this.projectId,
    required super.imageUrl,
    required super.thumbnailUrl,
    required super.nodeType,
    required this.width,
    required this.height,
    required this.fileSize,
    required this.format,
    required this.museDna,
    required this.generationParams,
    required super.depth,
    required this.path,
    required super.status,
    required super.label,
    required this.metadata,
    required super.tags,
    required super.createdAt,
  });

  final String projectId;
  final int? width;
  final int? height;
  final int? fileSize;
  final String? format;
  final Map<String, dynamic>? museDna;
  final Map<String, dynamic>? generationParams;
  final List<String> path;
  final Map<String, dynamic>? metadata;

  factory AssetTreeNode.fromJson(Map<String, dynamic> json) {
    return AssetTreeNode(
      nodeId: json['node_id']?.toString() ?? '',
      projectId: json['project_id']?.toString() ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String?,
      nodeType: json['node_type'] as String? ?? 'generated',
      width: json['width'] as int?,
      height: json['height'] as int?,
      fileSize: json['file_size'] as int?,
      format: json['format'] as String?,
      museDna: _mapOrNull(json['muse_dna']),
      generationParams: _mapOrNull(json['generation_params']),
      depth: json['depth'] as int? ?? 0,
      path: (json['path'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      status: json['status'] as String? ?? 'completed',
      label: json['label'] as String?,
      metadata: _mapOrNull(json['metadata']),
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((item) => AssetTreeTag.fromJson(item as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isOriginal => nodeType == 'original';
  bool get isGenerating => status == 'generating';
  bool get isFailed => status == 'failed';
}

@immutable
class AssetTreeEdgeSummary {
  const AssetTreeEdgeSummary({
    required this.edgeId,
    required this.sourceNodeId,
    required this.targetNodeId,
    required this.lensId,
    required this.lensName,
    required this.userPrompt,
    required this.parameters,
    required this.executionTimeMs,
    required this.createdAt,
  });

  final String edgeId;
  final String sourceNodeId;
  final String targetNodeId;
  final String? lensId;
  final String? lensName;
  final String? userPrompt;
  final Map<String, dynamic>? parameters;
  final int? executionTimeMs;
  final DateTime createdAt;

  factory AssetTreeEdgeSummary.fromJson(Map<String, dynamic> json) {
    return AssetTreeEdgeSummary(
      edgeId: json['edge_id']?.toString() ?? '',
      sourceNodeId: json['source_node_id']?.toString() ?? '',
      targetNodeId: json['target_node_id']?.toString() ?? '',
      lensId: json['lens_id'] as String?,
      lensName: json['lens_name'] as String?,
      userPrompt: json['user_prompt'] as String?,
      parameters: _mapOrNull(json['parameters']),
      executionTimeMs: json['execution_time_ms'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get displayName {
    final lens = lensName?.trim();
    if (lens != null && lens.isNotEmpty) {
      return lens;
    }
    final prompt = userPrompt?.trim();
    if (prompt != null && prompt.isNotEmpty) {
      return prompt;
    }
    return '生成步骤';
  }
}

@immutable
class AssetTreeEdge extends AssetTreeEdgeSummary {
  const AssetTreeEdge({
    required super.edgeId,
    required this.projectId,
    required super.sourceNodeId,
    required super.targetNodeId,
    required super.lensId,
    required super.lensName,
    required super.userPrompt,
    required super.parameters,
    required this.museDna,
    required super.executionTimeMs,
    required this.taskId,
    required super.createdAt,
  });

  final String projectId;
  final Map<String, dynamic>? museDna;
  final String? taskId;

  factory AssetTreeEdge.fromJson(Map<String, dynamic> json) {
    return AssetTreeEdge(
      edgeId: json['edge_id']?.toString() ?? '',
      projectId: json['project_id']?.toString() ?? '',
      sourceNodeId: json['source_node_id']?.toString() ?? '',
      targetNodeId: json['target_node_id']?.toString() ?? '',
      lensId: json['lens_id'] as String?,
      lensName: json['lens_name'] as String?,
      userPrompt: json['user_prompt'] as String?,
      parameters: _mapOrNull(json['parameters']),
      museDna: _mapOrNull(json['muse_dna']),
      executionTimeMs: json['execution_time_ms'] as int?,
      taskId: json['task_id']?.toString(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

@immutable
class AssetTreeProjectTree {
  const AssetTreeProjectTree({
    required this.project,
    required this.nodes,
    required this.edges,
  });

  final AssetTreeProject project;
  final List<AssetTreeNodeSummary> nodes;
  final List<AssetTreeEdgeSummary> edges;

  factory AssetTreeProjectTree.fromJson(Map<String, dynamic> json) {
    return AssetTreeProjectTree(
      project: AssetTreeProject.fromJson(json['project'] as Map<String, dynamic>),
      nodes: (json['nodes'] as List<dynamic>? ?? const [])
          .map(
            (item) => AssetTreeNodeSummary.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
      edges: (json['edges'] as List<dynamic>? ?? const [])
          .map(
            (item) => AssetTreeEdgeSummary.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }

  Map<String, AssetTreeNodeSummary> get nodeMap {
    return {
      for (final node in nodes) node.nodeId: node,
    };
  }

  List<AssetTreeNodeSummary> childrenOf(String nodeId) {
    final childIds = edges
        .where((edge) => edge.sourceNodeId == nodeId)
        .map((edge) => edge.targetNodeId)
        .toSet();
    return nodes.where((node) => childIds.contains(node.nodeId)).toList();
  }

  AssetTreeEdgeSummary? edgeTo(String targetNodeId) {
    for (final edge in edges) {
      if (edge.targetNodeId == targetNodeId) {
        return edge;
      }
    }
    return null;
  }
}

@immutable
class AssetTreeAncestorPath {
  const AssetTreeAncestorPath({
    required this.nodeId,
    required this.ancestors,
    required this.pathEdges,
  });

  final String nodeId;
  final List<AssetTreeNodeSummary> ancestors;
  final List<AssetTreeEdgeSummary> pathEdges;

  factory AssetTreeAncestorPath.fromJson(Map<String, dynamic> json) {
    return AssetTreeAncestorPath(
      nodeId: json['node_id']?.toString() ?? '',
      ancestors: (json['ancestors'] as List<dynamic>? ?? const [])
          .map(
            (item) => AssetTreeNodeSummary.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
      pathEdges: (json['path_edges'] as List<dynamic>? ?? const [])
          .map(
            (item) => AssetTreeEdgeSummary.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

@immutable
class AssetTreeDescendants {
  const AssetTreeDescendants({
    required this.nodeId,
    required this.descendants,
  });

  final String nodeId;
  final List<AssetTreeNodeSummary> descendants;

  factory AssetTreeDescendants.fromJson(Map<String, dynamic> json) {
    return AssetTreeDescendants(
      nodeId: json['node_id']?.toString() ?? '',
      descendants: (json['descendants'] as List<dynamic>? ?? const [])
          .map(
            (item) => AssetTreeNodeSummary.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

@immutable
class AssetTreeNodeCompare {
  const AssetTreeNodeCompare({
    required this.nodeA,
    required this.nodeB,
    required this.edge,
  });

  final AssetTreeNode nodeA;
  final AssetTreeNode nodeB;
  final AssetTreeEdgeSummary? edge;

  factory AssetTreeNodeCompare.fromJson(Map<String, dynamic> json) {
    return AssetTreeNodeCompare(
      nodeA: AssetTreeNode.fromJson(json['node_a'] as Map<String, dynamic>),
      nodeB: AssetTreeNode.fromJson(json['node_b'] as Map<String, dynamic>),
      edge: json['edge'] is Map<String, dynamic>
          ? AssetTreeEdgeSummary.fromJson(json['edge'] as Map<String, dynamic>)
          : null,
    );
  }
}

@immutable
class AssetTreeChildNodeResult {
  const AssetTreeChildNodeResult({
    required this.node,
    required this.edge,
  });

  final AssetTreeNode node;
  final AssetTreeEdge edge;

  factory AssetTreeChildNodeResult.fromJson(Map<String, dynamic> json) {
    return AssetTreeChildNodeResult(
      node: AssetTreeNode.fromJson(json['node'] as Map<String, dynamic>),
      edge: AssetTreeEdge.fromJson(json['edge'] as Map<String, dynamic>),
    );
  }
}

@immutable
class CreateAssetTreeProjectInput {
  const CreateAssetTreeProjectInput({
    required this.name,
    this.description = '',
  });

  final String name;
  final String description;

  Map<String, dynamic> toJson() {
    return {
      'name': name.trim(),
      'description': description.trim(),
    };
  }
}

@immutable
class UpdateAssetTreeProjectInput {
  const UpdateAssetTreeProjectInput({
    this.name,
    this.description,
    this.coverUrl,
  });

  final String? name;
  final String? description;
  final String? coverUrl;

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name!.trim(),
      if (description != null) 'description': description!.trim(),
      if (coverUrl != null) 'cover_url': coverUrl!.trim(),
    };
  }
}

@immutable
class AssetTreeImagePayload {
  const AssetTreeImagePayload({
    required this.imageUrl,
    this.thumbnailUrl,
    this.width,
    this.height,
    this.fileSize,
    this.format,
    this.metadata,
  });

  final String imageUrl;
  final String? thumbnailUrl;
  final int? width;
  final int? height;
  final int? fileSize;
  final String? format;
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toJson() {
    return {
      'image_url': imageUrl,
      if (thumbnailUrl != null && thumbnailUrl!.trim().isNotEmpty)
        'thumbnail_url': thumbnailUrl!.trim(),
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (fileSize != null) 'file_size': fileSize,
      if (format != null && format!.trim().isNotEmpty) 'format': format!.trim(),
      if (metadata != null) 'metadata': metadata,
    };
  }
}

@immutable
class CreateAssetTreeChildNodeInput extends AssetTreeImagePayload {
  const CreateAssetTreeChildNodeInput({
    required this.parentNodeId,
    required super.imageUrl,
    super.thumbnailUrl,
    super.width,
    super.height,
    super.fileSize,
    super.format,
    this.lensId,
    this.lensName,
    this.userPrompt,
    this.parameters,
    this.museDna,
    this.generationParams,
    this.executionTimeMs,
    this.taskId,
    this.status = 'completed',
    super.metadata,
  });

  final String parentNodeId;
  final String? lensId;
  final String? lensName;
  final String? userPrompt;
  final Map<String, dynamic>? parameters;
  final Map<String, dynamic>? museDna;
  final Map<String, dynamic>? generationParams;
  final int? executionTimeMs;
  final String? taskId;
  final String status;

  @override
  Map<String, dynamic> toJson() {
    return {
      'parent_node_id': parentNodeId,
      ...super.toJson(),
      if (lensId != null && lensId!.trim().isNotEmpty) 'lens_id': lensId!.trim(),
      if (lensName != null && lensName!.trim().isNotEmpty)
        'lens_name': lensName!.trim(),
      if (userPrompt != null && userPrompt!.trim().isNotEmpty)
        'user_prompt': userPrompt!.trim(),
      if (parameters != null) 'parameters': parameters,
      if (museDna != null) 'muse_dna': museDna,
      if (generationParams != null) 'generation_params': generationParams,
      if (executionTimeMs != null) 'execution_time_ms': executionTimeMs,
      if (taskId != null && taskId!.trim().isNotEmpty) 'task_id': taskId!.trim(),
      'status': status,
    };
  }
}

@immutable
class UpdateAssetTreeNodeStatusInput {
  const UpdateAssetTreeNodeStatusInput({
    required this.status,
    this.imageUrl,
    this.thumbnailUrl,
    this.executionTimeMs,
  });

  final String status;
  final String? imageUrl;
  final String? thumbnailUrl;
  final int? executionTimeMs;

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      if (imageUrl != null && imageUrl!.trim().isNotEmpty)
        'image_url': imageUrl!.trim(),
      if (thumbnailUrl != null && thumbnailUrl!.trim().isNotEmpty)
        'thumbnail_url': thumbnailUrl!.trim(),
      if (executionTimeMs != null) 'execution_time_ms': executionTimeMs,
    };
  }
}

@immutable
class AddAssetTreeTagInput {
  const AddAssetTreeTagInput({
    required this.label,
    this.color = '#4A90E2',
  });

  final String label;
  final String color;

  Map<String, dynamic> toJson() {
    return {
      'label': label.trim(),
      'color': color.trim(),
    };
  }
}

Map<String, dynamic>? _mapOrNull(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}
