import 'package:flutter/material.dart';
import 'dart:ui'; // 用于 ImageFilter
import '../../../core/theme/app_theme.dart';
import '../../../core/navigation/slide_right_route.dart';
import 'post_detail_screen.dart'; // 引入帖子详情页
import 'chat_detail_screen.dart'; // 引入对话详情页
import 'search_screen.dart'; // 引入搜索页
import '../../../core/localization/app_localizations.dart';

// --- 1. 模拟数据模型 (已更新支持多图和本地资源) ---
class CommunityPostMock {
  final String imageUrl; // 封面图
  final List<String> galleryImages; // 🔥 新增：画廊多图列表
  final String description;
  final String authorName;
  final String authorAvatar;
  final int likeCount;
  final int commentCount;
  final double aspectRatio;

  CommunityPostMock({
    required this.imageUrl,
    this.galleryImages = const [], // 默认为空
    required this.description,
    required this.authorName,
    required this.authorAvatar,
    required this.likeCount,
    required this.commentCount,
    this.aspectRatio = 1.0,
  });

  static List<CommunityPostMock> getPosts() {
    return [
      // 1. Cyberpunk (使用本地资源)
      CommunityPostMock(
        imageUrl: "assets/images/community/N1.png", // 封面
        galleryImages: [
          "assets/images/community/N1.png",
          "assets/images/community/N2.png",
          "assets/images/community/N3.png",
        ],
        description: "用了最新的 Neon Tokyo V2 滤镜，光影效果太绝了！仿佛穿越到了2077年。🌃✨",
        authorName: "赛博少女",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Felix",
        likeCount: 128,
        commentCount: 45,
        aspectRatio: 1.0,
      ),
      // 2. Ghibli Nature (使用本地资源)
      CommunityPostMock(
        imageUrl: "assets/images/community/G1.png", // 封面
        galleryImages: [
          "assets/images/community/G1.png",
          "assets/images/community/G2.png",
          "assets/images/community/G3.png",
        ],
        description: "把后院拍出了宫崎骏电影的感觉，太治愈了。🍃",
        authorName: "旅行家杰克",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Jack",
        likeCount: 892,
        commentCount: 120,
        aspectRatio: 1.0,
      ),
      // 3. Film Noir (网络图)
      CommunityPostMock(
        imageUrl: "https://picsum.photos/seed/post3/600/900",
        galleryImages: ["https://picsum.photos/seed/post3/600/900"],
        description: "经典永不过时。Film Noir 模板简直是街拍神器，黑白质感满分。",
        authorName: "复古控",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Bella",
        likeCount: 2300,
        commentCount: 342,
        aspectRatio: 1.5,
      ),
      // 4. Street Snap
      CommunityPostMock(
        imageUrl: "https://picsum.photos/seed/post4/600/700",
        galleryImages: ["https://picsum.photos/seed/post4/600/700"],
        description: "黄金时刻抓拍的一瞬间。没有后期，原图直出，MuseLens 的色彩科学很强。",
        authorName: "街头摄影师",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Max",
        likeCount: 45,
        commentCount: 8,
        aspectRatio: 1.1,
      ),
      // 5. Portrait
      CommunityPostMock(
        imageUrl: "https://picsum.photos/seed/post5/800/600",
        galleryImages: ["https://picsum.photos/seed/post5/800/600"],
        description: "分享一下 Soft Glamour 滤镜的参数设置，链接在主页！需要的自取~ 💄",
        authorName: "美妆Queen",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Luna",
        likeCount: 567,
        commentCount: 99,
        aspectRatio: 0.8,
      ),
      // 6. Food
      CommunityPostMock(
        imageUrl: "https://picsum.photos/seed/food1/600/600",
        galleryImages: ["https://picsum.photos/seed/food1/600/600"],
        description: "深夜放毒。这碗拉面加上 Michelin Star 滤镜，看着也太有食欲了吧！🍜",
        authorName: "吃货小汤姆",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Tom",
        likeCount: 320,
        commentCount: 24,
        aspectRatio: 1.0,
      ),
      // 7. Cat
      CommunityPostMock(
        imageUrl: "https://picsum.photos/seed/cat1/600/800",
        galleryImages: ["https://picsum.photos/seed/cat1/600/800"],
        description: "哈哈，我把我家猫变成了皮克斯主角！眼神太到位了 😂 #PixarPet",
        authorName: "猫奴99号",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Kitty",
        likeCount: 4500,
        commentCount: 600,
        aspectRatio: 1.2,
      ),
      // 8. Abstract Art
      CommunityPostMock(
        imageUrl: "https://picsum.photos/seed/art1/700/900",
        galleryImages: ["https://picsum.photos/seed/art1/700/900"],
        description: "正在测试抽象艺术风格转换。大家觉得这幅画怎么样？",
        authorName: "数字艺术家",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Art",
        likeCount: 88,
        commentCount: 12,
        aspectRatio: 1.4,
      ),
      // 9. Architecture
      CommunityPostMock(
        imageUrl: "https://picsum.photos/seed/arch1/800/600",
        galleryImages: ["https://picsum.photos/seed/arch1/800/600"],
        description: "现代线条遇上极简镜头。删繁就简，建筑之美。",
        authorName: "每日建筑",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Arch",
        likeCount: 150,
        commentCount: 5,
        aspectRatio: 0.75,
      ),
      // 10. Mountain
      CommunityPostMock(
        imageUrl: "https://picsum.photos/seed/mountain1/600/750",
        galleryImages: ["https://picsum.photos/seed/mountain1/600/750"],
        description: "Alien Vista 滤镜让这座山看起来像外星基地。🪐 下次徒步还要带上它。",
        authorName: "徒步的大卫",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Dave",
        likeCount: 2100,
        commentCount: 150,
        aspectRatio: 1.25,
      ),
    ];
  }
}

