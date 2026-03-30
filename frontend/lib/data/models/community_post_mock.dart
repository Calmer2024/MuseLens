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

  String get description => title;
  String get authorAvatar => authorAvatarUrl;
  String get authorAvatarUrlOrFallback => authorAvatarUrl;
  String get likeCount => likes;
  int get commentCount => 12;
  List<String> get galleryImages => [imageUrl];

  static List<CommunityPostMock> getMockPosts() {
    return [
      CommunityPostMock(
        title: "Dreamy Clouds",
        authorName: "Alex Creates",
        authorHandle: "@alex_creates",
        imageUrl: "assets/images/home/SpringFilmFestival.png",
        authorAvatarUrl: "assets/images/profile.png",
        likes: "2.1k",
        aspectRatio: 1.3,
      ),
      CommunityPostMock(
        title: "Neon Cityscape",
        authorName: "Luna Art",
        authorHandle: "@luna_art",
        imageUrl: "assets/images/home/CyberpunkNightChallenge.jpg",
        authorAvatarUrl: "assets/images/profile.png",
        likes: "450",
        aspectRatio: 0.8,
      ),
      CommunityPostMock(
        title: "Vintage Film Noir",
        authorName: "Retro Vibes",
        authorHandle: "@retro_vibes",
        imageUrl: "assets/images/home/OldPhotoRestore.jpg",
        authorAvatarUrl: "assets/images/profile.png",
        likes: "10.3k",
        aspectRatio: 1.0,
      ),
      CommunityPostMock(
        title: "Creato-Sonnis",
        authorName: "Alex Art",
        authorHandle: "@alex_art",
        imageUrl: "assets/images/home/TravelVlog.JPG",
        authorAvatarUrl: "assets/images/profile.png",
        likes: "37k",
        aspectRatio: 1.6,
      ),
      CommunityPostMock(
        title: "Abstract Art",
        authorName: "Alex Creates",
        authorHandle: "@alex_creates",
        imageUrl: "assets/images/home/AnimeGroupPhoto.JPG",
        authorAvatarUrl: "assets/images/profile.png",
        likes: "10.3k",
        aspectRatio: 0.9,
      ),
      CommunityPostMock(
        title: "Vintage Carsion",
        authorName: "Luna Art",
        authorHandle: "@luna_art",
        imageUrl: "assets/images/home/Photography_after.png",
        authorAvatarUrl: "assets/images/profile.png",
        likes: "3.2k",
        aspectRatio: 1.1,
      ),
    ];
  }

  static List<CommunityPostMock> getPosts() => getMockPosts();
}
