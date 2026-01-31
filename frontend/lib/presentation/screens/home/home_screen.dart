import 'package:flutter/material.dart';
import '../../widgets/home/hero_create_card.dart';
import '../../widgets/home/recipe_list_item.dart';
import '../../../data/models/recipe_mock.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/lens_template_mock.dart';
import '../lens/lens_detail_screen.dart';

// --- 1. 临时 Mock 数据 ---
class OfficialLensItem {
  final String title;
  final String imageUrl;
  final String usageCount;
  final LensTemplateMock templateData;

  OfficialLensItem({
    required this.title,
    required this.imageUrl,
    required this.usageCount,
    required this.templateData,
  });
}

class OfficialChallengeItem {
  final String title;
  final String description;
  final String imageUrl;
  final String participants;

  OfficialChallengeItem({
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.participants,
  });
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 获取之前的 Recent 数据
    final recipes = RecipeMock.getRecentRecipes();

    // --- 准备官方 Lens 数据 ---
    final List<OfficialLensItem> officialLenses = [
      OfficialLensItem(
        title: "老照片修复",
        imageUrl: "assets/images/home/OldPhotoRestore.jpg",
        usageCount: "1.2M Uses",
        templateData: LensTemplateMock(
          title: "老照片修复",
          author: "MuseLens Official",
          authorAvatar: "assets/images/logo.png",
          usageCount: "1.2M",
          beforeImage: "https://picsum.photos/seed/old_before/300/300",
          afterImage: "https://picsum.photos/seed/old_after/300/300",
          isOfficial: true,
          splitStyle: LensSplitStyle.vertical,
        ),
      ),
      OfficialLensItem(
        title: "一键生成你的旅游日记~",
        imageUrl: "assets/images/home/TravelVlog.JPG",
        usageCount: "850k Uses",
        templateData: LensTemplateMock(
          title: "旅游日记 Vlog",
          author: "MuseLens Official",
          authorAvatar: "assets/images/logo.png",
          usageCount: "850k",
          beforeImage: "https://picsum.photos/seed/travel_before/300/300",
          afterImage: "https://picsum.photos/seed/travel_after/300/300",
          isOfficial: true,
          splitStyle: LensSplitStyle.diagonal,
        ),
      ),
      OfficialLensItem(
        title: "快来和动漫人物合影吧！",
        imageUrl: "assets/images/home/AnimeGroupPhoto.JPG",
        usageCount: "2.3M Uses",
        templateData: LensTemplateMock(
          title: "打破次元壁",
          author: "MuseLens Official",
          authorAvatar: "assets/images/logo.png",
          usageCount: "2.3M",
          beforeImage: "https://picsum.photos/seed/anime_before/300/300",
          afterImage: "https://picsum.photos/seed/anime_after/300/300",
          isOfficial: true,
          splitStyle: LensSplitStyle.vertical,
        ),
      ),
      OfficialLensItem(
        title: "你也可以变成摄影大师~",
        imageUrl: "https://picsum.photos/seed/anime/300/400",
        usageCount: "500k Uses",
        templateData: LensTemplateMock(
          title: "大师名作",
          author: "MuseLens Official",
          authorAvatar: "assets/images/logo.png",
          usageCount: "500k",
          beforeImage: "https://picsum.photos/seed/art_before/300/300",
          afterImage: "https://picsum.photos/seed/art_after/300/300",
          isOfficial: true,
          splitStyle: LensSplitStyle.diagonal,
        ),
      ),
    ];

    // --- 准备话题挑战数据 ---
    final List<OfficialChallengeItem> challenges = [
      OfficialChallengeItem(
        title: "#赛博朋克夜景挑战",
        description: "寻找身边的霓虹灯光",
        imageUrl: "assets/images/home/CyberpunkNightChallenge.jpg",
        participants: "24k joined",
      ),
      OfficialChallengeItem(
        title: "#春日胶片大赏",
        description: "记录春天的第一抹绿色",
        imageUrl: "assets/images/home/SpringFilmFestival.png",
        participants: "18k joined",
      ),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. Top Header ---
              _buildUserInfoHeader(),

              const SizedBox(height: 30),

              // --- 2. Hero Section (Updated) ---
              // 现在 HeroCreateCard 内部已经支持本地图片逻辑
              const HeroCreateCard(),

              const SizedBox(height: 30),

              // --- 3. My Recent Lens Section ---
              _buildSectionHeader(title: "My Recent Lens", showViewAll: false),
              const SizedBox(height: 16),
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: recipes.length,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    // RecipeListItem 内部如果需要修改，原理同下
                    return RecipeListItem(recipe: recipes[index]);
                  },
                ),
              ),

              const SizedBox(height: 30),

              // --- 4. Official Trending Templates ---
              _buildSectionHeader(
                title: "Trending Templates",
                onTapViewAll: () {},
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemCount: officialLenses.length,
                itemBuilder: (context, index) {
                  return _buildOfficialLensCard(context, officialLenses[index]);
                },
              ),

              const SizedBox(height: 30),

              // --- 5. Official Topics & Challenges ---
              _buildSectionHeader(
                title: "Topics & Challenges",
                onTapViewAll: () {},
              ),
              const SizedBox(height: 16),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: challenges.length,
                separatorBuilder: (c, i) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  return _buildChallengeCard(challenges[index]);
                },
              ),

              // 底部留白
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  // --- 组件封装 ---

  // 1. 顶部用户信息栏 (已优化图片加载)
  Widget _buildUserInfoHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Good morning, Creator",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
        Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              // 使用辅助方法加载本地或网络头像
              image: _getImageProvider("assets/images/profile.jpg"),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
  }

  // 2. 通用 Section 标题栏
  Widget _buildSectionHeader({
    required String title,
    bool showViewAll = true,
    VoidCallback? onTapViewAll,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        if (showViewAll)
          GestureDetector(
            onTap: onTapViewAll,
            child: Row(
              children: [
                Text(
                  "View All",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 10,
                  color: Colors.white.withOpacity(0.6),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // 3. 官方 Lens 模板卡片 (已优化图片加载)
  Widget _buildOfficialLensCard(BuildContext context, OfficialLensItem item) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LensDetailScreen(template: item.templateData),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: Image(
                      image: _getImageProvider(item.imageUrl), // <--- 核心修改
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) =>
                          Container(color: Colors.grey[800]),
                    ),
                  ),
                  if (item.title == "老照片修复")
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4757),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "HOT",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.play_circle_outline,
                        size: 12,
                        color: AppTheme.electricIndigo,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.usageCount,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 10,
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

  // 4. 话题挑战卡片 (已优化图片加载)
  Widget _buildChallengeCard(OfficialChallengeItem item) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        image: DecorationImage(
          image: _getImageProvider(item.imageUrl), // <--- 核心修改
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Colors.black.withOpacity(0.8), Colors.transparent],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.electricIndigo.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    "Challenge",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  // 修改 3: 限制行数，防止标题过长导致溢出
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  "${item.description} · ${item.participants}",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                  // 修改 4: 限制描述行数
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            top: 0,
            bottom: 0,
            child: Center(
              child: Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withOpacity(0.8),
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 核心辅助方法：智能图片提供者 ---
  ImageProvider _getImageProvider(String path) {
    if (path.startsWith('http')) {
      return NetworkImage(path);
    } else {
      return AssetImage(path);
    }
  }
}
