import 'package:flutter/foundation.dart';

import 'user_model.dart';

@immutable
class CommunityTag {
  final int tagId;
  final String name;
  final String description;
  final int postCount;
  final DateTime createdAt;

  const CommunityTag({
    required this.tagId,
    required this.name,
    required this.description,
    required this.postCount,
    required this.createdAt,
  });

  factory CommunityTag.fromJson(Map<String, dynamic> json) {
    return CommunityTag(
      tagId: json['tag_id'] as int,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      postCount: json['post_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

@immutable
class CommunityPostImage {
  final int imageId;
  final String imageUrl;
  final String? thumbnailUrl;
  final int? width;
  final int? height;
  final int orderIndex;
  final String? assetNodeId;

  const CommunityPostImage({
    required this.imageId,
    required this.imageUrl,
    required this.thumbnailUrl,
    required this.width,
    required this.height,
    required this.orderIndex,
    required this.assetNodeId,
  });

  factory CommunityPostImage.fromJson(Map<String, dynamic> json) {
    return CommunityPostImage(
      imageId: json['image_id'] as int,
      imageUrl: json['image_url'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      orderIndex: json['order_index'] as int? ?? 0,
      assetNodeId: json['asset_node_id']?.toString(),
    );
  }
}

@immutable
class CommunityPost {
  final int postId;
  final int userId;
  final String? title;
  final String content;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final int viewCount;
  final bool isPublic;
  final String auditStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<CommunityPostImage> images;
  final List<CommunityTag> tags;

  const CommunityPost({
    required this.postId,
    required this.userId,
    required this.title,
    required this.content,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.viewCount,
    required this.isPublic,
    required this.auditStatus,
    required this.createdAt,
    required this.updatedAt,
    required this.images,
    required this.tags,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      postId: json['post_id'] as int,
      userId: json['user_id'] as int,
      title: json['title'] as String?,
      content: json['content'] as String? ?? '',
      likeCount: json['like_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      shareCount: json['share_count'] as int? ?? 0,
      viewCount: json['view_count'] as int? ?? 0,
      isPublic: json['is_public'] as bool? ?? true,
      auditStatus: json['audit_status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      images: (json['images'] as List<dynamic>? ?? const [])
          .map((item) => CommunityPostImage.fromJson(item as Map<String, dynamic>))
          .toList(),
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((item) => CommunityTag.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  CommunityPost copyWith({
    String? title,
    String? content,
    int? likeCount,
    int? commentCount,
    int? shareCount,
    int? viewCount,
    bool? isPublic,
    String? auditStatus,
    DateTime? updatedAt,
    List<CommunityPostImage>? images,
    List<CommunityTag>? tags,
  }) {
    return CommunityPost(
      postId: postId,
      userId: userId,
      title: title ?? this.title,
      content: content ?? this.content,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      shareCount: shareCount ?? this.shareCount,
      viewCount: viewCount ?? this.viewCount,
      isPublic: isPublic ?? this.isPublic,
      auditStatus: auditStatus ?? this.auditStatus,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      images: images ?? this.images,
      tags: tags ?? this.tags,
    );
  }
}

@immutable
class CommunityComment {
  final int commentId;
  final int postId;
  final int userId;
  final int? parentId;
  final int? rootId;
  final String content;
  final int likeCount;
  final int replyCount;
  final int level;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CommunityComment({
    required this.commentId,
    required this.postId,
    required this.userId,
    required this.parentId,
    required this.rootId,
    required this.content,
    required this.likeCount,
    required this.replyCount,
    required this.level,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CommunityComment.fromJson(Map<String, dynamic> json) {
    return CommunityComment(
      commentId: json['comment_id'] as int,
      postId: json['post_id'] as int,
      userId: json['user_id'] as int,
      parentId: json['parent_id'] as int?,
      rootId: json['root_id'] as int?,
      content: json['content'] as String? ?? '',
      likeCount: json['like_count'] as int? ?? 0,
      replyCount: json['reply_count'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  CommunityComment copyWith({
    String? content,
    int? likeCount,
    int? replyCount,
    DateTime? updatedAt,
  }) {
    return CommunityComment(
      commentId: commentId,
      postId: postId,
      userId: userId,
      parentId: parentId,
      rootId: rootId,
      content: content ?? this.content,
      likeCount: likeCount ?? this.likeCount,
      replyCount: replyCount ?? this.replyCount,
      level: level,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

@immutable
class CommunityAuthor {
  final int userId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final bool isVerified;

  const CommunityAuthor({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.isVerified,
  });

  factory CommunityAuthor.fromUser(User user) {
    return CommunityAuthor(
      userId: user.userId,
      username: user.username,
      displayName: (user.nickname != null && user.nickname!.trim().isNotEmpty)
          ? user.nickname!.trim()
          : user.username,
      avatarUrl: user.avatarUrl,
      isVerified: user.isVerified,
    );
  }

  factory CommunityAuthor.placeholder(int userId) {
    return CommunityAuthor(
      userId: userId,
      username: 'user_$userId',
      displayName: '用户$userId',
      avatarUrl: null,
      isVerified: false,
    );
  }
}

@immutable
class CommunityPostView {
  final CommunityPost post;
  final CommunityAuthor author;
  final bool isLiked;
  final bool isFavorited;

  const CommunityPostView({
    required this.post,
    required this.author,
    required this.isLiked,
    required this.isFavorited,
  });

  List<String> get galleryImages {
    if (post.images.isEmpty) return const [];
    final sortedImages = [...post.images]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return sortedImages
        .map((item) => item.imageUrl.trim())
        .where((url) => url.isNotEmpty)
        .toList();
  }

  List<CommunityPostImage> get orderedImages {
    if (post.images.isEmpty) return const [];
    final sortedImages = [...post.images]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return sortedImages;
  }

  CommunityPostImage? get coverImage {
    for (final image in orderedImages) {
      if (image.imageUrl.trim().isNotEmpty) {
        return image;
      }
    }
    return null;
  }

  String? get coverImageUrl {
    return coverImage?.imageUrl.trim();
  }

  String get displayTitle {
    final trimmedTitle = post.title?.trim();
    if (trimmedTitle != null && trimmedTitle.isNotEmpty) {
      return trimmedTitle;
    }
    final trimmedContent = post.content.trim();
    if (trimmedContent.isNotEmpty) {
      return trimmedContent;
    }
    return '未命名帖子';
  }

  double? get coverAspectRatio {
    final cover = coverImage;
    if (cover == null) return null;
    final width = cover.width;
    final height = cover.height;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return width / height;
  }

  double? imageAspectRatioAt(int index) {
    if (index < 0 || index >= orderedImages.length) {
      return null;
    }
    final image = orderedImages[index];
    final width = image.width;
    final height = image.height;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return width / height;
  }

  CommunityPostView copyWith({
    CommunityPost? post,
    CommunityAuthor? author,
    bool? isLiked,
    bool? isFavorited,
  }) {
    return CommunityPostView(
      post: post ?? this.post,
      author: author ?? this.author,
      isLiked: isLiked ?? this.isLiked,
      isFavorited: isFavorited ?? this.isFavorited,
    );
  }
}

@immutable
class CommunityCommentView {
  final CommunityComment comment;
  final CommunityAuthor author;
  final bool isLiked;
  final List<CommunityCommentView> replies;

  const CommunityCommentView({
    required this.comment,
    required this.author,
    required this.isLiked,
    required this.replies,
  });

  CommunityCommentView copyWith({
    CommunityComment? comment,
    CommunityAuthor? author,
    bool? isLiked,
    List<CommunityCommentView>? replies,
  }) {
    return CommunityCommentView(
      comment: comment ?? this.comment,
      author: author ?? this.author,
      isLiked: isLiked ?? this.isLiked,
      replies: replies ?? this.replies,
    );
  }
}

@immutable
class CommunityPostDetailData {
  final CommunityPostView post;
  final List<CommunityCommentView> comments;

  const CommunityPostDetailData({
    required this.post,
    required this.comments,
  });
}

@immutable
class CreatePostImageInput {
  final String imageUrl;
  final String? thumbnailUrl;
  final int? width;
  final int? height;
  final int orderIndex;
  final String? assetNodeId;

  const CreatePostImageInput({
    required this.imageUrl,
    this.thumbnailUrl,
    this.width,
    this.height,
    required this.orderIndex,
    this.assetNodeId,
  });

  Map<String, dynamic> toJson() {
    return {
      'image_url': imageUrl,
      if (thumbnailUrl != null && thumbnailUrl!.trim().isNotEmpty)
        'thumbnail_url': thumbnailUrl!.trim(),
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      'order_index': orderIndex,
      if (assetNodeId != null && assetNodeId!.trim().isNotEmpty)
        'asset_node_id': assetNodeId!.trim(),
    };
  }
}

@immutable
class CreatePostInput {
  final int userId;
  final String? title;
  final String content;
  final bool isPublic;
  final List<CreatePostImageInput> images;
  final List<String> tagNames;

  const CreatePostInput({
    required this.userId,
    required this.title,
    required this.content,
    required this.isPublic,
    required this.images,
    required this.tagNames,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      if (title != null && title!.trim().isNotEmpty) 'title': title!.trim(),
      'content': content.trim(),
      'is_public': isPublic,
      'images': images.map((item) => item.toJson()).toList(),
      'tag_names': tagNames,
    };
  }
}
