import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/asset_tree_models.dart';
import '../models/providers/services/asset_tree_api_service.dart';

final assetTreeApiServiceProvider = Provider<AssetTreeApiService>((ref) {
  return AssetTreeApiService();
});

final assetTreeRepositoryProvider = Provider<AssetTreeRepository>((ref) {
  return AssetTreeRepository(apiService: ref.watch(assetTreeApiServiceProvider));
});

class AssetTreeRepository {
  AssetTreeRepository({required AssetTreeApiService apiService})
    : _apiService = apiService;

  final AssetTreeApiService _apiService;

  Future<AssetTreeProject> createProject(CreateAssetTreeProjectInput input) {
    return _apiService.createProject(input);
  }

  Future<List<AssetTreeProject>> listProjects() {
    return _apiService.listProjects();
  }

  Future<AssetTreeProject> getProject(String projectId) {
    return _apiService.getProject(projectId);
  }

  Future<AssetTreeProject> updateProject({
    required String projectId,
    required UpdateAssetTreeProjectInput input,
  }) {
    return _apiService.updateProject(projectId: projectId, input: input);
  }

  Future<AssetTreeProject> switchCurrentNode({
    required String projectId,
    required String nodeId,
  }) {
    return _apiService.switchCurrentNode(projectId: projectId, nodeId: nodeId);
  }

  Future<void> deleteProject(String projectId) {
    return _apiService.deleteProject(projectId);
  }

  Future<AssetTreeProjectTree> getProjectTree(String projectId) {
    return _apiService.getProjectTree(projectId);
  }

  Future<AssetTreeNode> addRootNode({
    required String projectId,
    required AssetTreeImagePayload input,
  }) {
    return _apiService.addRootNode(projectId: projectId, input: input);
  }

  Future<AssetTreeChildNodeResult> createChildNode({
    required String projectId,
    required CreateAssetTreeChildNodeInput input,
  }) {
    return _apiService.createChildNode(projectId: projectId, input: input);
  }

  Future<AssetTreeNode> getNode(String nodeId) {
    return _apiService.getNode(nodeId);
  }

  Future<AssetTreeNode> updateNodeStatus({
    required String nodeId,
    required UpdateAssetTreeNodeStatusInput input,
  }) {
    return _apiService.updateNodeStatus(nodeId: nodeId, input: input);
  }

  Future<AssetTreeAncestorPath> getNodeAncestors(String nodeId) {
    return _apiService.getNodeAncestors(nodeId);
  }

  Future<AssetTreeDescendants> getNodeDescendants(String nodeId) {
    return _apiService.getNodeDescendants(nodeId);
  }

  Future<void> deleteNode({
    required String nodeId,
    required bool cascade,
  }) {
    return _apiService.deleteNode(nodeId: nodeId, cascade: cascade);
  }

  Future<AssetTreeNodeCompare> compareNodes({
    required String nodeA,
    required String nodeB,
  }) {
    return _apiService.compareNodes(nodeA: nodeA, nodeB: nodeB);
  }

  Future<AssetTreeTag> addNodeTag({
    required String nodeId,
    required AddAssetTreeTagInput input,
  }) {
    return _apiService.addNodeTag(nodeId: nodeId, input: input);
  }

  Future<List<AssetTreeTag>> listNodeTags(String nodeId) {
    return _apiService.listNodeTags(nodeId);
  }

  Future<void> deleteTag(String tagId) {
    return _apiService.deleteTag(tagId);
  }
}
