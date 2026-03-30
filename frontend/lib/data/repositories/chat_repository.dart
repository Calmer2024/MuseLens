import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_models.dart';
import '../models/providers/services/chat_api_service.dart';

final chatApiServiceProvider = Provider<ChatApiService>((ref) {
  return ChatApiService();
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(apiService: ref.watch(chatApiServiceProvider));
});

class ChatRepository {
  ChatRepository({required ChatApiService apiService}) : _apiService = apiService;

  final ChatApiService _apiService;

  Future<List<ChatFriend>> listFriends(int userId) {
    return _apiService.listFriends(userId);
  }

  Future<DirectConversationOpenResult> openDirectConversation({
    required int userId,
    required int friendUserId,
  }) {
    return _apiService.openDirectConversation(
      userId: userId,
      friendUserId: friendUserId,
    );
  }

  Future<List<ChatConversation>> listConversations(int userId) {
    return _apiService.listConversations(userId);
  }

  Future<ChatConversation> getConversationDetail({
    required int conversationId,
    required int userId,
  }) {
    return _apiService.getConversationDetail(
      conversationId: conversationId,
      userId: userId,
    );
  }

  Future<ChatMessagePage> listMessages({
    required int conversationId,
    required int userId,
    int limit = 50,
    int? beforeMessageId,
  }) {
    return _apiService.listMessages(
      conversationId: conversationId,
      userId: userId,
      limit: limit,
      beforeMessageId: beforeMessageId,
    );
  }

  Future<ChatMessage> sendMessage({
    required int conversationId,
    required int senderId,
    required String content,
    ChatShareInput? share,
  }) {
    return _apiService.sendMessage(
      conversationId: conversationId,
      senderId: senderId,
      content: content,
      share: share,
    );
  }

  Future<void> markConversationRead({
    required int conversationId,
    required int userId,
    int? lastReadMessageId,
  }) {
    return _apiService.markConversationRead(
      conversationId: conversationId,
      userId: userId,
      lastReadMessageId: lastReadMessageId,
    );
  }
}
