import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/community_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/chat_models.dart';
import '../../../data/models/community_models.dart';
import '../../../data/repositories/community_repository.dart';
import '../../../data/models/user_model.dart';
import '../../../core/providers/user_provider.dart';
import '../../widgets/profile/follow_action_button.dart';
import '../../widgets/shared/adaptive_media.dart';
import '../auth/login_screen.dart';
import 'chat_friend_picker_screen.dart';
import '../profile/user_detail_screen.dart';

class CommunityPostDetailScreen extends ConsumerStatefulWidget {
  const CommunityPostDetailScreen({super.key, required this.postId});

  final int postId;

  @override
  ConsumerState<CommunityPostDetailScreen> createState() =>
      _CommunityPostDetailScreenState();
}

class _CommunityPostDetailScreenState
    extends ConsumerState<CommunityPostDetailScreen> {
  final _commentController = TextEditingController();
  final _pageController = PageController();

  CommunityPostDetailData? _detailState;
  int _currentImage = 0;
  bool _submittingComment = false;
  bool _updatingPostAction = false;
  bool _deletingPost = false;
  final Set<int> _updatingComments = <int>{};
  final Set<int> _animatedCommentIds = <int>{};
  CommunityCommentView? _replyTarget;

  @override
  void didUpdateWidget(covariant CommunityPostDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId) {
      _detailState = null;
      _replyTarget = null;
      _currentImage = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(communityPostDetailProvider(widget.postId));
    final currentUser = ref.watch(authProvider);
    ref.listen<AsyncValue<CommunityPostDetailData>>(
      communityPostDetailProvider(widget.postId),
      (_, next) {
        final latest = next.asData?.value;
        if (latest == null || !mounted) {
          return;
        }
        setState(() {
          _detailState = latest;
        });
      },
    );
    final detail = _detailState ?? detailAsync.asData?.value;

    return Scaffold(
      backgroundColor: Colors.white,
      body: detail != null
          ? RefreshIndicator(
          color: AppTheme.electricIndigo,
          onRefresh: _refreshDetail,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                titleSpacing: 0,
                title: Row(
                  children: [
                    GestureDetector(
                      onTap: () =>
                          _openAuthorProfile(detail.post.author.userId),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: resolveAdaptiveImageProvider(
                          detail.post.author.avatarUrl,
                        ),
                        child:
                            detail.post.author.avatarUrl == null ||
                                detail.post.author.avatarUrl!.trim().isEmpty
                            ? const Icon(
                                Icons.person,
                                size: 18,
                                color: Colors.black45,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            _openAuthorProfile(detail.post.author.userId),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              detail.post.author.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '@${detail.post.author.username}',
                              style: TextStyle(
                                color: Colors.black.withOpacity(0.45),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  if (currentUser?.userId != detail.post.author.userId)
                    FollowActionButton(
                      targetUserId: detail.post.author.userId,
                      compact: true,
                      onChanged: () {
                        ref.invalidate(
                          userDetailProvider(detail.post.author.userId),
                        );
                      },
                    ),
                  if (currentUser?.userId == detail.post.author.userId)
                    PopupMenuButton<_PostMenuAction>(
                      enabled: !_deletingPost,
                      onSelected: (value) {
                        if (value == _PostMenuAction.delete) {
                          _deletePost(detail.post);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: _PostMenuAction.delete,
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                '删除帖子',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ],
                          ),
                        ),
                      ],
                      icon: _deletingPost
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.more_horiz_rounded),
                    ),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatFriendPickerScreen(
                            shareDraft: ChatComposerShareDraft.post(
                              postId: detail.post.post.postId,
                              title: detail.post.displayTitle,
                              summary: detail.post.post.content.trim(),
                              coverUrl: detail.post.coverImageUrl,
                              authorName: detail.post.author.displayName,
                            ),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.share_outlined),
                  ),
                ],
              ),
              SliverToBoxAdapter(child: _buildCarousel(detail.post)),
              SliverToBoxAdapter(child: _buildPostBody(detail.post)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                  child: Row(
                    children: [
                      _StatPill(
                        icon: detail.post.isLiked
                            ? Icons.favorite
                            : Icons.favorite_border,
                        label: _formatCount(detail.post.post.likeCount),
                        active: detail.post.isLiked,
                        onTap: _updatingPostAction
                            ? null
                            : () => _togglePostLike(detail.post),
                      ),
                      const SizedBox(width: 10),
                      _StatPill(
                        icon: detail.post.isFavorited
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        label: detail.post.isFavorited ? '已收藏' : '收藏',
                        active: detail.post.isFavorited,
                        onTap: _updatingPostAction
                            ? null
                            : () => _toggleFavorite(detail.post),
                      ),
                      const SizedBox(width: 10),
                      _StatPill(
                        icon: Icons.remove_red_eye_outlined,
                        label: _formatCount(detail.post.post.viewCount),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                  child: Row(
                    children: [
                      const Text(
                        '评论区',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${detail.post.post.commentCount}',
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.42),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (detail.comments.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 18, 20, 120),
                    child: _EmptyCommentState(),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  sliver: SliverList.builder(
                    itemCount: detail.comments.length,
                    itemBuilder: (context, index) {
                      final comment = detail.comments[index];
                      final isAnimated = _animatedCommentIds.contains(
                        comment.comment.commentId,
                      );
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == detail.comments.length - 1 ? 0 : 18,
                        ),
                        child: AnimatedSlide(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                          offset: isAnimated ? const Offset(0, 0.16) : Offset.zero,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOut,
                            opacity: isAnimated ? 0.45 : 1,
                            child: _CommentTile(
                              comment: comment,
                              loadingIds: _updatingComments,
                              animatedIds: _animatedCommentIds,
                              onReply: () => setState(() => _replyTarget = comment),
                              onToggleLike: _toggleCommentLike,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        )
          : detailAsync.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '帖子加载失败：${detailAsync.asError?.error}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black.withOpacity(0.5)),
            ),
          ),
        ),
      bottomNavigationBar: _buildComposer(),
    );
  }

  Widget _buildCarousel(CommunityPostView post) {
    final images = post.galleryImages;
    if (images.isEmpty) {
      return Container(
        height: 260,
        color: Colors.grey.shade100,
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_outlined,
          size: 42,
          color: Colors.black26,
        ),
      );
    }

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: AspectRatio(
            aspectRatio: _currentImageAspectRatio(post),
            child: PageView.builder(
              controller: _pageController,
              itemCount: images.length,
              onPageChanged: (index) => setState(() => _currentImage = index),
              itemBuilder: (context, index) {
                final imageUrl = images[index];
                return buildAdaptiveImage(
                  imageUrl,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  errorWidget: Container(
                    color: Colors.grey.shade100,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.black26,
                      size: 36,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (images.length > 1)
          Positioned(
            bottom: 16,
            child: Row(
              children: List.generate(images.length, (index) {
                final active = index == _currentImage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white54,
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildPostBody(CommunityPostView post) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.post.title != null &&
              post.post.title!.trim().isNotEmpty) ...[
            Text(
              post.post.title!.trim(),
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            post.post.content.trim().isEmpty
                ? '这条帖子还没有正文内容。'
                : post.post.content,
            style: TextStyle(
              color: Colors.black.withOpacity(0.78),
              fontSize: 15,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...post.post.tags.map(
                (tag) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.electricIndigo.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '#${tag.name}',
                    style: const TextStyle(
                      color: AppTheme.electricIndigo,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: post.post.isPublic
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  post.post.isPublic ? '公开' : '仅自己可见',
                  style: TextStyle(
                    color: post.post.isPublic
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${_formatTime(post.post.createdAt)} · 审核状态 ${post.post.auditStatus}',
            style: TextStyle(
              color: Colors.black.withOpacity(0.42),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    final replyLabel = _replyTarget == null
        ? null
        : '回复 ${_replyTarget!.author.displayName}';

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.black.withOpacity(0.06)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (replyLabel != null)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        replyLabel,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _replyTarget = null),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: _replyTarget == null
                          ? '写下你的评论...'
                          : '写下你的回复...',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _submittingComment ? null : _submitComment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.electricIndigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _submittingComment
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('发送'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePostLike(CommunityPostView post) async {
    final user = await _requireLogin();
    if (user == null) return;

    final targetLiked = !post.isLiked;
    _updateLocalDetail((detail) {
      final delta = targetLiked ? 1 : -1;
      return detail.copyWith(
        post: detail.post.copyWith(
          isLiked: targetLiked,
          post: detail.post.post.copyWith(
            likeCount: (detail.post.post.likeCount + delta).clamp(0, 1 << 31),
          ),
        ),
      );
    });
    setState(() => _updatingPostAction = true);
    try {
      await ref
          .read(communityRepositoryProvider)
          .setPostLiked(
            postId: post.post.postId,
            userId: user.userId,
            liked: targetLiked,
          );
      unawaited(
        _refreshAfterMutation(
          user.userId,
          affectedUserIds: {post.author.userId},
        ),
      );
    } catch (error) {
      _updateLocalDetail((detail) {
        final delta = targetLiked ? -1 : 1;
        return detail.copyWith(
          post: detail.post.copyWith(
            isLiked: post.isLiked,
            post: detail.post.post.copyWith(
              likeCount: (detail.post.post.likeCount + delta).clamp(0, 1 << 31),
            ),
          ),
        );
      });
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _updatingPostAction = false);
      }
    }
  }

  Future<void> _toggleFavorite(CommunityPostView post) async {
    final user = await _requireLogin();
    if (user == null) return;

    final targetFavorited = !post.isFavorited;
    _updateLocalDetail((detail) {
      return detail.copyWith(
        post: detail.post.copyWith(isFavorited: targetFavorited),
      );
    });
    setState(() => _updatingPostAction = true);
    try {
      await ref
          .read(communityRepositoryProvider)
          .setPostFavorited(
            postId: post.post.postId,
            userId: user.userId,
            favorited: targetFavorited,
          );
      unawaited(
        _refreshAfterMutation(
          user.userId,
          affectedUserIds: {post.author.userId},
        ),
      );
    } catch (error) {
      _updateLocalDetail((detail) {
        return detail.copyWith(post: detail.post.copyWith(isFavorited: post.isFavorited));
      });
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _updatingPostAction = false);
      }
    }
  }

  Future<void> _toggleCommentLike(CommunityCommentView comment) async {
    final user = await _requireLogin();
    if (user == null) return;

    final targetLiked = !comment.isLiked;
    _updateLocalComment(
      comment.comment.commentId,
      (current) => current.copyWith(
        isLiked: targetLiked,
        comment: current.comment.copyWith(
          likeCount: (current.comment.likeCount + (targetLiked ? 1 : -1)).clamp(
            0,
            1 << 31,
          ),
        ),
      ),
    );
    setState(() => _updatingComments.add(comment.comment.commentId));
    try {
      await ref
          .read(communityRepositoryProvider)
          .setCommentLiked(
            commentId: comment.comment.commentId,
            userId: user.userId,
            liked: targetLiked,
          );
      unawaited(
        _refreshAfterMutation(
          user.userId,
          affectedUserIds: {comment.author.userId},
        ),
      );
    } catch (error) {
      _updateLocalComment(
        comment.comment.commentId,
        (current) => current.copyWith(
          isLiked: comment.isLiked,
          comment: current.comment.copyWith(
            likeCount: (current.comment.likeCount + (targetLiked ? -1 : 1)).clamp(
              0,
              1 << 31,
            ),
          ),
        ),
      );
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _updatingComments.remove(comment.comment.commentId));
      }
    }
  }

  Future<void> _submitComment() async {
    final user = await _requireLogin();
    if (user == null) return;

    final text = _commentController.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() => _submittingComment = true);
    try {
      final createdComment = await ref
          .read(communityRepositoryProvider)
          .createComment(
            postId: widget.postId,
            userId: user.userId,
            content: text,
            parentId: _replyTarget?.comment.commentId,
          );
      final createdView = CommunityCommentView(
        comment: createdComment,
        author: CommunityAuthor.fromUser(user),
        isLiked: false,
        replies: const [],
      );
      _insertLocalComment(createdView);
      _commentController.clear();
      setState(() => _replyTarget = null);
      _animateCommentIn(createdComment.commentId);
      unawaited(
        _refreshAfterMutation(
          user.userId,
          affectedUserIds: {user.userId},
        ),
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _submittingComment = false);
      }
    }
  }

  Future<void> _deletePost(CommunityPostView post) async {
    final user = await _requireLogin();
    if (user == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('删除帖子'),
        content: const Text('删除后将无法恢复，帖子内容、评论和互动记录都会一起移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              '确认删除',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _deletingPost = true);
    try {
      await ref
          .read(communityRepositoryProvider)
          .deletePost(postId: post.post.postId, userId: user.userId);
      await _refreshAfterDelete(user.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('帖子已删除')));
      Navigator.of(context).pop(true);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _deletingPost = false);
      }
    }
  }

  Future<void> _refreshDetail() async {
    ref.invalidate(communityPostDetailProvider(widget.postId));
    final refreshed = await ref.read(communityPostDetailProvider(widget.postId).future);
    if (!mounted) return;
    setState(() {
      _detailState = refreshed;
    });
  }

  Future<void> _refreshAfterMutation(
    int userId, {
    Set<int> affectedUserIds = const <int>{},
  }) async {
    ref.invalidate(communityFavoritePostsProvider);
    ref.invalidate(communityPostsProvider);
    for (final affectedUserId in {...affectedUserIds, userId}) {
      ref.invalidate(userDetailProvider(affectedUserId));
    }
    await ref.read(authProvider.notifier).refreshUser();
  }

  Future<void> _refreshAfterDelete(int userId) async {
    ref.invalidate(communityPostDetailProvider);
    ref.invalidate(communityFavoritePostsProvider);
    ref.invalidate(communityPostsProvider);
    ref.invalidate(communityTagsProvider);
    ref.invalidate(userDetailProvider(userId));
    await ref.read(authProvider.notifier).refreshUser();
  }

  void _openAuthorProfile(int userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserDetailScreen(userId: userId)),
    );
  }

  Future<User?> _requireLogin() async {
    final user = ref.read(authProvider);
    if (user != null) {
      return user;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    return ref.read(authProvider);
  }

  void _showError(Object error) {
    String message = '操作失败，请稍后重试';
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic> && data['detail'] != null) {
        message = data['detail'].toString();
      } else if (error.message != null) {
        message = error.message!;
      }
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatCount(int value) {
    if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}w';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return '$value';
  }

  String _formatTime(DateTime time) {
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
  }

  double _currentImageAspectRatio(CommunityPostView post) {
    return post.imageAspectRatioAt(_currentImage) ??
        post.coverAspectRatio ??
        1.0;
  }

  void _updateLocalDetail(
    CommunityPostDetailData Function(CommunityPostDetailData detail) updater,
  ) {
    if (_detailState == null || !mounted) {
      return;
    }
    setState(() {
      _detailState = updater(_detailState!);
    });
  }

  void _updateLocalComment(
    int commentId,
    CommunityCommentView Function(CommunityCommentView current) updater,
  ) {
    _updateLocalDetail((detail) {
      return detail.copyWith(
        comments: detail.comments
            .map((comment) => _mapCommentTree(comment, commentId, updater))
            .toList(),
      );
    });
  }

  CommunityCommentView _mapCommentTree(
    CommunityCommentView current,
    int commentId,
    CommunityCommentView Function(CommunityCommentView current) updater,
  ) {
    if (current.comment.commentId == commentId) {
      return updater(current);
    }

    if (current.replies.isEmpty) {
      return current;
    }

    return current.copyWith(
      replies: current.replies
          .map((reply) => _mapCommentTree(reply, commentId, updater))
          .toList(),
    );
  }

  void _insertLocalComment(CommunityCommentView comment) {
    _updateLocalDetail((detail) {
      final updatedPost = detail.post.copyWith(
        post: detail.post.post.copyWith(
          commentCount: detail.post.post.commentCount + 1,
        ),
      );
      if (comment.comment.parentId == null) {
        return detail.copyWith(
          post: updatedPost,
          comments: [comment, ...detail.comments],
        );
      }

      final rootCommentId = comment.comment.rootId ?? comment.comment.parentId;
      final updatedComments = detail.comments.map((item) {
        if (item.comment.commentId != rootCommentId) {
          return item;
        }
        return item.copyWith(
          comment: item.comment.copyWith(
            replyCount: item.comment.replyCount + 1,
          ),
          replies: [comment, ...item.replies],
        );
      }).toList();

      return detail.copyWith(
        post: updatedPost,
        comments: updatedComments,
      );
    });
  }

  void _animateCommentIn(int commentId) {
    if (!mounted) {
      return;
    }
    setState(() => _animatedCommentIds.add(commentId));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 24), () {
        if (!mounted) {
          return;
        }
        setState(() => _animatedCommentIds.remove(commentId));
      });
    });
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.electricIndigo : Colors.black87;
    return Material(
      color: active
          ? AppTheme.electricIndigo.withOpacity(0.08)
          : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.loadingIds,
    required this.animatedIds,
    required this.onReply,
    required this.onToggleLike,
  });

  final CommunityCommentView comment;
  final Set<int> loadingIds;
  final Set<int> animatedIds;
  final VoidCallback onReply;
  final ValueChanged<CommunityCommentView> onToggleLike;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommentBubble(
          comment: comment,
          isLoading: loadingIds.contains(comment.comment.commentId),
          isAnimated: animatedIds.contains(comment.comment.commentId),
          onReply: comment.comment.level == 1 ? onReply : null,
          onToggleLike: () => onToggleLike(comment),
        ),
        if (comment.replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 42, top: 12),
            child: Column(
              children: comment.replies.map((reply) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CommentBubble(
                    comment: reply,
                    isLoading: loadingIds.contains(reply.comment.commentId),
                    isAnimated: animatedIds.contains(reply.comment.commentId),
                    onToggleLike: () => onToggleLike(reply),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _CommentBubble extends StatelessWidget {
  const _CommentBubble({
    required this.comment,
    required this.isLoading,
    required this.isAnimated,
    required this.onToggleLike,
    this.onReply,
  });

  final CommunityCommentView comment;
  final bool isLoading;
  final bool isAnimated;
  final VoidCallback onToggleLike;
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isAnimated
            ? AppTheme.electricIndigo.withOpacity(0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: resolveAdaptiveImageProvider(
              comment.author.avatarUrl,
            ),
            child:
                comment.author.avatarUrl == null ||
                    comment.author.avatarUrl!.trim().isEmpty
                ? const Icon(Icons.person, size: 16, color: Colors.black38)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.author.displayName,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.56),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  comment.comment.content,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '${comment.comment.createdAt.month}-${comment.comment.createdAt.day}',
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.38),
                        fontSize: 11,
                      ),
                    ),
                    if (onReply != null) ...[
                      const SizedBox(width: 14),
                      GestureDetector(
                        onTap: onReply,
                        child: const Text(
                          '回复',
                          style: TextStyle(
                            color: AppTheme.electricIndigo,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: isLoading ? null : onToggleLike,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                children: [
                  if (isLoading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      comment.isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 16,
                      color: comment.isLiked
                          ? AppTheme.electricIndigo
                          : Colors.black38,
                    ),
                  const SizedBox(height: 2),
                  Text(
                    '${comment.comment.likeCount}',
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.4),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCommentState extends StatelessWidget {
  const _EmptyCommentState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.chat_bubble_outline,
          size: 42,
          color: Colors.black.withOpacity(0.14),
        ),
        const SizedBox(height: 12),
        const Text(
          '还没有评论',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '来写下第一条评论，把讨论带起来。',
          style: TextStyle(color: Colors.black.withOpacity(0.44), fontSize: 13),
        ),
      ],
    );
  }
}

enum _PostMenuAction { delete }
