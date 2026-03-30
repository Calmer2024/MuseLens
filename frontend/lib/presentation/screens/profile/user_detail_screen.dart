import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/community_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/community/community_post_card.dart';
import '../../widgets/profile/follow_action_button.dart';
import '../../widgets/shared/adaptive_media.dart';
import '../community/community_post_detail_screen.dart';
import 'followers_list_screen.dart';

class UserDetailScreen extends ConsumerWidget {
  const UserDetailScreen({
    super.key,
    required this.userId,
  });

  final int userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userDetailProvider(userId));
    final postsAsync = ref.watch(
      communityPostsProvider(CommunityPostQuery(userId: userId)),
    );
    final followersAsync = ref.watch(followersProvider(userId));
    final followingAsync = ref.watch(followingProvider(userId));
    final currentUser = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6FF),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '用户信息加载失败：$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (user) {
          final followerCount = followersAsync.value?.length ?? user.followerCount;
          final followingCount = followingAsync.value?.length ?? user.followingCount;
          final isMe = currentUser?.userId == user.userId;

          return RefreshIndicator(
            color: AppTheme.electricIndigo,
            onRefresh: () async {
              ref.invalidate(userDetailProvider(userId));
              ref.invalidate(followersProvider(userId));
              ref.invalidate(followingProvider(userId));
              ref.invalidate(
                communityPostsProvider(CommunityPostQuery(userId: userId)),
              );
              await ref.read(userDetailProvider(userId).future);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 220,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  actions: [
                    IconButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('分享功能稍后开放')),
                        );
                      },
                      icon: const Icon(Icons.share_outlined),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (user.bannerUrl != null && user.bannerUrl!.trim().isNotEmpty)
                          buildAdaptiveImage(
                            user.bannerUrl,
                            fit: BoxFit.cover,
                            errorWidget: Container(color: const Color(0xFFECE7FF)),
                          )
                        else
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF6E5BFF),
                                  Color(0xFF9C8CFF),
                                  Color(0xFFE9E2FF),
                                ],
                              ),
                            ),
                          ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.06),
                                Colors.black.withValues(alpha: 0.28),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Transform.translate(
                    offset: const Offset(0, -34),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.electricIndigo.withValues(alpha: 0.20),
                                      blurRadius: 24,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 42,
                                  backgroundColor: Colors.grey.shade200,
                                  backgroundImage: resolveAdaptiveImageProvider(user.avatarUrl),
                                  child: user.avatarUrl == null || user.avatarUrl!.trim().isEmpty
                                      ? const Icon(Icons.person, size: 36, color: Colors.black38)
                                      : null,
                                ),
                              ),
                              const Spacer(),
                              if (!isMe)
                                FollowActionButton(
                                  targetUserId: user.userId,
                                  onChanged: () {
                                    ref.invalidate(followersProvider(user.userId));
                                    ref.invalidate(followingProvider(user.userId));
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              user.nickname?.trim().isNotEmpty == true
                                  ? user.nickname!.trim()
                                  : user.username,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '@${user.username}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black.withValues(alpha: 0.48),
                              ),
                            ),
                          ),
                          if (user.bio != null && user.bio!.trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                user.bio!.trim(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.electricIndigo.withValues(alpha: 0.10),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _UserStat(
                                  value: '${user.totalLikes}',
                                  label: context.tr('likes'),
                                ),
                                _UserStat(
                                  value: '$followerCount',
                                  label: context.tr('followers'),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => FollowersListScreen(
                                          userId: user.userId,
                                          isFollowers: true,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                _UserStat(
                                  value: '$followingCount',
                                  label: context.tr('following'),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => FollowersListScreen(
                                          userId: user.userId,
                                          isFollowers: false,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppTheme.electricIndigo.withValues(alpha: 0.08),
                              ),
                            ),
                            child: const Text(
                              'TA的帖子',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
                  sliver: SliverToBoxAdapter(
                    child: postsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, _) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: Text('帖子加载失败：$error')),
                      ),
                      data: (posts) {
                        if (posts.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '还没有公开帖子',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.black.withValues(alpha: 0.40),
                                fontSize: 14,
                              ),
                            ),
                          );
                        }

                        return MasonryGridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          itemCount: posts.length,
                          itemBuilder: (context, index) {
                            final post = posts[index];
                            return CommunityPostCard(
                              post: post,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CommunityPostDetailScreen(
                                      postId: post.post.postId,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _UserStat extends StatelessWidget {
  const _UserStat({
    required this.value,
    required this.label,
    this.onTap,
  });

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black.withValues(alpha: 0.48),
            ),
          ),
        ],
      ),
    );
  }
}
