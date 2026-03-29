import 'package:flutter/material.dart';
// 引入刚刚写的炫彩流体卡片
import '../../widgets/home/hero_create_card.dart';
import '../../widgets/home/recipe_list_item.dart';
import '../../../data/models/recipe_mock.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/navigation/slide_right_route.dart';
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
    final recipes = RecipeMock.getRecentRecipes();

    // 官方 Lens 数据
    final List<OfficialLensItem> officialLenses = [
      OfficialLensItem(
        title: "老照片修复",
        imageUrl: "assets/images/home/OldPhotoRestore.jpg",
        usageCount: "120万次使用",
        templateData: LensTemplateMock(
          title: "老照片修复",
          author: "MuseLens Official",
          authorAvatar: "assets/images/logo.png",
          usageCount: "1.2M",
          beforeImage: "assets/images/home/Old_before.png",
          afterImage: "assets/images/home/Old_after.png",
          isOfficial: true,
          splitStyle: LensSplitStyle.vertical,
        ),
      ),
      OfficialLensItem(
        title: "一键生成你的旅游日记~",
        imageUrl: "assets/images/home/TravelVlog.JPG",
        usageCount: "85万次使用",
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
        usageCount: "230万次使用",
        templateData: LensTemplateMock(
          title: "打破次元壁",
          author: "MuseLens Official",
          authorAvatar: "assets/images/logo.png",
          usageCount: "2.3M",
          beforeImage: "assets/images/home/Cartoon_before.png",
          afterImage: "assets/images/home/Cartoon_after.png",
          isOfficial: true,
          splitStyle: LensSplitStyle.vertical,
        ),
      ),
      OfficialLensItem(
        title: "你也可以变成摄影大师~",
        imageUrl: "https://picsum.photos/seed/anime/300/400",
        usageCount: "50万次使用",
        templateData: LensTemplateMock(
          title: "大师名作",
          author: "MuseLens Official",
          authorAvatar: "assets/images/logo.png",
          usageCount: "500k",
          beforeImage: "assets/images/home/Photography_before.png",
          afterImage: "assets/images/home/Photography_after.png",
          isOfficial: true,
          splitStyle: LensSplitStyle.diagonal,
        ),
      ),
    ];

    // 话题挑战数据
    final List<OfficialChallengeItem> challenges = [
      OfficialChallengeItem(
        title: "#赛博朋克夜景挑战",
        description: "寻找身边的霓虹灯光",
        imageUrl: "assets/images/home/CyberpunkNightChallenge.jpg",
        participants: "2.4万人参与",
      ),
      OfficialChallengeItem(
        title: "#春日胶片大赏",
        description: "记录春天的第一抹绿色",
        imageUrl: "assets/images/home/SpringFilmFestival.png",
        participants: "1.8万人参与",
      ),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. 顶部炫彩玻璃流体卡片 ---
              const HeroCreateCard(),

              const SizedBox(height: 32),

              // --- 2. 最近使用 ---
              _buildSectionHeader(context, title: "最近使用", onTapViewAll: () {}),
              const SizedBox(height: 12),
              SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: recipes.length,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    return RecipeListItem(recipe: recipes[index]);
                  },
                ),
              ),

              const SizedBox(height: 32),

              // --- 3. 热门创作 ---
              _buildSectionHeader(context, title: "热门创作", onTapViewAll: () {}),
              const SizedBox(height: 12),
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

              const SizedBox(height: 32),

              // --- 4. 话题与挑战 ---
              _buildSectionHeader(context, title: "话题与挑战", onTapViewAll: () {}),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: challenges.length,
                separatorBuilder: (c, i) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  return _buildChallengeCard(challenges[index]);
                },
              ),

              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  // --- 组件封装 ---
  Widget _buildSectionHeader(
    BuildContext context, {
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
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E1E1E),
          ),
        ),
        if (showViewAll)
          GestureDetector(
            onTap: onTapViewAll,
            child: Row(
              children: [
                Text(
                  "查看全部",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withOpacity(0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 10,
                  color: Colors.black.withOpacity(0.5),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildOfficialLensCard(BuildContext context, OfficialLensItem item) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          SlideRightRoute(page: LensDetailScreen(template: item.templateData)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
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
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: Image(
                      image: _getImageProvider(item.imageUrl),
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) =>
                          Container(color: Colors.grey[200]),
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
                          "热门",
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
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF1E1E1E),
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
                        color: AppTheme.primaryPurple,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.usageCount,
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.4),
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

  Widget _buildChallengeCard(OfficialChallengeItem item) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        image: DecorationImage(
          image: _getImageProvider(item.imageUrl),
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
                colors: [Colors.black.withOpacity(0.7), Colors.transparent],
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
                    color: AppTheme.primaryPurple.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    "挑战",
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

  ImageProvider _getImageProvider(String path) {
    if (path.startsWith('http')) {
      return NetworkImage(path);
    } else {
      return AssetImage(path);
    }
  }
}
