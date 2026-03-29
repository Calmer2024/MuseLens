import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../data/models/user_model.dart';

// 引入之前定义的数据模型和详情页
import '../../../data/models/lens_template_mock.dart';
import '../community/community_screen.dart'; // 包含 CommunityPostMock
import '../lens/lens_detail_screen.dart'; // Lens 详情页
import '../community/post_detail_screen.dart'; // 帖子详情页

// 新页面
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import 'edit_profile_screen.dart';
import 'followers_list_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // 当前选中的 Tab 索引: 0=My Lens, 1=My Post, 2=Favorite
  int _currentTab = 0;

  // 模拟数据源
  late List<LensTemplateMock> _myLenses;
  late List<CommunityPostMock> _myPosts;
  late List<CommunityPostMock> _favorites;

  @override
  void initState() {
    super.initState();
    _myLenses = LensTemplateMock.getTemplates();
    _myPosts = CommunityPostMock.getPosts().take(5).toList();
    _favorites = CommunityPostMock.getPosts().skip(5).toList();
  }

  void _openLoginScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _openEditProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
  }

  void _openFollowersList(int userId, bool isFollowers) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FollowersListScreen(
          userId: userId,
          isFollowers: isFollowers,
        ),
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
                  const SizedBox(height: 10),

                  // --- 1. Header ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 40),
                      Text(
                        context.tr('profile'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          letterSpacing: 0.5,
                        ),
                      ),
                      // 退出登录按钮（仅已登录时显示）
                      if (isLoggedIn)
                        IconButton(
                          onPressed: _handleLogout,
                          icon: Icon(
                            Icons.logout_rounded,
                            color: Colors.black.withOpacity(0.4),
                            size: 22,
                          ),
                        )
                      else
                        const SizedBox(width: 40),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // --- 2. User Info ---
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
                image: user.bannerUrl != null && user.bannerUrl!.isNotEmpty
                    ? DecorationImage(
                        image: _getImageProvider(user.bannerUrl!),
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
              child: user.bannerUrl == null || user.bannerUrl!.isEmpty
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
                    backgroundImage: user.avatarUrl != null &&
                            user.avatarUrl!.isNotEmpty
                        ? _getImageProvider(user.avatarUrl!)
                        : const AssetImage('assets/images/profile.jpg'),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 56), // 为悬浮的头像留出空间

        Text(
          user.nickname ?? user.username,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '@${user.username}',
          style: TextStyle(
            fontSize: 14,
            color: Colors.black.withOpacity(0.5),
          ),
        ),
        if (user.bio != null && user.bio!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            user.bio!,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],

        // 会员等级标签
        if (user.memberLevel != 'free') ...[
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
              user.memberLevel.toUpperCase(),
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

        // 编辑资料按钮
        GestureDetector(
          onTap: _openEditProfile,
          child: Container(
            width: 200,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [AppTheme.electricIndigo, Color(0xFF584CF4)],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.electricIndigo.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Text(
                context.tr('edit_profile'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 30),

        // Stats Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatItem(
              '${user.totalLikes}',
              context.tr('likes'),
              onTap: null,
            ),
            _buildStatItem(
              '${user.followerCount}',
              context.tr('followers'),
              onTap: () => _openFollowersList(user.userId, true),
            ),
            _buildStatItem(
              '${user.followingCount}',
              context.tr('following'),
              onTap: () => _openFollowersList(user.userId, false),
            ),
          ],
        ),

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
          style: TextStyle(
            fontSize: 14,
            color: Colors.black.withOpacity(0.5),
          ),
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
                const Icon(Icons.login_rounded, color: Colors.white, size: 20),
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
        ).animate().fade(duration: 500.ms).scale(
              begin: const Offset(0.95, 0.95),
              end: const Offset(1, 1),
              duration: 500.ms,
              curve: Curves.easeOutBack,
            ),

        const SizedBox(height: 16),

        // 注册链接
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const RegisterScreen(),
              ),
            );
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
              color: isActive
                  ? Colors.black87
                  : Colors.black.withOpacity(0.5),
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
    if (_currentTab == 0) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _myLenses.length,
        itemBuilder: (context, index) {
          return _buildLensCard(_myLenses[index]);
        },
      );
    } else if (_currentTab == 1) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _myPosts.length,
        itemBuilder: (context, index) {
          return _buildPostCard(_myPosts[index]);
        },
      );
    } else {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _favorites.length,
        itemBuilder: (context, index) {
          return _buildPostCard(_favorites[index]);
        },
      );
    }
  }

  Widget _buildLensCard(LensTemplateMock lens) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LensDetailScreen(template: lens),
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
                child: _buildSmartImage(lens.afterImage),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lens.title,
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
                    '${lens.usageCount} ${context.tr('uses')}',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(CommunityPostMock post) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => PostDetailScreen(post: post)),
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
                child: _buildSmartImage(post.imageUrl),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Text(
                post.description,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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

  Widget _buildSmartImage(String path) {
    if (path.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: path,
        fit: BoxFit.cover,
        width: double.infinity,
        placeholder: (context, url) =>
            Container(color: Colors.grey[200]),
        errorWidget: (context, url, error) =>
            Container(color: Colors.grey[200]),
      );
    } else if (path.startsWith('file://')) {
      return Image.file(
        File(path.substring(7)),
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) =>
            Container(color: Colors.grey[200]),
      );
    } else {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) =>
            Container(color: Colors.grey[200]),
      );
    }
  }

  ImageProvider _getImageProvider(String path) {
    if (path.startsWith('http')) {
      return CachedNetworkImageProvider(path);
    } else if (path.startsWith('file://')) {
      return FileImage(File(path.substring(7)));
    } else if (path.startsWith('/')) {
      return FileImage(File(path));
    } else {
      return AssetImage(path);
    }
  }
}
