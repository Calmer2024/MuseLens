import 'package:flutter/foundation.dart';

import 'user_model.dart';

@immutable
class MarketLens {
  final int lensId;
  final String lensKey;
  final String name;
  final String description;
  final int? authorId;
  final String? category;
  final double price;
  final bool isOfficial;
  final int installCount;
  final double rating;
  final int ratingCount;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MarketLens({
    required this.lensId,
    required this.lensKey,
    required this.name,
    required this.description,
    required this.authorId,
    required this.category,
    required this.price,
    required this.isOfficial,
    required this.installCount,
    required this.rating,
    required this.ratingCount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MarketLens.fromJson(Map<String, dynamic> json) {
    return MarketLens(
      lensId: json['lens_id'] as int,
      lensKey: json['lens_key'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      authorId: json['author_id'] as int?,
      category: json['category'] as String?,
      price: _readDouble(json['price']),
      isOfficial: json['is_official'] as bool? ?? false,
      installCount: json['install_count'] as int? ?? 0,
      rating: _readDouble(json['rating']),
      ratingCount: json['rating_count'] as int? ?? 0,
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  bool get isFree => price <= 0;

  String get displayPrice => isFree ? '免费' : '¥${price.toStringAsFixed(2)}';
}

@immutable
class MarketLensVersion {
  final int versionId;
  final int lensId;
  final String version;
  final Map<String, dynamic> baseWorkflow;
  final Map<String, dynamic> parameters;
  final Map<String, dynamic> uiSchema;
  final String changelog;
  final bool isLatest;
  final DateTime createdAt;

  const MarketLensVersion({
    required this.versionId,
    required this.lensId,
    required this.version,
    required this.baseWorkflow,
    required this.parameters,
    required this.uiSchema,
    required this.changelog,
    required this.isLatest,
    required this.createdAt,
  });

  factory MarketLensVersion.fromJson(Map<String, dynamic> json) {
    return MarketLensVersion(
      versionId: json['version_id'] as int,
      lensId: json['lens_id'] as int,
      version: json['version'] as String? ?? '',
      baseWorkflow: Map<String, dynamic>.from(
        json['base_workflow'] as Map<String, dynamic>? ?? const {},
      ),
      parameters: Map<String, dynamic>.from(
        json['parameters'] as Map<String, dynamic>? ?? const {},
      ),
      uiSchema: Map<String, dynamic>.from(
        json['ui_schema'] as Map<String, dynamic>? ?? const {},
      ),
      changelog: json['changelog'] as String? ?? '',
      isLatest: json['is_latest'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

@immutable
class LensReview {
  final int reviewId;
  final int lensId;
  final int userId;
  final int rating;
  final String content;
  final DateTime createdAt;

  const LensReview({
    required this.reviewId,
    required this.lensId,
    required this.userId,
    required this.rating,
    required this.content,
    required this.createdAt,
  });

  factory LensReview.fromJson(Map<String, dynamic> json) {
    return LensReview(
      reviewId: json['review_id'] as int,
      lensId: json['lens_id'] as int,
      userId: json['user_id'] as int,
      rating: json['rating'] as int? ?? 0,
      content: json['content'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

@immutable
class MarketLensAuthor {
  final int? userId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final bool isVerified;

  const MarketLensAuthor({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.isVerified,
  });

  factory MarketLensAuthor.fromUser(User user) {
    final nickname = user.nickname?.trim();
    final displayName = (nickname != null && nickname.isNotEmpty)
        ? nickname
        : user.username;
    return MarketLensAuthor(
      userId: user.userId,
      username: user.username,
      displayName: displayName,
      avatarUrl: user.avatarUrl,
      isVerified: user.isVerified,
    );
  }

  factory MarketLensAuthor.placeholder(int? userId) {
    if (userId == null) {
      return const MarketLensAuthor(
        userId: null,
        username: 'official',
        displayName: 'MuseLens 官方',
        avatarUrl: null,
        isVerified: true,
      );
    }

    return MarketLensAuthor(
      userId: userId,
      username: 'user_$userId',
      displayName: '用户$userId',
      avatarUrl: null,
      isVerified: false,
    );
  }
}

@immutable
class MarketLensView {
  final MarketLens lens;
  final MarketLensAuthor author;
  final bool isInstalled;
  final bool isFavorited;

  const MarketLensView({
    required this.lens,
    required this.author,
    required this.isInstalled,
    required this.isFavorited,
  });

  MarketLensView copyWith({
    MarketLens? lens,
    MarketLensAuthor? author,
    bool? isInstalled,
    bool? isFavorited,
  }) {
    return MarketLensView(
      lens: lens ?? this.lens,
      author: author ?? this.author,
      isInstalled: isInstalled ?? this.isInstalled,
      isFavorited: isFavorited ?? this.isFavorited,
    );
  }
}

@immutable
class LensReviewView {
  final LensReview review;
  final MarketLensAuthor author;

  const LensReviewView({
    required this.review,
    required this.author,
  });
}

@immutable
class MarketLensDetailData {
  final MarketLensView lens;
  final List<MarketLensVersion> versions;
  final List<LensReviewView> reviews;
  final LensReviewView? currentUserReview;

  const MarketLensDetailData({
    required this.lens,
    required this.versions,
    required this.reviews,
    required this.currentUserReview,
  });
}

@immutable
class CreateMarketLensInput {
  final String lensKey;
  final String name;
  final String description;
  final int authorId;
  final String? category;
  final double price;
  final bool isOfficial;
  final String status;

  const CreateMarketLensInput({
    required this.lensKey,
    required this.name,
    required this.description,
    required this.authorId,
    required this.category,
    required this.price,
    required this.isOfficial,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'lens_key': lensKey.trim(),
      'name': name.trim(),
      'description': description.trim(),
      'author_id': authorId,
      if (category != null && category!.trim().isNotEmpty)
        'category': category!.trim(),
      'price': price.toStringAsFixed(2),
      'is_official': isOfficial,
      'status': status.trim(),
    };
  }
}

@immutable
class UpdateMarketLensInput {
  final String? name;
  final String? description;
  final String? category;
  final double? price;
  final bool? isOfficial;
  final String? status;

  const UpdateMarketLensInput({
    this.name,
    this.description,
    this.category,
    this.price,
    this.isOfficial,
    this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name!.trim(),
      if (description != null) 'description': description!.trim(),
      if (category != null) 'category': category!.trim(),
      if (price != null) 'price': price!.toStringAsFixed(2),
      if (isOfficial != null) 'is_official': isOfficial,
      if (status != null) 'status': status!.trim(),
    };
  }
}

@immutable
class CreateMarketLensVersionInput {
  final String version;
  final Map<String, dynamic> baseWorkflow;
  final Map<String, dynamic> parameters;
  final Map<String, dynamic> uiSchema;
  final String changelog;
  final bool isLatest;

  const CreateMarketLensVersionInput({
    required this.version,
    required this.baseWorkflow,
    required this.parameters,
    required this.uiSchema,
    required this.changelog,
    required this.isLatest,
  });

  Map<String, dynamic> toJson() {
    return {
      'version': version.trim(),
      'base_workflow': baseWorkflow,
      'parameters': parameters,
      'ui_schema': uiSchema,
      'changelog': changelog.trim(),
      'is_latest': isLatest,
    };
  }
}

@immutable
class CreateLensReviewInput {
  final int userId;
  final int rating;
  final String content;

  const CreateLensReviewInput({
    required this.userId,
    required this.rating,
    required this.content,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'rating': rating,
      'content': content.trim(),
    };
  }
}

double _readDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
