import 'dart:ui'; // 新增：用于 ImageFilter 模糊效果
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/community_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';
import '../../widgets/community/community_post_card.dart';
import '../../widgets/profile/follow_action_button.dart';
import '../../widgets/shared/adaptive_media.dart';
import '../community/community_post_detail_screen.dart';
import 'followers_list_screen.dart';

class UserDetailScreen extends ConsumerWidget {
  const UserDetailScreen({super.key, required this.userId});

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
      backgroundColor: const Color(0xFFF9F7FF),
      body: Stack(
        children: [
          Positioned(
            top: -120,
            left: -40,
            right: -40,
            child: Container(
              height: 320,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 0.95,
                  colors: [
                    AppTheme.electricIndigo.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          userAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('用户信息加载失败：$error', textAlign: TextAlign.center),
              ),
            ),
            data: (user) {
              final followerCount =
                  followersAsync.value?.length ?? user.followerCount;
              final followingCount =
                  followingAsync.value?.length ?? user.followingCount;
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
                  physics: const ClampingScrollPhysics(),
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      expandedHeight: 250,
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.white, // 改为白色以配合顶部遮罩，让图标更清晰
                      surfaceTintColor: Colors.transparent,
                      // 需求 4: 去掉了 title 属性中的“用户昵称”
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
                        collapseMode: CollapseMode.pin,
                        background: _UserBanner(user: user),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Transform.translate(
                        offset: const Offset(0, -26),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFFF9F7FF),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(30),
                            ),
                          ),
                          // 需求 1: 使用 Stack 重构，让头像突破限制浮在最上面
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  20,
                                  0,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 占位并对齐右侧的关注按钮
                                    SizedBox(
                                      height: 56,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          if (!isMe)
                                            FollowActionButton(
                                              targetUserId: user.userId,
                                              onChanged: () {
                                                ref.invalidate(
                                                  followersProvider(
                                                    user.userId,
                                                  ),
                                                );
                                                ref.invalidate(
                                                  followingProvider(
                                                    user.userId,
                                                  ),
                                                );
                                                ref.invalidate(
                                                  userDetailProvider(
                                                    user.userId,
                                                  ),
                                                );
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            user.nickname?.trim().isNotEmpty ==
                                                    true
                                                ? user.nickname!.trim()
                                                : user.username,
                                            style: const TextStyle(
                                              fontSize: 26,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                        if (user.isVerified) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: AppTheme.electricIndigo
                                                  .withValues(alpha: 0.12),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.verified_rounded,
                                              size: 16,
                                              color: AppTheme.electricIndigo,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '@${user.username}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.black.withValues(
                                          alpha: 0.48,
                                        ),
                                      ),
                                    ),
                                    if (user.bio != null &&
                                        user.bio!.trim().isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        user.bio!.trim(),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.65,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 14),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        if (user.memberLevel != 'free')
                                          _ProfileChip(
                                            label: user.memberLevel
                                                .toUpperCase(),
                                          ),
                                        const _ProfileChip(label: '共创者'),
                                      ],
                                    ),
                                    const SizedBox(height: 22),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 18,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color: AppTheme.electricIndigo
                                              .withValues(alpha: 0.08),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.04,
                                            ),
                                            blurRadius: 18,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
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
                                                  builder: (_) =>
                                                      FollowersListScreen(
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
                                                  builder: (_) =>
                                                      FollowersListScreen(
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
                                    const SizedBox(height: 26),
                                    Row(
                                      children: [
                                        const Text(
                                          'TA的帖子',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.electricIndigo
                                                .withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            '${postsAsync.asData?.value.length ?? 0}',
                                            style: const TextStyle(
                                              color: AppTheme.electricIndigo,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    // 需求 3: 移除了原本这里高度为 16 的 SizedBox，或者将其改得极小
                                    const SizedBox(height: 4),
                                  ],
                                ),
                              ),
                              // 独立定位的头像，层级最高，位置不受容器裁剪影响
                              Positioned(
                                top: -38, // 将头像向上移动，脱离背景区域
                                left: 20,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 4,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.electricIndigo
                                            .withValues(alpha: 0.18),
                                        blurRadius: 24,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 42,
                                    backgroundColor: Colors.grey.shade200,
                                    backgroundImage:
                                        resolveAdaptiveImageProvider(
                                          user.avatarUrl,
                                        ),
                                    child:
                                        user.avatarUrl == null ||
                                            user.avatarUrl!.trim().isEmpty
                                        ? const Icon(
                                            Icons.person,
                                            size: 34,
                                            color: Colors.black38,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 52,
                                  horizontal: 20,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: AppTheme.electricIndigo.withValues(
                                      alpha: 0.06,
                                    ),
                                  ),
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
                              padding: EdgeInsets.zero, // 需求 3: 清除自带间距
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
                                        builder: (_) =>
                                            CommunityPostDetailScreen(
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
        ],
      ),
    );
  }
}

class _UserBanner extends StatelessWidget {
  const _UserBanner({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Stack(
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
                  Color(0xFF9385FF),
                  Color(0xFFE7E0FF),
                ],
              ),
            ),
          ),
        // 原有底部暗色渐变（保留）
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.04),
                Colors.black.withValues(alpha: 0.26),
              ],
            ),
          ),
        ),
        // 需求 2: 顶部模糊遮罩（结合 ShaderMask 实现平滑过渡的毛玻璃）
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 120,
          child: ShaderMask(
            shaderCallback: (bounds) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black, Colors.transparent],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
        ),
        // 需求 2: 为顶部文字（例如返回、分享按钮及状态栏）提供额外的深色渐变底，确保可见度
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 120,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppTheme.electricIndigo.withValues(alpha: 0.16),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.electricIndigo,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _UserStat extends StatelessWidget {
  const _UserStat({required this.value, required this.label, this.onTap});

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
              fontSize: 18,
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
