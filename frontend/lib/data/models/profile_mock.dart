class ProfileCreationMock {
  final String title;
  final String imageUrl;

  ProfileCreationMock({required this.title, required this.imageUrl});

  static List<ProfileCreationMock> getCreations() {
    return [
      ProfileCreationMock(
        title: "Neon Samurai",
        imageUrl: "assets/images/home/CyberpunkNightChallenge.jpg",
      ),
      ProfileCreationMock(
        title: "Abstract Flow",
        imageUrl: "assets/images/home/SpringFilmFestival.png",
      ),
      ProfileCreationMock(
        title: "Space Cat",
        imageUrl: "assets/images/home/AnimeGroupPhoto.JPG",
      ),
      ProfileCreationMock(
        title: "Cyber City",
        imageUrl: "assets/images/home/TravelVlog.JPG",
      ),
    ];
  }
}
