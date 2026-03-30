import 'package:flutter/foundation.dart';

import 'user_summary_model.dart';

@immutable
class ChatPeerUser extends UserSummary {
  const ChatPeerUser({
    required super.userId,
    required super.username,
    super.nickname,
    super.avatarUrl,
    super.bio,
    super.isVerified,
  });

  factory ChatPeerUser.fromJson(Map<String, dynamic> json) {
    return ChatPeerUser(
      userId: json['user_id'] as int,
      username: json['username'] as String? ?? '',
      nickname: json['nickname'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }
}

@immutable
class ChatFriend extends ChatPeerUser {
  final int? conversationId;
  final DateTime? lastMessageAt;

  const ChatFriend({
    required super.userId,
    required super.username,
    super.nickname,
    super.avatarUrl,
    super.bio,
    super.isVerified,
    required this.conversationId,
    required this.lastMessageAt,
  });

  factory ChatFriend.fromJson(Map<String, dynamic> json) {
    return ChatFriend(
      userId: json['user_id'] as int,
      username: json['username'] as String? ?? '',
      nickname: json['nickname'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      conversationId: json['conversation_id'] as int?,
      lastMessageAt: _readDateTime(json['last_message_at']),
    );
  }
}

@immutable
class ChatMessageShare {
  final String shareType;
  final String shareSourceType;
  final String resourceId;
  final String title;
  final String summary;
  final String? coverUrl;
  final int? authorId;
  final String? authorName;
  final Map<String, dynamic> metadata;

  const ChatMessageShare({
    required this.shareType,
    required this.shareSourceType,
    required this.resourceId,
    required this.title,
    required this.summary,
    required this.coverUrl,
    required this.authorId,
    required this.authorName,
    required this.metadata,
  });

  factory ChatMessageShare.fromJson(Map<String, dynamic> json) {
    return ChatMessageShare(
      shareType: json['share_type'] as String? ?? '',
      shareSourceType: json['share_source_type'] as String? ?? '',
      resourceId: json['resource_id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      coverUrl: json['cover_url'] as String?,
      authorId: json['author_id'] as int?,
      authorName: json['author_name'] as String?,
      metadata: Map<String, dynamic>.from(
        json['metadata'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

@immutable
class ChatMessage {
  final int messageId;
  final int conversationId;
  final int senderId;
  final String messageType;
  final String content;
  final ChatMessageShare? share;
  final DateTime createdAt;

  const ChatMessage({
    required this.messageId,
    required this.conversationId,
    required this.senderId,
    required this.messageType,
    required this.content,
    required this.share,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      messageId: json['message_id'] as int,
      conversationId: json['conversation_id'] as int,
      senderId: json['sender_id'] as int,
      messageType: json['message_type'] as String? ?? 'text',
      content: json['content'] as String? ?? '',
      share: json['share'] is Map<String, dynamic>
          ? ChatMessageShare.fromJson(json['share'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

@immutable
class ChatMessagePreview {
  final int messageId;
  final int senderId;
  final String messageType;
  final String contentPreview;
  final String? shareType;
  final DateTime createdAt;

  const ChatMessagePreview({
    required this.messageId,
    required this.senderId,
    required this.messageType,
    required this.contentPreview,
    required this.shareType,
    required this.createdAt,
  });

  factory ChatMessagePreview.fromJson(Map<String, dynamic> json) {
    return ChatMessagePreview(
      messageId: json['message_id'] as int,
      senderId: json['sender_id'] as int,
      messageType: json['message_type'] as String? ?? 'text',
      contentPreview: json['content_preview'] as String? ?? '',
      shareType: json['share_type'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

@immutable
class ChatConversation {
  final int conversationId;
  final List<int> participantUserIds;
  final ChatPeerUser peerUser;
  final ChatMessagePreview? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatConversation({
    required this.conversationId,
    required this.participantUserIds,
    required this.peerUser,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      conversationId: json['conversation_id'] as int,
      participantUserIds: (json['participant_user_ids'] as List<dynamic>? ?? const [])
          .map((item) => item as int)
          .toList(),
      peerUser: ChatPeerUser.fromJson(json['peer_user'] as Map<String, dynamic>),
      lastMessage: json['last_message'] is Map<String, dynamic>
          ? ChatMessagePreview.fromJson(
              json['last_message'] as Map<String, dynamic>,
            )
          : null,
      lastMessageAt: _readDateTime(json['last_message_at']),
      unreadCount: json['unread_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

@immutable
class DirectConversationOpenResult {
  final bool created;
  final ChatConversation conversation;

  const DirectConversationOpenResult({
    required this.created,
    required this.conversation,
  });

  factory DirectConversationOpenResult.fromJson(Map<String, dynamic> json) {
    return DirectConversationOpenResult(
      created: json['created'] as bool? ?? false,
      conversation: ChatConversation.fromJson(
        json['conversation'] as Map<String, dynamic>,
      ),
    );
  }
}

@immutable
class ChatMessagePage {
  final int conversationId;
  final List<ChatMessage> messages;
  final bool hasMore;

  const ChatMessagePage({
    required this.conversationId,
    required this.messages,
    required this.hasMore,
  });

  factory ChatMessagePage.fromJson(Map<String, dynamic> json) {
    return ChatMessagePage(
      conversationId: json['conversation_id'] as int,
      messages: (json['messages'] as List<dynamic>? ?? const [])
          .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
          .toList(),
      hasMore: json['has_more'] as bool? ?? false,
    );
  }
}

@immutable
class ChatShareInput {
  final String shareType;
  final int? postId;
  final int? marketLensId;
  final String? assetNodeId;

  const ChatShareInput({
    required this.shareType,
    this.postId,
    this.marketLensId,
    this.assetNodeId,
  });

  Map<String, dynamic> toJson() {
    return {
      'share_type': shareType,
      if (postId != null) 'post_id': postId,
      if (marketLensId != null) 'market_lens_id': marketLensId,
      if (assetNodeId != null && assetNodeId!.trim().isNotEmpty)
        'asset_node_id': assetNodeId!.trim(),
    };
  }
}

@immutable
class ChatComposerShareDraft {
  final ChatShareInput share;
  final String shareSourceType;
  final String resourceId;
  final String title;
  final String summary;
  final String? coverUrl;
  final String? authorName;

  const ChatComposerShareDraft({
    required this.share,
    required this.shareSourceType,
    required this.resourceId,
    required this.title,
    required this.summary,
    required this.coverUrl,
    required this.authorName,
  });

  factory ChatComposerShareDraft.post({
    required int postId,
    required String title,
    required String summary,
    String? coverUrl,
    String? authorName,
  }) {
    return ChatComposerShareDraft(
      share: ChatShareInput(shareType: 'post', postId: postId),
      shareSourceType: 'community_post',
      resourceId: '$postId',
      title: title,
      summary: summary,
      coverUrl: coverUrl,
      authorName: authorName,
    );
  }

  factory ChatComposerShareDraft.marketLens({
    required int lensId,
    required String title,
    required String summary,
    String? coverUrl,
    String? authorName,
  }) {
    return ChatComposerShareDraft(
      share: ChatShareInput(shareType: 'preset', marketLensId: lensId),
      shareSourceType: 'market_lens',
      resourceId: '$lensId',
      title: title,
      summary: summary,
      coverUrl: coverUrl,
      authorName: authorName,
    );
  }

  factory ChatComposerShareDraft.assetNode({
    required String assetNodeId,
    required String title,
    required String summary,
    String? coverUrl,
    String? authorName,
  }) {
    return ChatComposerShareDraft(
      share: ChatShareInput(shareType: 'preset', assetNodeId: assetNodeId),
      shareSourceType: 'asset_node',
      resourceId: assetNodeId,
      title: title,
      summary: summary,
      coverUrl: coverUrl,
      authorName: authorName,
    );
  }
}

DateTime? _readDateTime(dynamic value) {
  final raw = value?.toString();
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw);
}
