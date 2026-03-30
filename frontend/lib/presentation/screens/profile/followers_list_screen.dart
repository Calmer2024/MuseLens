import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_summary_model.dart';
import '../../widgets/profile/follow_action_button.dart';
import '../../widgets/shared/adaptive_media.dart';

class FollowersListScreen extends ConsumerStatefulWidget {
  final int userId;
  final bool isFollowers; // true = 粉丝列表, false = 关注列表

  const FollowersListScreen({
    super.key,
    required this.userId,
    required this.isFollowers,
  });

  @override
  ConsumerState<FollowersListScreen> createState() =>
      _FollowersListScreenState();
}

class _FollowersListScreenState extends ConsumerState<FollowersListScreen> {
  @override
  Widget build(BuildContext context) {
    final listAsync = widget.isFollowers
        ? ref.watch(followersProvider(widget.userId))
        : ref.watch(followingProvider(widget.userId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Colors.black87, size: 20),
        ),
        title: Text(
          widget.isFollowers
              ? context.tr('followers')
              : context.tr('following'),
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: listAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: AppTheme.electricIndigo,
            strokeWidth: 2.5,
          ),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 48, color: Colors.black.withOpacity(0.3)),
              const SizedBox(height: 12),
              Text(
                '加载失败',
                style: TextStyle(
                  color: Colors.black.withOpacity(0.5),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  if (widget.isFollowers) {
                    ref.invalidate(followersProvider(widget.userId));
                  } else {
                    ref.invalidate(followingProvider(widget.userId));
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.electricIndigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '重试',
                    style: TextStyle(
                      color: AppTheme.electricIndigo,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        data: (users) {
          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.isFollowers
                        ? Icons.people_outline_rounded
                        : Icons.person_add_alt_rounded,
                    size: 64,
                    color: Colors.black.withOpacity(0.15),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.isFollowers ? '暂无粉丝' : '暂未关注任何人',
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.4),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            itemCount: users.length,
            separatorBuilder: (_, __) => Divider(
              color: Colors.black.withOpacity(0.05),
              height: 1,
            ),
            itemBuilder: (context, index) {
              return _buildUserTile(users[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildUserTile(UserSummary user) {
    final currentUser = ref.watch(authProvider);
    final isMe = currentUser?.userId == user.userId;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // 头像
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.electricIndigo.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: ClipOval(
              child: _buildAvatar(user.avatarUrl),
            ),
          ),
          const SizedBox(width: 14),

          // 用户名和昵称
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.nickname ?? user.username,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${user.username}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black.withOpacity(0.45),
                  ),
                ),
              ],
            ),
          ),

          // 关注/取关按钮（不显示自己）
          if (!isMe && currentUser != null)
            FollowActionButton(
              targetUserId: user.userId,
              compact: true,
              onChanged: () {
                ref.invalidate(followersProvider(widget.userId));
                ref.invalidate(followingProvider(widget.userId));
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return CircleAvatar(
        backgroundColor: Colors.grey.shade200,
        child: Icon(Icons.person_rounded, color: Colors.grey.shade400),
      );
    }
    
    return buildAdaptiveImage(
      avatarUrl,
      fit: BoxFit.cover,
      errorWidget: Icon(
        Icons.person_rounded,
        color: Colors.grey.shade400,
      ),
    );
  }
}

