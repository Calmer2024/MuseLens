import 'dart:convert';

class User {
  final int userId;
  final String username;
  final String email;
  final String? nickname;
  final String? bio;
  final String? avatarUrl;
  final String? bannerUrl;
  final int totalLikes;
  final int followerCount;
  final int followingCount;
  final String memberLevel;
  final bool isVerified;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  User({
    required this.userId,
    required this.username,
    required this.email,
    this.nickname,
    this.bio,
    this.avatarUrl,
    this.bannerUrl,
    this.totalLikes = 0,
    this.followerCount = 0,
    this.followingCount = 0,
    this.memberLevel = 'free',
    this.isVerified = false,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'] as int,
      username: json['username'] as String,
      email: json['email'] as String,
      nickname: json['nickname'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bannerUrl: json['banner_url'] as String?,
      totalLikes: json['total_likes'] as int? ?? 0,
      followerCount: json['follower_count'] as int? ?? 0,
      followingCount: json['following_count'] as int? ?? 0,
      memberLevel: json['member_level'] as String? ?? 'free',
      isVerified: json['is_verified'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'email': email,
      'nickname': nickname,
      'bio': bio,
      'avatar_url': avatarUrl,
      'banner_url': bannerUrl,
      'total_likes': totalLikes,
      'follower_count': followerCount,
      'following_count': followingCount,
      'member_level': memberLevel,
      'is_verified': isVerified,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Serialize to JSON string for SharedPreferences storage
  String toJsonString() => jsonEncode(toJson());

  /// Deserialize from JSON string stored in SharedPreferences
  factory User.fromJsonString(String jsonString) {
    return User.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  /// Create a copy with updated fields
  User copyWith({
    String? nickname,
    String? bio,
    String? avatarUrl,
    String? bannerUrl,
    int? totalLikes,
    int? followerCount,
    int? followingCount,
    String? memberLevel,
    bool? isVerified,
  }) {
    return User(
      userId: userId,
      username: username,
      email: email,
      nickname: nickname ?? this.nickname,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      totalLikes: totalLikes ?? this.totalLikes,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
      memberLevel: memberLevel ?? this.memberLevel,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
