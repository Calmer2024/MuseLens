import 'package:dio/dio.dart';

import '../../chat_models.dart';
import 'api_client.dart';

class ChatApiService {
  final Dio _dio = ApiClient().dio;
  static const String _basePath = '/api/v1/chat';

  Future<List<ChatFriend>> listFriends(int userId) async {
    final response = await _dio.get('$_basePath/friends/$userId');
    return (response.data as List<dynamic>)
        .map((item) => ChatFriend.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<DirectConversationOpenResult> openDirectConversation({
    required int userId,
    required int friendUserId,
  }) async {
    final response = await _dio.post(
      '$_basePath/conversations/direct',
      data: {
        'user_id': userId,
        'friend_user_id': friendUserId,
      },
    );
    return DirectConversationOpenResult.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<List<ChatConversation>> listConversations(int userId) async {
    final response = await _dio.get(
      '$_basePath/conversations',
      queryParameters: {'user_id': userId},
    );
    return (response.data as List<dynamic>)
        .map((item) => ChatConversation.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ChatConversation> getConversationDetail({
    required int conversationId,
    required int userId,
  }) async {
    final response = await _dio.get(
      '$_basePath/conversations/$conversationId',
      queryParameters: {'user_id': userId},
    );
    return ChatConversation.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ChatMessagePage> listMessages({
    required int conversationId,
    required int userId,
    int limit = 50,
    int? beforeMessageId,
  }) async {
    final response = await _dio.get(
      '$_basePath/conversations/$conversationId/messages',
      queryParameters: {
        'user_id': userId,
        'limit': limit,
        if (beforeMessageId != null) 'before_message_id': beforeMessageId,
      },
    );
    return ChatMessagePage.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ChatMessage> sendMessage({
    required int conversationId,
    required int senderId,
    required String content,
    ChatShareInput? share,
  }) async {
    final response = await _dio.post(
      '$_basePath/conversations/$conversationId/messages',
      data: {
        'sender_id': senderId,
        'content': content,
        if (share != null) 'share': share.toJson(),
      },
    );
    return ChatMessage.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> markConversationRead({
    required int conversationId,
    required int userId,
    int? lastReadMessageId,
  }) async {
    await _dio.post(
      '$_basePath/conversations/$conversationId/read',
      data: {
        'user_id': userId,
        if (lastReadMessageId != null) 'last_read_message_id': lastReadMessageId,
      },
    );
  }
}
