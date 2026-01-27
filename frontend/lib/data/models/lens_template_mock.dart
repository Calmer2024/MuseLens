// 定义分割风格枚举
enum LensSplitStyle {
  diagonal, // 斜向分割
  vertical, // 竖向分割
}

class LensTemplateMock {
  final String title;
  final String author;
  final String authorAvatar;
  final String usageCount;
  final String beforeImage;
  final String afterImage;
  final bool isOfficial;
  final double aspectRatio;
  final LensSplitStyle splitStyle;

  LensTemplateMock({
    required this.title,
    required this.author,
    required this.authorAvatar,
    required this.usageCount,
    required this.beforeImage,
    required this.afterImage,
    this.isOfficial = false,
    this.aspectRatio = 1.2,
    this.splitStyle = LensSplitStyle.diagonal,
  });

  static List<LensTemplateMock> getTemplates() {
    return [
      // 1. Neon Tokyo (赛博朋克)
      LensTemplateMock(
        title: "Neon Tokyo",
        author: "@CyberPunk",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Felix",
        usageCount: "12.4k",
        beforeImage: "assets/images/lens_market/NeonTokyo_before.jpg",
        afterImage: "assets/images/lens_market/NeonTokyo_after.jpg",
        isOfficial: true,
        aspectRatio: 1.4,
        splitStyle: LensSplitStyle.diagonal,
      ),

      // 2. Ghibli Breeze (日系动漫)
      LensTemplateMock(
        title: "Ghibli Breeze",
        author: "@MiyazakiFan",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Luna",
        usageCount: "8.9k",
        beforeImage: "assets/images/lens_market/GhibliBreeze_before.jpg",
        afterImage: "assets/images/lens_market/GhibliBreeze_after.jpg",
        aspectRatio: 1.3,
        splitStyle: LensSplitStyle.vertical,
      ),

      // 3. Soft Glamour (高级人像)
      LensTemplateMock(
        title: "Soft Glamour",
        author: "@BeautyPro",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Bella",
        usageCount: "5.2k",
        beforeImage: "assets/images/lens_market/SoftGlamour_before.jpg",
        afterImage: "assets/images/lens_market/SoftGlamour_after.jpg",
        aspectRatio: 1.0,
        splitStyle: LensSplitStyle.vertical,
      ),

      // 4. 1990s Film (复古胶片)
      LensTemplateMock(
        title: "1990s Film",
        author: "@RetroVibes",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Jack",
        usageCount: "3.1k",
        beforeImage: "https://picsum.photos/seed/film_before/700/600",
        afterImage: "https://picsum.photos/seed/film_after/700/600",
        aspectRatio: 1.2,
        splitStyle: LensSplitStyle.diagonal,
      ),

      // 5. Studio Minimal (电商产品)
      LensTemplateMock(
        title: "Studio Minimal",
        author: "@ProductGuru",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Max",
        usageCount: "1.5k",
        beforeImage: "assets/images/lens_market/StudioMinimal_before.png",
        afterImage: "assets/images/lens_market/StudioMinimal_after.png",
        aspectRatio: 1.0,
        splitStyle: LensSplitStyle.vertical,
      ),

      // 6. Pixar Avatar (皮克斯风)
      LensTemplateMock(
        title: "Pixar Avatar",
        author: "@3DArtist",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Zoe",
        usageCount: "22k",
        beforeImage: "https://picsum.photos/seed/pixar_before/600/600",
        afterImage: "https://picsum.photos/seed/pixar_after/600/600",
        aspectRatio: 1.0,
        splitStyle: LensSplitStyle.vertical,
      ),

      // 7. Fantasy Realm (史诗风景)
      LensTemplateMock(
        title: "Fantasy Realm",
        author: "@MagicWand",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Wizard",
        usageCount: "4.5k",
        beforeImage: "https://picsum.photos/seed/fantasy_before/600/900",
        afterImage: "https://picsum.photos/seed/fantasy_after/600/900",
        aspectRatio: 1.5,
        splitStyle: LensSplitStyle.diagonal,
      ),

      // 8. Charcoal Sketch (素描)
      LensTemplateMock(
        title: "Charcoal Sketch",
        author: "@Sketchy",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Art",
        usageCount: "900",
        beforeImage: "assets/images/lens_market/CharcoalSketch_before.jpg",
        afterImage: "assets/images/lens_market/CharcoalSketch_after.jpg",
        aspectRatio: 1.1,
        splitStyle: LensSplitStyle.vertical,
      ),

      // 9. Michelin Star (美食滤镜)
      LensTemplateMock(
        title: "Michelin Star",
        author: "@FoodieOne",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Chef",
        usageCount: "6.7k",
        beforeImage: "https://picsum.photos/seed/food_before/600/600",
        afterImage: "https://picsum.photos/seed/food_after/600/600",
        aspectRatio: 1.0,
        splitStyle: LensSplitStyle.vertical,
      ),

      // 10. Future Tech (科幻机械)
      LensTemplateMock(
        title: "Future Tech",
        author: "@SciFiLab",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Robot",
        usageCount: "15k",
        beforeImage: "https://picsum.photos/seed/tech_before/800/600",
        afterImage: "https://picsum.photos/seed/tech_after/800/600",
        aspectRatio: 1.3,
        splitStyle: LensSplitStyle.diagonal,
      ),
    ];
  }
}
