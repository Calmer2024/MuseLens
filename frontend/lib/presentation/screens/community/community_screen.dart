import 'package:flutter/material.dart';
import 'dart:ui'; // 用于 ImageFilter
import '../../../core/theme/app_theme.dart';
import 'post_detail_screen.dart'; // 引入详情页

// --- 1. 模拟数据模型 (扩充至10条 - 中文内容) ---
class CommunityPostMock {
  final String imageUrl;
  final String description;
  final String authorName;
  final String authorAvatar;
  final int likeCount;
  final int commentCount;
  final double aspectRatio;

  CommunityPostMock({
    required this.imageUrl,
    required this.description,
    required this.authorName,
    required this.authorAvatar,
    required this.likeCount,
    required this.commentCount,
    this.aspectRatio = 1.0,
  });

  static List<CommunityPostMock> getPosts() {
    return [
      // 1. Cyberpunk
      CommunityPostMock(
        imageUrl: "https://picsum.photos/seed/post1/600/800",
        description: "用了最新的 Neon Tokyo V2 滤镜，光影效果太绝了！仿佛穿越到了2077年。🌃✨",
        authorName: "赛博少女",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Felix",
        likeCount: 128,
        commentCount: 45,
        aspectRatio: 1.3,
      ),
      // 2. Ghibli Nature
      CommunityPostMock(
        imageUrl: "https://picsum.photos/seed/post2/600/600",
        description: "把后院拍出了宫崎骏电影的感觉，太治愈了。🍃",
        authorName: "旅行家杰克",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Jack",
        likeCount: 892,
        commentCount: 120,
        aspectRatio: 1.0,
      ),
      // 3. Film Noir
      CommunityPostMock(
        imageUrl: "https://picsum.photos/seed/post3/600/900",
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
        description: "分享一下 Soft Glamour 滤镜的参数设置，链接在主页！需要的自取~ 💄",
        authorName: "美妆Queen",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Luna",
        likeCount: 567,
        commentCount: 99,
        aspectRatio: 0.8,
      ),
      // 6. Food (New)
      CommunityPostMock(
        imageUrl: "https://picsum.photos/seed/food1/600/600",
        description: "深夜放毒。这碗拉面加上 Michelin Star 滤镜，看着也太有食欲了吧！🍜",
        authorName: "吃货小汤姆",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Tom",
        likeCount: 320,
        commentCount: 24,
        aspectRatio: 1.0,
      ),
      // 7. Cat (New)
      CommunityPostMock(
        imageUrl: "https://picsum.photos/seed/cat1/600/800",
        description: "哈哈，我把我家猫变成了皮克斯主角！眼神太到位了 😂 #PixarPet",
        authorName: "猫奴99号",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Kitty",
        likeCount: 4500,
        commentCount: 600,
        aspectRatio: 1.2,
      ),
      // 8. Abstract Art (New)
      CommunityPostMock(
        imageUrl: "https://picsum.photos/seed/art1/700/900",
        description: "正在测试抽象艺术风格转换。大家觉得这幅画怎么样？",
        authorName: "数字艺术家",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Art",
        likeCount: 88,
        commentCount: 12,
        aspectRatio: 1.4,
      ),
      // 9. Architecture (New)
      CommunityPostMock(
        imageUrl: "https://picsum.photos/seed/arch1/800/600",
        description: "现代线条遇上极简镜头。删繁就简，建筑之美。",
        authorName: "每日建筑",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Arch",
        likeCount: 150,
        commentCount: 5,
        aspectRatio: 0.75,
      ),
      // 10. Mountain (New)
      CommunityPostMock(
        imageUrl: "https://picsum.photos/seed/mountain1/600/750",
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
  // 0 = Discover, 1 = Messages
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
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // --- 1. 顶部自定义导航栏 (Header) ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppTheme.background,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 左侧：筛选按钮
                  _buildIconButton(Icons.tune, "Filter"),

                  // 中间：导航 Tab (Discover | Messages) - 保持英文
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTabItem(0, "Discover"), // 英文标签
                        _buildTabItem(1, "Messages"), // 英文标签
                      ],
                    ),
                  ),

                  // 右侧：搜索按钮
                  _buildIconButton(Icons.search, "Search"),
                ],
              ),
            ),

            // --- 2. 内容区域 (Content) ---
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: [
                  // Tab 1: Discover (瀑布流)
                  _buildDiscoverView(),

                  // Tab 2: Messages (列表)
                  _buildMessagesView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 构建 Tab 1: Discover (瀑布流) ---
  Widget _buildDiscoverView() {
    // 简单的瀑布流分列逻辑
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 100), // 底部留白给导航栏
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

  // --- 构建 Tab 2: Messages (列表 - 中文内容) ---
  Widget _buildMessagesView() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
      children: [
        // 官方消息
        _buildMessageItem(
          "MuseLens 官方小助手",
          "🎉 恭喜！您的作品入选了本周精选推荐。",
          "assets/images/logo.png", // 假设这是本地 logo
          "上午 10:00",
          isOfficial: true,
          isLocalImage: true,
        ),
        // 好友消息
        _buildMessageItem(
          "cher老师",
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

  // --- 辅助组件 ---

  Widget _buildIconButton(IconData icon, String tooltip) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
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
            color: isActive ? Colors.white : Colors.white.withOpacity(0.5),
            fontWeight: FontWeight.bold, // 保持粗体风格
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          // 头像
          Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey[800],
                child: ClipOval(
                  child: isLocalImage
                      ? Image.asset(
                          avatar,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) =>
                              const Icon(Icons.person, color: Colors.white),
                        )
                      : Image.network(
                          avatar,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          headers: const {'User-Agent': 'Mozilla/5.0'},
                          errorBuilder: (c, e, s) =>
                              const Icon(Icons.person, color: Colors.white),
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
          // 内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      time,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
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
      // --- 核心修改：添加点击跳转 ---
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PostDetailScreen(post: post)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
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
            // 1. 图片区域
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: AspectRatio(
                aspectRatio: 1 / post.aspectRatio,
                child: _buildSmartImage(post.imageUrl),
              ),
            ),

            // 2. 内容区域
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2.1 描述文字
                  Text(
                    post.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2.2 底部信息行
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 左侧：作者信息
                      Expanded(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 9,
                              backgroundColor: Colors.grey[800],
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
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 右侧：交互数据 (紫色椭圆)
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
                            // 点赞
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

                            // 分割线
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              width: 1,
                              height: 8,
                              color: AppTheme.electricIndigo.withOpacity(0.5),
                            ),

                            // 评论
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

  // 智能图片加载 helper
  Widget _buildSmartImage(String path, {bool isAvatar = false}) {
    if (path.startsWith('http')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        width: isAvatar ? 18 : null,
        height: isAvatar ? 18 : null,
        headers: const {'User-Agent': 'Mozilla/5.0'},
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[850],
          child: isAvatar
              ? const Icon(Icons.person, size: 10, color: Colors.white)
              : null,
        ),
      );
    } else {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        width: isAvatar ? 18 : null,
        height: isAvatar ? 18 : null,
        errorBuilder: (context, error, stackTrace) =>
            Container(color: Colors.grey[850]),
      );
    }
  }
}
