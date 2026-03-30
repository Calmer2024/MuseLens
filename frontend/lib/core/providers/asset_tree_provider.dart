import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/asset_tree_models.dart';
import '../../data/repositories/asset_tree_repository.dart';

final assetTreeProjectsProvider = FutureProvider<List<AssetTreeProject>>((
  ref,
) async {
  return ref.watch(assetTreeRepositoryProvider).listProjects();
});

final assetTreeProjectDetailProvider =
    FutureProvider.family<AssetTreeProject, String>((ref, projectId) async {
      return ref.watch(assetTreeRepositoryProvider).getProject(projectId);
    });

final assetTreeProjectTreeProvider =
    FutureProvider.family<AssetTreeProjectTree, String>((ref, projectId) async {
      return ref.watch(assetTreeRepositoryProvider).getProjectTree(projectId);
    });

final assetTreeNodeDetailProvider =
    FutureProvider.family<AssetTreeNode, String>((ref, nodeId) async {
      return ref.watch(assetTreeRepositoryProvider).getNode(nodeId);
    });

final assetTreeNodeAncestorsProvider =
    FutureProvider.family<AssetTreeAncestorPath, String>((ref, nodeId) async {
      return ref.watch(assetTreeRepositoryProvider).getNodeAncestors(nodeId);
    });

final assetTreeNodeDescendantsProvider =
    FutureProvider.family<AssetTreeDescendants, String>((ref, nodeId) async {
      return ref.watch(assetTreeRepositoryProvider).getNodeDescendants(nodeId);
    });

final assetTreeNodeTagsProvider =
    FutureProvider.family<List<AssetTreeTag>, String>((ref, nodeId) async {
      return ref.watch(assetTreeRepositoryProvider).listNodeTags(nodeId);
    });

final assetTreeNodeCompareProvider = FutureProvider.family<
  AssetTreeNodeCompare,
  ({String nodeA, String nodeB})
>((ref, query) async {
  return ref.watch(assetTreeRepositoryProvider).compareNodes(
    nodeA: query.nodeA,
    nodeB: query.nodeB,
  );
});
