import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/chat_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/chat_models.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../widgets/shared/adaptive_media.dart';
import '../auth/login_screen.dart';
import 'chat_detail_screen.dart';

class ChatFriendPickerScreen extends ConsumerWidget {
  const ChatFriendPickerScreen({
    super.key,
    this.shareDraft,
  });

  final ChatComposerShareDraft? shareDraft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authProvider);
    final friendsAsync = ref.watch(chatFriendsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        title: Text(shareDraft == null ? '发起聊天' : '选择好友'),
      ),
      body: currentUser == null
          ? _LoginRequired(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            )
          : friendsAsync.when(
              data: (friends) {
                if (friends.isEmpty) {
                  return const _EmptyFriends();
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                  itemCount: friends.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    return _FriendListTile(
                      friend: friend,
                      onTap: () => _openConversation(
                        context,
                        ref,
                        currentUser.userId,
                        friend,
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '好友列表加载失败：$error',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _openConversation(
    BuildContext context,
    WidgetRef ref,
    int userId,
    ChatFriend friend,
  ) async {
    try {
      final conversationId = friend.conversationId ??
          (await ref.read(chatRepositoryProvider).openDirectConversation(
                userId: userId,
                friendUserId: friend.userId,
              ))
              .conversation
              .conversationId;
      ref.invalidate(chatConversationsProvider);
      ref.invalidate(chatFriendsProvider);
      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            conversationId: conversationId,
            initialShareDraft: shareDraft,
          ),
        ),
      );
    } catch (error) {
      String message = '无法打开会话，请稍后重试';
      if (error is DioException) {
        final data = error.response?.data;
        if (data is Map<String, dynamic> && data['detail'] != null) {
          message = data['detail'].toString();
        } else if (error.message != null) {
          message = error.message!;
        }
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
}

class _FriendListTile extends StatelessWidget {
  const _FriendListTile({
    required this.friend,
    required this.onTap,
  });

  final ChatFriend friend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.grey.shade100,
                backgroundImage: resolveAdaptiveImageProvider(friend.avatarUrl),
                child: friend.avatarUrl == null || friend.avatarUrl!.trim().isEmpty
                    ? const Icon(Icons.person, color: Colors.black38)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            friend.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (friend.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: AppTheme.electricIndigo,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${friend.username}',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.45),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.electricIndigo.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  friend.conversationId == null ? '开始聊天' : '进入会话',
                  style: const TextStyle(
                    color: AppTheme.electricIndigo,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginRequired extends StatelessWidget {
  const _LoginRequired({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 50,
              color: Colors.black.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 14),
            Text(
              '登录后才能使用好友聊天',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.64),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.electricIndigo,
                foregroundColor: Colors.white,
              ),
              child: const Text('去登录'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFriends extends StatelessWidget {
  const _EmptyFriends();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 54,
              color: Colors.black.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 14),
            const Text(
              '还没有可私聊的好友',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '只有互相关注的用户，才会出现在这里。',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.46),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
