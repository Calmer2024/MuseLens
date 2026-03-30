import 'package:dio/dio.dart';

import '../../asset_tree_models.dart';
import 'api_client.dart';

class AssetTreeApiService {
  AssetTreeApiService() : _dio = ApiClient().dio;

  final Dio _dio;
  static const String _basePath = '/api/v1/asset-tree';

  Future<AssetTreeProject> createProject(
    CreateAssetTreeProjectInput input,
  ) async {
    final response = await _dio.post(
      '$_basePath/projects',
      data: input.toJson(),
    );
    return AssetTreeProject.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<AssetTreeProject>> listProjects() async {
    final response = await _dio.get('$_basePath/projects');
    return (response.data as List<dynamic>)
        .map((item) => AssetTreeProject.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<AssetTreeProject> getProject(String projectId) async {
    final response = await _dio.get('$_basePath/projects/$projectId');
    return AssetTreeProject.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AssetTreeProject> updateProject({
    required String projectId,
    required UpdateAssetTreeProjectInput input,
  }) async {
    final response = await _dio.patch(
      '$_basePath/projects/$projectId',
      data: input.toJson(),
    );
    return AssetTreeProject.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AssetTreeProject> switchCurrentNode({
    required String projectId,
    required String nodeId,
  }) async {
    final response = await _dio.post(
      '$_basePath/projects/$projectId/current-node',
      data: {'node_id': nodeId},
    );
    return AssetTreeProject.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteProject(String projectId) async {
    await _dio.delete('$_basePath/projects/$projectId');
  }

  Future<AssetTreeProjectTree> getProjectTree(String projectId) async {
    final response = await _dio.get('$_basePath/projects/$projectId/tree');
    return AssetTreeProjectTree.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AssetTreeNode> addRootNode({
    required String projectId,
    required AssetTreeImagePayload input,
  }) async {
    final response = await _dio.post(
      '$_basePath/projects/$projectId/root-node',
      data: input.toJson(),
    );
    return AssetTreeNode.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AssetTreeChildNodeResult> createChildNode({
    required String projectId,
    required CreateAssetTreeChildNodeInput input,
  }) async {
    final response = await _dio.post(
      '$_basePath/projects/$projectId/nodes',
      data: input.toJson(),
    );
    return AssetTreeChildNodeResult.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<AssetTreeNode> getNode(String nodeId) async {
    final response = await _dio.get('$_basePath/nodes/$nodeId');
    return AssetTreeNode.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AssetTreeNode> updateNodeStatus({
    required String nodeId,
    required UpdateAssetTreeNodeStatusInput input,
  }) async {
    final response = await _dio.patch(
      '$_basePath/nodes/$nodeId/status',
      data: input.toJson(),
    );
    return AssetTreeNode.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AssetTreeAncestorPath> getNodeAncestors(String nodeId) async {
    final response = await _dio.get('$_basePath/nodes/$nodeId/ancestors');
    return AssetTreeAncestorPath.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<AssetTreeDescendants> getNodeDescendants(String nodeId) async {
    final response = await _dio.get('$_basePath/nodes/$nodeId/descendants');
    return AssetTreeDescendants.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<void> deleteNode({
    required String nodeId,
    required bool cascade,
  }) async {
    await _dio.delete(
      '$_basePath/nodes/$nodeId',
      queryParameters: {'cascade': cascade},
    );
  }

  Future<AssetTreeNodeCompare> compareNodes({
    required String nodeA,
    required String nodeB,
  }) async {
    final response = await _dio.get(
      '$_basePath/nodes/compare',
      queryParameters: {
        'nodeA': nodeA,
        'nodeB': nodeB,
      },
    );
    return AssetTreeNodeCompare.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<AssetTreeTag> addNodeTag({
    required String nodeId,
    required AddAssetTreeTagInput input,
  }) async {
    final response = await _dio.post(
      '$_basePath/nodes/$nodeId/tags',
      data: input.toJson(),
    );
    return AssetTreeTag.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<AssetTreeTag>> listNodeTags(String nodeId) async {
    final response = await _dio.get('$_basePath/nodes/$nodeId/tags');
    return (response.data as List<dynamic>)
        .map((item) => AssetTreeTag.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteTag(String tagId) async {
    await _dio.delete('$_basePath/tags/$tagId');
  }
}
