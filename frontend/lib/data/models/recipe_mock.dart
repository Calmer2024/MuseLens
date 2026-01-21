class RecipeMock {
  final String title;
  final String imageUrl;
  final String iconName; // 模拟图标类型

  RecipeMock({
    required this.title,
    required this.imageUrl,
    required this.iconName,
  });

  // 模拟后端返回的数据
  static List<RecipeMock> getRecentRecipes() {
    return [
      RecipeMock(
        title: "Cyberpunk City",
        imageUrl: "https://picsum.photos/id/122/200/200", // 模拟赛博朋克图
        iconName: "city",
      ),
      RecipeMock(
        title: "Retro Film",
        imageUrl: "https://picsum.photos/id/123/200/200", // 模拟复古图
        iconName: "film",
      ),
      RecipeMock(
        title: "Oil Canvas Style",
        imageUrl: "https://picsum.photos/id/124/200/200", // 模拟油画
        iconName: "brush",
      ),
      RecipeMock(
        title: "Digital Glitch",
        imageUrl: "https://picsum.photos/id/125/200/200", // 模拟故障风
        iconName: "glitch",
      ),
    ];
  }
}
