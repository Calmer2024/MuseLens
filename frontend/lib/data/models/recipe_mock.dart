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
        title: "赛博朋克城市",
        imageUrl: "assets/images/home/CyberpunkNightChallenge.jpg",
        iconName: "city",
        author: "Neon_Walker",
        authorAvatar: "assets/images/profile.png",
      ),
      RecipeMock(
        title: "复古胶片",
        imageUrl: "assets/images/home/OldPhotoRestore.jpg",
        iconName: "film",
        author: "Film_Master",
        authorAvatar: "assets/images/profile.png",
      ),
      RecipeMock(
        title: "油画风格",
        imageUrl: "assets/images/home/SpringFilmFestival.png",
        iconName: "brush",
        author: "Art_Vibes",
        authorAvatar: "assets/images/profile.png",
      ),
      RecipeMock(
        title: "数字故障风",
        imageUrl: "assets/images/home/TravelVlog.JPG",
        iconName: "glitch",
        author: "Glitch_God",
        authorAvatar: "assets/images/profile.png",
      ),
    ];
  }
}
