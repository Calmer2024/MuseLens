class CommunityPostMock {
  final String title;
  final String authorName;
  final String authorHandle;
  final String imageUrl;
  final String authorAvatarUrl;
  final String likes;
  final double aspectRatio; // 图片宽高比，用于模拟瀑布流高度差异

  CommunityPostMock({
    required this.title,
    required this.authorName,
    required this.authorHandle,
    required this.imageUrl,
    required this.authorAvatarUrl,
    required this.likes,
    required this.aspectRatio,
  });

  static List<CommunityPostMock> getMockPosts() {
    return [
      CommunityPostMock(
        title: "Dreamy Clouds",
        authorName: "Alex Creates",
        authorHandle: "@alex_creates",
        imageUrl: "https://picsum.photos/400/300", // 宽图
        authorAvatarUrl: "https://i.pravatar.cc/150?img=11",
        likes: "2.1k",
        aspectRatio: 1.3,
      ),
      CommunityPostMock(
        title: "Neon Cityscape",
        authorName: "Luna Art",
        authorHandle: "@luna_art",
        imageUrl: "https://picsum.photos/400/500", // 长图
        authorAvatarUrl: "https://i.pravatar.cc/150?img=5",
        likes: "450",
        aspectRatio: 0.8,
      ),
      CommunityPostMock(
        title: "Vintage Film Noir",
        authorName: "Retro Vibes",
        authorHandle: "@retro_vibes",
        imageUrl: "https://picsum.photos/400/400", // 方图
        authorAvatarUrl: "https://i.pravatar.cc/150?img=3",
        likes: "10.3k",
        aspectRatio: 1.0,
      ),
      CommunityPostMock(
        title: "Creato-Sonnis",
        authorName: "Alex Art",
        authorHandle: "@alex_art",
        imageUrl: "https://picsum.photos/400/250",
        authorAvatarUrl: "https://i.pravatar.cc/150?img=8",
        likes: "37k",
        aspectRatio: 1.6,
      ),
      CommunityPostMock(
        title: "Abstract Art",
        authorName: "Alex Creates",
        authorHandle: "@alex_creates",
        imageUrl: "https://picsum.photos/400/450",
        authorAvatarUrl: "https://i.pravatar.cc/150?img=11",
        likes: "10.3k",
        aspectRatio: 0.9,
      ),
      CommunityPostMock(
        title: "Vintage Carsion",
        authorName: "Luna Art",
        authorHandle: "@luna_art",
        imageUrl: "https://picsum.photos/400/350",
        authorAvatarUrl: "https://i.pravatar.cc/150?img=5",
        likes: "3.2k",
        aspectRatio: 1.1,
      ),
    ];
  }
}
