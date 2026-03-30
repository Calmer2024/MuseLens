import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/chat_models.dart';
import '../../data/repositories/chat_repository.dart';
import 'auth_provider.dart';

final chatFriendsProvider = FutureProvider<List<ChatFriend>>((ref) async {
  final currentUser = ref.watch(authProvider);
  if (currentUser == null) {
    return const [];
  }

  final repository = ref.watch(chatRepositoryProvider);
  return repository.listFriends(currentUser.userId);
});

final chatConversationsProvider =
    FutureProvider<List<ChatConversation>>((ref) async {
  final currentUser = ref.watch(authProvider);
  if (currentUser == null) {
    return const [];
  }

  final repository = ref.watch(chatRepositoryProvider);
  return repository.listConversations(currentUser.userId);
});

final chatConversationDetailProvider =
    FutureProvider.family<ChatConversation, int>((ref, conversationId) async {
  final currentUser = ref.watch(authProvider);
  if (currentUser == null) {
    throw StateError('未登录');
  }

  final repository = ref.watch(chatRepositoryProvider);
  return repository.getConversationDetail(
    conversationId: conversationId,
    userId: currentUser.userId,
  );
});
