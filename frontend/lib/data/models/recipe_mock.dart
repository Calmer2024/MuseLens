// 文件路径: lib/data/models/recipe_mock.dart

class RecipeMock {
  final String title;
  final String imageUrl;
  final String iconName; // 模拟图标类型

  // --- 新增：作者名称和头像 ---
  final String author;
  final String authorAvatar;

  RecipeMock({
    required this.title,
    required this.imageUrl,
    required this.iconName,
    // --- 新增：构造函数必填参数 ---
    required this.author,
    required this.authorAvatar,
  });

  // 模拟后端返回的数据
  static List<RecipeMock> getRecentRecipes() {
    return [
      RecipeMock(
        title: "Cyberpunk City",
        imageUrl: "https://picsum.photos/id/122/200/200", // 模拟赛博朋克图
        iconName: "city",
        // --- 补充缺失的参数 ---
        author: "Neon_Walker",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Felix",
      ),
      RecipeMock(
        title: "Retro Film",
        imageUrl: "https://picsum.photos/id/123/200/200", // 模拟复古图
        iconName: "film",
        // --- 补充缺失的参数 ---
        author: "Film_Master",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Jack",
      ),
      RecipeMock(
        title: "Oil Canvas Style",
        imageUrl: "https://picsum.photos/id/124/200/200", // 模拟油画
        iconName: "brush",
        // --- 补充缺失的参数 ---
        author: "Art_Vibes",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Bella",
      ),
      RecipeMock(
        title: "Digital Glitch",
        imageUrl: "https://picsum.photos/id/125/200/200", // 模拟故障风
        iconName: "glitch",
        // --- 补充缺失的参数 ---
        author: "Glitch_God",
        authorAvatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Max",
      ),
    ];
  }
}
