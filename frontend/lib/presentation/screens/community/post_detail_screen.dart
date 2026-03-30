import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/community_post_mock.dart';
import '../../widgets/shared/adaptive_media.dart';

class PostDetailScreen extends StatefulWidget {
  final CommunityPostMock post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();

  // 模拟多图数据
  late List<String> _postImages;

  // 模拟评论数据
  final List<Map<String, dynamic>> _comments = [
    {
      "name": "Neon_Walker",
      "avatar": "assets/images/profile.png",
      "content": "这看起来太不可思议了！色彩无比鲜艳。一定要试试这个滤镜。",
      "likes": 45,
      "time": "2小时前",
    },
    {
      "name": "Digital_Dreamer",
      "avatar": "assets/images/profile.png",
      "content": "这是我本周见过的最棒的赛博朋克照片。干得漂亮！🔥",
      "likes": 28,
      "time": "5小时前",
    },
    {
      "name": "Tech_Nomad",
      "avatar": "assets/images/profile.png",
      "content": "氛围感太强了。绝佳的构图。",
      "likes": 12,
      "time": "1天前",
    },
    {
      "name": "Lens_Master",
      "avatar": "assets/images/profile.png",
      "content": "这是V2版本吗？光晕更柔和了。",
      "likes": 8,
      "time": "1天前",
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.post.galleryImages.isNotEmpty) {
      _postImages = widget.post.galleryImages;
    } else {
      _postImages = [
        widget.post.imageUrl,
        "assets/images/home/AnimeGroupPhoto.JPG",
        "assets/images/home/TravelVlog.JPG",
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. 可滚动的主体内容
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 100), // 底部留出互动栏空间
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1.1 图片轮播 (支持本地/网络混合)
                _buildImageCarousel(context),

                // 1.2 帖子文本内容
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post.description,
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildTag("#Cyberpunk"),
                          _buildTag("#MuseLens"),
                          _buildTag("#StreetPhotography"),
                          _buildTag("#NightCity"),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "10-24 · 使用 MuseLens 编辑",
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                const Divider(color: Colors.black12, height: 1),

                // 1.3 评论区
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "评论 (${widget.post.commentCount})",
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildPinnedLensCard(),

                      const SizedBox(height: 24),

                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _comments.length,
                        separatorBuilder: (c, i) => const SizedBox(height: 20),
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return _buildCommentItem(comment);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. 顶部悬浮导航栏
          Positioned(top: 0, left: 0, right: 0, child: _buildTopBar(context)),

          // 3. 底部固定互动栏
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomBar()),
        ],
      ),
    );
  }

  // --- 组件构建方法 ---

  Widget _buildImageCarousel(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.width * 1.25,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _postImages.length,
            onPageChanged: (index) {
              setState(() => _currentImageIndex = index);
            },
            itemBuilder: (context, index) {
              final path = _postImages[index];
              return buildAdaptiveImage(
                path,
                fit: BoxFit.cover,
                placeholder: Container(
                  color: Colors.grey[100],
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.electricIndigo,
                    ),
                  ),
                ),
                errorWidget: Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(Icons.broken_image, color: Colors.black12),
                  ),
                ),
              );
            },
          ),
        ),
        // 指示器 Dots
        Positioned(
          bottom: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_postImages.length, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 6,
                width: _currentImageIndex == index ? 20 : 6,
                decoration: BoxDecoration(
                  color: _currentImageIndex == index
                      ? AppTheme.electricIndigo
                      : Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // 辅助方法：半透明圆形按钮
  Widget _buildGlassCircle(Widget child, {double size = 40}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: child,
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 10,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: _buildGlassCircle(
              const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey[800],
                  backgroundImage: resolveAdaptiveImageProvider(
                    widget.post.authorAvatar,
                  ),
                  child: widget.post.authorAvatar.trim().isEmpty
                      ? const Icon(Icons.person, color: Colors.white, size: 20)
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.post.authorName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.electricIndigo,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "Follow",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildGlassCircle(
            const Icon(Icons.share, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedLensCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.electricIndigo.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.electricIndigo.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              // 使用帖子封面图作为缩略图，智能判断类型
              image: DecorationImage(
                image:
                    resolveAdaptiveImageProvider(widget.post.imageUrl) ??
                    const AssetImage('assets/images/profile.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Center(
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Icon(
                  Icons.compare_arrows,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "滤镜模板同款",
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Neon Tokyo V2",
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.electricIndigo,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              "试用滤镜",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey[200],
          backgroundImage: resolveAdaptiveImageProvider(
            comment['avatar'] as String?,
          ),
          child:
              (comment['avatar'] as String?) == null ||
                  (comment['avatar'] as String).trim().isEmpty
              ? const Icon(Icons.person, color: Colors.grey, size: 20)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                comment['name'],
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                comment['content'],
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    comment['time'],
                    style: const TextStyle(color: Colors.black45, fontSize: 11),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    "回复",
                    style: const TextStyle(
                      color: Colors.black45,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Column(
          children: [
            Icon(Icons.favorite_border, size: 16, color: Colors.black26),
            const SizedBox(height: 4),
            Text(
              "${comment['likes']}",
              style: const TextStyle(color: Colors.black45, fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        border: Border(top: BorderSide(color: Colors.black.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.centerLeft,
              child: Text(
                "添加评论...",
                style: const TextStyle(color: Colors.black54, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 16),
          _buildInteractionIcon(
            Icons.favorite,
            "${widget.post.likeCount}",
            color: AppTheme.electricIndigo,
          ),
          const SizedBox(width: 16),
          _buildInteractionIcon(Icons.star_border, "892"),
          const SizedBox(width: 16),
          _buildInteractionIcon(
            Icons.chat_bubble_outline,
            "${widget.post.commentCount}",
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionIcon(
    IconData icon,
    String count, {
    Color color = Colors.black87,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 2),
        Text(
          count,
          style: TextStyle(
            color: color == Colors.black87 ? Colors.black54 : color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.black87, fontSize: 12),
      ),
    );
  }
}