// --- 2. 主界面 ---
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  int _currentTab = 0;
  late TabController _tabController;

  final List<CommunityPostMock> _posts = CommunityPostMock.getPosts();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTab = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // --- 1. Header ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildIconButton(Icons.tune, context.tr('filter'), onTap: () {}),
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.black.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTabItem(0, context.tr('discover')),
                        _buildTabItem(1, context.tr('messages')),
                      ],
                    ),
                  ),
                  _buildIconButton(
                    Icons.search,
                    context.tr('search'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SearchScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // --- 2. Content ---
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: [_buildDiscoverView(), _buildMessagesView()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建发现页 (瀑布流)
  Widget _buildDiscoverView() {
    final leftColumn = <CommunityPostMock>[];
    final rightColumn = <CommunityPostMock>[];

    for (var i = 0; i < _posts.length; i++) {
      if (i % 2 == 0) {
        leftColumn.add(_posts[i]);
      } else {
        rightColumn.add(_posts[i]);
      }
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: leftColumn
                  .map((post) => CommunityPostCard(post: post))
                  .toList(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: rightColumn
                  .map((post) => CommunityPostCard(post: post))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  // 构建消息页
  Widget _buildMessagesView() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
      children: [
        _buildMessageItem(
          "MuseLens 官方小助手",
          "🎉 恭喜！您的作品入选了本周精选推荐。",
          "assets/images/logo.png",
          "上午 10:00",
          isOfficial: true,
          isLocalImage: true,
        ),
        _buildMessageItem(
          "Tim",
          "那个赛博朋克的参数可以发我一份吗？我也想试试。",
          "https://api.dicebear.com/7.x/avataaars/png?seed=Cher",
          "昨天",
        ),
        _buildMessageItem(
          "设计大师",
          "你的构图很有意思，互关一下？",
          "https://api.dicebear.com/7.x/avataaars/png?seed=Design",
          "周一",
        ),
        _buildMessageItem(
          "像素画师",
          "嘿，你要参加下周的创意挑战赛吗？",
          "https://api.dicebear.com/7.x/avataaars/png?seed=Pixel",
          "周日",
        ),
      ],
    );
  }

  Widget _buildIconButton(
    IconData icon,
    String tooltip, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.black.withOpacity(0.1),
          ),
        ),
        child: Icon(
          icon, 
          color: Colors.black87,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, String label) {
    final bool isActive = _currentTab == index;
    return GestureDetector(
      onTap: () {
        _tabController.animateTo(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.electricIndigo : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive 
                ? Colors.white 
                : Colors.black.withOpacity(0.5),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageItem(
    String name,
    String message,
    String avatar,
    String time, {
    bool isOfficial = false,
    bool isLocalImage = false,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ChatDetailScreen(userName: name, avatarUrl: avatar),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.black.withOpacity(0.05),
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[200],
                  child: ClipOval(
                    child: isLocalImage
                        ? Image.asset(
                            avatar,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) =>
                                const Icon(Icons.person, color: Colors.grey),
                          )
                        : Image.network(
                            avatar,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            headers: const {'User-Agent': 'Mozilla/5.0'},
                            errorBuilder: (c, e, s) =>
                                const Icon(Icons.person, color: Colors.grey),
                          ),
                  ),
                ),
                if (isOfficial)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: AppTheme.background,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified,
                        color: AppTheme.electricIndigo,
                        size: 14,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        time,
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.4),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.6),
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 3. 社区帖子卡片组件 (CommunityPostCard) ---
class CommunityPostCard extends StatelessWidget {
  final CommunityPostMock post;

  const CommunityPostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          SlideRightRoute(page: PostDetailScreen(post: post)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面图片
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: AspectRatio(
                aspectRatio: 1 / post.aspectRatio,
                child: _buildSmartImage(post.imageUrl),
              ),
            ),
            // 内容
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.9),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 9,
                              backgroundColor: Colors.grey[200],
                              child: ClipOval(
                                child: _buildSmartImage(
                                  post.authorAvatar,
                                  isAvatar: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                post.authorName,
                                style: TextStyle(
                                  color: Colors.black.withOpacity(0.6),
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.electricIndigo.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.electricIndigo.withOpacity(0.3),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.favorite,
                              size: 12,
                              color: AppTheme.electricIndigo,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatCount(post.likeCount),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              width: 1,
                              height: 8,
                              color: AppTheme.electricIndigo.withOpacity(0.5),
                            ),
                            const Icon(
                              Icons.chat_bubble_outline,
                              size: 12,
                              color: AppTheme.electricIndigo,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatCount(post.commentCount),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count > 1000) {
      return "${(count / 1000).toStringAsFixed(1)}k";
    }
    return count.toString();
  }

  // 🔥 核心：智能加载方法 (支持本地 Asset 和 网络 URL)
  Widget _buildSmartImage(String path, {bool isAvatar = false}) {
    if (path.startsWith('http')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        width: isAvatar ? 18 : null,
        height: isAvatar ? 18 : null,
        headers: const {'User-Agent': 'Mozilla/5.0'},
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[200],
          child: isAvatar
              ? const Icon(Icons.person, size: 10, color: Colors.grey)
              : null,
        ),
      );
    } else {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        width: isAvatar ? 18 : null,
        height: isAvatar ? 18 : null,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[200],
          child: isAvatar
              ? const Icon(Icons.person, size: 10, color: Colors.grey)
              : const Center(
                  child: Icon(Icons.broken_image, color: Colors.black12),
                ),
        ),
      );
    }
  }
}
