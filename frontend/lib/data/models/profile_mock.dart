class ProfileCreationMock {
  final String title;
  final String imageUrl;

  ProfileCreationMock({required this.title, required this.imageUrl});

  static List<ProfileCreationMock> getCreations() {
    return [
      ProfileCreationMock(
        title: "Neon Samurai",
        imageUrl: "https://picsum.photos/id/237/400/600", // 替换为类似赛博武士的图
      ),
      ProfileCreationMock(
        title: "Abstract Flow",
        imageUrl: "https://picsum.photos/id/238/400/300", // 替换为抽象流体
      ),
      ProfileCreationMock(
        title: "Space Cat",
        imageUrl: "https://picsum.photos/id/239/400/250", // 替换为太空猫
      ),
      ProfileCreationMock(
        title: "Cyber City",
        imageUrl: "https://picsum.photos/id/240/400/500",
      ),
    ];
  }
}
