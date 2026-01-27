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
  final LensSplitStyle splitStyle; // 新增字段

  LensTemplateMock({
    required this.title,
    required this.author,
    required this.authorAvatar,
    required this.usageCount,
    required this.beforeImage,
    required this.afterImage,
    this.isOfficial = false,
    this.aspectRatio = 1.2,
    this.splitStyle = LensSplitStyle.diagonal, // 默认为斜向
  });

  static List<LensTemplateMock> getTemplates() {
    return [
      LensTemplateMock(
        title: "Neon City",
        author: "@CreatorX",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Felix",
        usageCount: "2.4k",
        beforeImage: "https://picsum.photos/seed/neon_before/600/800",
        afterImage: "https://picsum.photos/seed/neon_after/600/800",
        isOfficial: true,
        aspectRatio: 1.4,
        splitStyle: LensSplitStyle.diagonal, // 斜切适合透视感强的街景
      ),
      LensTemplateMock(
        title: "Soft Glow",
        author: "@LightMaster",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Aneka",
        usageCount: "1.8k",
        beforeImage: "https://picsum.photos/seed/glow_before/600/600",
        afterImage: "https://picsum.photos/seed/glow_after/600/600",
        aspectRatio: 1.0,
        splitStyle: LensSplitStyle.vertical, // 竖切适合正脸人像
      ),
      LensTemplateMock(
        title: "Anime Style",
        author: "@TokyoDreamer",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Zack",
        usageCount: "7.3k",
        beforeImage: "https://picsum.photos/seed/anime_before/600/800",
        afterImage: "https://picsum.photos/seed/anime_after/600/800",
        aspectRatio: 1.3,
        splitStyle: LensSplitStyle.vertical, // 竖切适合人物展示
      ),
      LensTemplateMock(
        title: "Film Noir",
        author: "@RetroLens",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Bella",
        usageCount: "1.2k",
        beforeImage: "https://picsum.photos/seed/film_before/600/700",
        afterImage: "https://picsum.photos/seed/film_after/600/700",
        aspectRatio: 1.1,
        splitStyle: LensSplitStyle.diagonal, // 斜切增加电影感
      ),
      LensTemplateMock(
        title: "Fantasy Realm",
        author: "@MagicWand",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Luna",
        usageCount: "2.4k",
        beforeImage: "https://picsum.photos/seed/fantasy_before/600/900",
        afterImage: "https://picsum.photos/seed/fantasy_after/600/900",
        aspectRatio: 1.5,
        splitStyle: LensSplitStyle.vertical,
      ),
    ];
  }
}
