class UserSummary {
  final int userId;
  final String username;
  final String? nickname;
  final String? avatarUrl;
  final String? bio;
  final bool isVerified;

  const UserSummary({
    required this.userId,
    required this.username,
    this.nickname,
    this.avatarUrl,
    this.bio,
    this.isVerified = false,
  });

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    return UserSummary(
      userId: json['user_id'] as int,
      username: json['username'] as String,
      nickname: json['nickname'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }

  String get displayName {
    final trimmed = nickname?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    return username;
  }

  static List<UserSummary> fromJsonList(List<dynamic> jsonList) {
    return jsonList
        .map((json) => UserSummary.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
