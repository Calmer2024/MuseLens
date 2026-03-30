import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_model.dart';
import '../../data/models/user_summary_model.dart';
import 'auth_provider.dart';

/// 获取指定用户详情
final userDetailProvider =
    FutureProvider.family<User, int>((ref, userId) async {
  final apiService = ref.watch(userApiServiceProvider);
  return apiService.getUserById(userId);
});

/// 获取指定用户的粉丝列表
final followersProvider =
    FutureProvider.family<List<UserSummary>, int>((ref, userId) async {
  final apiService = ref.watch(userApiServiceProvider);
  return apiService.getFollowers(userId);
});

/// 获取指定用户的关注列表
final followingProvider =
    FutureProvider.family<List<UserSummary>, int>((ref, userId) async {
  final apiService = ref.watch(userApiServiceProvider);
  return apiService.getFollowing(userId);
});

final userIsFollowingProvider =
    FutureProvider.family<bool, int>((ref, targetUserId) async {
  final currentUser = ref.watch(authProvider);
  if (currentUser == null || currentUser.userId == targetUserId) {
    return false;
  }

  final following = await ref.watch(followingProvider(currentUser.userId).future);
  return following.any((user) => user.userId == targetUserId);
});
