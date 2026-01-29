import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';

// 引入之前定义的数据模型和详情页
import '../../../data/models/lens_template_mock.dart';
import '../community/community_screen.dart'; // 包含 CommunityPostMock
import '../lens/lens_detail_screen.dart'; // Lens 详情页
import '../community/post_detail_screen.dart'; // 帖子详情页

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // 当前选中的 Tab 索引: 0=My Lens, 1=My Post, 2=Favorite
  int _currentTab = 0;

  // 模拟数据源
  late List<LensTemplateMock> _myLenses;
  late List<CommunityPostMock> _myPosts;
  late List<CommunityPostMock> _favorites;

  @override
  void initState() {
    super.initState();
    // 1. 获取 My Lens 数据
    _myLenses = LensTemplateMock.getTemplates();

    // 2. 获取 My Post 数据 (取前5个作为模拟)
    _myPosts = CommunityPostMock.getPosts().take(5).toList();

    // 3. 获取 Favorite 数据 (取后5个作为模拟)
    _favorites = CommunityPostMock.getPosts().skip(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), // 哑光黑背景
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

                  // --- 1. Header (Title & Settings) ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 40), // 占位
                      const Text(
                        "Profile",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: const Icon(
                          Icons.settings_outlined,
                          color: AppTheme.electricIndigo,
                          size: 20,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // --- 2. User Info ---
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.electricIndigo.withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: -5,
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppTheme.electricIndigo, Color(0xFF8E2DE2)],
                        ),
                      ),
                      child: const CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.black,
                        backgroundImage: AssetImage(
                          "assets/images/profile.jpg",
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    "Calmer",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "@Calmer_makes_art",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "AI art enthusiast & style explorer.",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- 3. Edit Profile Button ---
                  Container(
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
                    child: const Center(
                      child: Text(
                        "Edit Profile",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- 4. Stats Row ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatItem("12", "Lens"),
                      _buildStatItem("85", "Posts"),
                      _buildStatItem("4.5k", "Likes"),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // --- 5. Tabs (Updated) ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTabButton(0, "My Lens"),
                      _buildTabButton(1, "My Post"),
                      _buildTabButton(2, "Favorite"),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // --- 6. Content Grid (Dynamic) ---
                  _buildContentGrid(),

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

  // --- 逻辑组件 ---

  // 构建 Tab 按钮
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
              color: isActive ? Colors.white : Colors.white.withOpacity(0.5),
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

  // 根据当前 Tab 构建网格内容
  Widget _buildContentGrid() {
    if (_currentTab == 0) {
      // --- Tab 1: My Lens ---
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7, // Lens 卡片通常是竖长的
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _myLenses.length,
        itemBuilder: (context, index) {
          return _buildLensCard(_myLenses[index]);
        },
      );
    } else if (_currentTab == 1) {
      // --- Tab 2: My Post ---
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75, // 帖子卡片比例
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _myPosts.length,
        itemBuilder: (context, index) {
          return _buildPostCard(_myPosts[index]);
        },
      );
    } else {
      // --- Tab 3: Favorite ---
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

  // 构建 Lens 卡片 (样式一)
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
          color: const Color(0xFF1E1E1E),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: _buildSmartImage(lens.afterImage), // 展示效果图
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
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${lens.usageCount} uses",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
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

  // 构建 Post 卡片 (样式二)
  Widget _buildPostCard(CommunityPostMock post) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PostDetailScreen(post: post)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF1E1E1E),
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
                  color: Colors.white,
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

  // 辅助方法：统计块
  Widget _buildStatItem(String count, String label) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Dark Charcoal
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // 辅助方法：智能图片加载
  Widget _buildSmartImage(String path) {
    if (path.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: path,
        fit: BoxFit.cover,
        width: double.infinity,
        placeholder: (context, url) =>
            Container(color: const Color(0xFF2C2C2C)),
        errorWidget: (context, url, error) =>
            Container(color: Colors.grey[850]),
      );
    } else {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) =>
            Container(color: Colors.grey[850]),
      );
    }
  }
}
