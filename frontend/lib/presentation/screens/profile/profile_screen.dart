import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/community_provider.dart';
import '../../../core/providers/market_provider.dart';
import '../../../data/models/user_model.dart';

import '../../../data/models/community_models.dart';
import '../../../data/models/market_models.dart';
import '../community/community_post_detail_screen.dart';
import '../lens/market_lens_detail_screen.dart';
import '../library/my_library_screen.dart';
import '../../widgets/community/community_post_card.dart';
import '../../widgets/lens/market_lens_visuals.dart';
import '../../widgets/shared/adaptive_media.dart';
import '../../../core/providers/user_provider.dart';

// 新页面
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import 'edit_profile_screen.dart';
import 'followers_list_screen.dart';
import 'user_detail_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // 当前选中的 Tab 索引: 0=My Lens, 1=My Post, 2=Favorite
  int _currentTab = 0;

  void _openLoginScreen() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  Future<void> _openEditProfile() async {
    final currentUser = ref.read(authProvider);
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const EditProfileScreen()));
    if (currentUser != null) {
      ref.invalidate(userDetailProvider(currentUser.userId));
    }
  }

  void _openFollowersList(int userId, bool isFollowers) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            FollowersListScreen(userId: userId, isFollowers: isFollowers),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(context.tr('logout')),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              '取消',
              style: TextStyle(color: Colors.black.withOpacity(0.5)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              '确定',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final isLoggedIn = user != null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 背景微光
          Positioned(
            top: -100,
            left: 0,
            right: 0,
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 0.8,
                  colors: [
                    AppTheme.electricIndigo.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 30), // 保留适度留白
                  // --- User Info ---
                  if (isLoggedIn)
                    _buildLoggedInProfile(user)
                  else
                    _buildGuestProfile(),

                  // 底部留白
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // 已登录态
  // ═══════════════════════════════════════════════
  Widget _buildLoggedInProfile(User user) {
    final liveUserAsync = ref.watch(userDetailProvider(user.userId));
    final followersAsync = ref.watch(followersProvider(user.userId));
    final followingAsync = ref.watch(followingProvider(user.userId));
    final liveUser = liveUserAsync.value ?? user;
    final followerCount = followersAsync.value?.length ?? liveUser.followerCount;
    final followingCount = followingAsync.value?.length ?? liveUser.followingCount;

    return Column(
      children: [
        // 头像与背景 Banner 组合
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // Banner 横幅
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.grey.shade100,
                image: liveUser.bannerUrl != null && liveUser.bannerUrl!.isNotEmpty
                    ? DecorationImage(
                        image: _getImageProvider(liveUser.bannerUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: liveUser.bannerUrl == null || liveUser.bannerUrl!.isEmpty
                  ? Icon(
                      Icons.image_outlined,
                      size: 40,
                      color: Colors.black.withOpacity(0.1),
                    )
                  : null,
            ),

            // 头像
            Positioned(
              bottom: -40,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.electricIndigo.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white, // 白边框
                  ),
                  child: CircleAvatar(
                    radius: 46,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage:
                        liveUser.avatarUrl != null && liveUser.avatarUrl!.isNotEmpty
                        ? _getImageProvider(liveUser.avatarUrl!)
                        : const AssetImage('assets/images/profile.png'),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 56), // 为悬浮的头像留出空间

        Text(
          liveUser.nickname ?? liveUser.username,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '@${liveUser.username}',
          style: TextStyle(fontSize: 14, color: Colors.black.withOpacity(0.5)),
        ),
        if (liveUser.bio != null && liveUser.bio!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            liveUser.bio!,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],

        // 会员等级标签
        if (liveUser.memberLevel != 'free') ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              liveUser.memberLevel.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Stats Row (位于按钮上方)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatItem(
              '${liveUser.totalLikes}',
              context.tr('likes'),
              onTap: null,
            ),
            _buildStatItem(
              '$followerCount',
              context.tr('followers'),
              onTap: () => _openFollowersList(liveUser.userId, true),
            ),
            _buildStatItem(
              '$followingCount',
              context.tr('following'),
              onTap: () => _openFollowersList(liveUser.userId, false),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // 编辑资料与退出登录按钮行（编辑居中，退出靠右，纯灰色icon）
        Stack(
          alignment: Alignment.center,
          children: [
            // 主按钮：居中的编辑资料按钮
            Container(
              width: double.infinity,
              alignment: Alignment.center,
              child: GestureDetector(
                onTap: _openEditProfile,
                child: Container(
                  width: 120, // 缩小尺寸
                  height: 36, // 缩小尺寸
                  decoration: BoxDecoration(
                    color: Colors.black, // 黑色背景
                    borderRadius: BorderRadius.circular(6), // 微小的圆角
                  ),
                  child: Center(
                    child: Text(
                      context.tr('edit_profile'),
                      style: const TextStyle(
                        color: Colors.white, // 白色文字
                        fontWeight: FontWeight.w500,
                        fontSize: 14, // 略微缩小字体
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 次按钮：位于最右侧的灰色退出Icon（无背景圆形）
            Positioned(
              right: 0,
              child: IconButton(
                onPressed: _handleLogout,
                padding: EdgeInsets.zero, // 减少点击区域的边距
                constraints: const BoxConstraints(), // 移除默认的最小尺寸限制
                icon: const Icon(
                  Icons.logout_rounded,
                  color: Colors.black54, // 灰色Icon
                  size: 20, // 略微调整尺寸
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 30),

        _buildMarketSummary(),

        const SizedBox(height: 30),

        // Tabs
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildTabButton(0, context.tr('my_lens')),
            _buildTabButton(1, context.tr('my_post')),
            _buildTabButton(2, context.tr('favorite')),
          ],
        ),

        const SizedBox(height: 20),

        // Content Grid
        _buildContentGrid(),
      ],
    );
  }

  // ═══════════════════════════════════════════════
  // 访客态（未登录）
  // ═══════════════════════════════════════════════
  Widget _buildGuestProfile() {
    return Column(
      children: [
        const SizedBox(height: 20),

        // 默认头像
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                spreadRadius: -5,
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey.shade100,
            child: Icon(
              Icons.person_rounded,
              size: 56,
              color: Colors.grey.shade400,
            ),
          ),
        ),

        const SizedBox(height: 16),

        Text(
          context.tr('guest_user'),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          context.tr('login_prompt'),
          style: TextStyle(fontSize: 14, color: Colors.black.withOpacity(0.5)),
        ),

        const SizedBox(height: 32),

        // 登录按钮
        GestureDetector(
              onTap: _openLoginScreen,
              child: Container(
                width: 220,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: const LinearGradient(
                    colors: [AppTheme.electricIndigo, Color(0xFF584CF4)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.electricIndigo.withOpacity(0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.login_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      context.tr('login_button'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .animate()
            .fade(duration: 500.ms)
            .scale(
              begin: const Offset(0.95, 0.95),
              end: const Offset(1, 1),
              duration: 500.ms,
              curve: Curves.easeOutBack,
            ),

        const SizedBox(height: 16),

        // 注册链接
        GestureDetector(
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const RegisterScreen()));
          },
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 14,
                color: Colors.black.withOpacity(0.5),
              ),
              children: [
                TextSpan(text: context.tr('no_account')),
                const TextSpan(text: ' '),
                TextSpan(
                  text: context.tr('register'),
                  style: const TextStyle(
                    color: AppTheme.electricIndigo,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 50),

        // Stats Row (全部为 0)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatItem('0', context.tr('likes'), onTap: null),
            _buildStatItem('0', context.tr('followers'), onTap: null),
            _buildStatItem('0', context.tr('following'), onTap: null),
          ],
        ),

        const SizedBox(height: 30),

        // Tabs (禁用状态)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildTabButton(0, context.tr('my_lens')),
            _buildTabButton(1, context.tr('my_post')),
            _buildTabButton(2, context.tr('favorite')),
          ],
        ),

        const SizedBox(height: 40),

        // 空内容提示
        Column(
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 56,
              color: Colors.black.withOpacity(0.12),
            ),
            const SizedBox(height: 12),
            Text(
              context.tr('login_to_view'),
              style: TextStyle(
                fontSize: 14,
                color: Colors.black.withOpacity(0.35),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════
  // 公共组件
  // ═══════════════════════════════════════════════

  Widget _buildMarketSummary() {
    final installedAsync = ref.watch(marketInstalledLensesProvider);
    final favoriteAsync = ref.watch(marketFavoriteLensesProvider);
    final authoredAsync = ref.watch(marketAuthoredLensesProvider);

    final installedCount = installedAsync.value?.length ?? 0;
    final favoriteCount = favoriteAsync.value?.length ?? 0;
    final authoredCount = authoredAsync.value?.length ?? 0;
    final isLoading =
        installedAsync.isLoading ||
        favoriteAsync.isLoading ||
        authoredAsync.isLoading;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '我的透镜',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MyLibraryScreen()),
                  );
                },
                child: const Text('查看全部'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Row(
              children: [
                Expanded(child: _buildMarketMetric('已安装', installedCount)),
                const SizedBox(width: 10),
                Expanded(child: _buildMarketMetric('已收藏', favoriteCount)),
                const SizedBox(width: 10),
                Expanded(child: _buildMarketMetric('已发布', authoredCount)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMarketMetric(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.electricIndigo.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.black.withOpacity(0.54),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label) {
    final bool isActive = _currentTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentTab = index;
        });
      },
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.black87 : Colors.black.withOpacity(0.5),
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 3,
            width: isActive ? 40 : 0,
            decoration: BoxDecoration(
              color: AppTheme.electricIndigo,
              borderRadius: BorderRadius.circular(2),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppTheme.electricIndigo.withOpacity(0.6),
                        blurRadius: 8,
                      ),
                    ]
                  : [],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentGrid() {
    final user = ref.watch(authProvider);
    if (_currentTab == 0) {
      final authoredLensesAsync = ref.watch(marketAuthoredLensesProvider);
      return authoredLensesAsync.when(
        data: (lenses) => _buildLensGrid(lenses),
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => _buildGridError('透镜加载失败：$error'),
      );
    }

    if (user == null) {
      return const SizedBox.shrink();
    }

    if (_currentTab == 1) {
      final postsAsync = ref.watch(
        communityPostsProvider(
          CommunityPostQuery(userId: user.userId, onlyPublic: false),
        ),
      );
      return postsAsync.when(
        data: (posts) => _buildPostGrid(posts, emptyText: '你还没有发布过帖子'),
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => _buildGridError('帖子加载失败：$error'),
      );
    }

    final favoritesAsync = ref.watch(communityFavoritePostsProvider);
    return favoritesAsync.when(
      data: (posts) => _buildPostGrid(posts, emptyText: '你还没有收藏任何帖子'),
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => _buildGridError('收藏加载失败：$error'),
    );
  }

  Widget _buildPostGrid(
    List<CommunityPostView> posts, {
    required String emptyText,
  }) {
    if (posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: Text(
            emptyText,
            style: TextStyle(
              color: Colors.black.withOpacity(0.38),
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return MasonryGridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return CommunityPostCard(
          post: post,
          onAuthorTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserDetailScreen(userId: post.author.userId),
              ),
            );
          },
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    CommunityPostDetailScreen(postId: post.post.postId),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGridError(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black.withOpacity(0.38), fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildLensGrid(List<MarketLensView> lenses) {
    if (lenses.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: Text(
            '你还没有发布过透镜',
            style: TextStyle(
              color: Colors.black.withOpacity(0.38),
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: lenses.length,
      itemBuilder: (context, index) {
        return _buildLensCard(lenses[index]);
      },
    );
  }

  Widget _buildLensCard(MarketLensView lens) {
    final visual = MarketLensVisualResolver.resolve(lens.lens);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                MarketLensDetailScreen(lensId: lens.lens.lensId),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          border: Border.all(color: Colors.black.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Image.asset(visual.afterImage, fit: BoxFit.cover),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lens.lens.name,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${lens.lens.installCount} ${context.tr('uses')}',
                    style: const TextStyle(color: Colors.black54, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String count, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.black.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  ImageProvider _getImageProvider(String path) {
    return resolveAdaptiveImageProvider(path) ??
        const AssetImage('assets/images/profile.png');
  }
}
