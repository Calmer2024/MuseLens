import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/chat_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/chat_models.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../widgets/shared/adaptive_media.dart';
import '../auth/login_screen.dart';
import '../lens/market_lens_detail_screen.dart';
import 'community_post_detail_screen.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  const ChatDetailScreen({
    super.key,
    required this.conversationId,
    this.initialShareDraft,
  });

  final int conversationId;
  final ChatComposerShareDraft? initialShareDraft;

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  ChatConversation? _conversation;
  List<ChatMessage> _messages = const [];
  ChatComposerShareDraft? _pendingShare;
  bool _loading = true;
  bool _loadingMore = false;
  bool _sending = false;
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    _pendingShare = widget.initialShareDraft;
    Future<void>.microtask(_loadInitial);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    var currentUser = ref.read(authProvider);
    if (currentUser == null) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (!mounted) return;
      currentUser = ref.read(authProvider);
      if (currentUser == null) {
        setState(() => _loading = false);
        return;
      }
    }

    setState(() => _loading = true);
    try {
      final repository = ref.read(chatRepositoryProvider);
      final results = await Future.wait<dynamic>([
        repository.getConversationDetail(
          conversationId: widget.conversationId,
          userId: currentUser.userId,
        ),
        repository.listMessages(
          conversationId: widget.conversationId,
          userId: currentUser.userId,
          limit: 50,
        ),
      ]);
      if (!mounted) return;
      final page = results[1] as ChatMessagePage;
      setState(() {
        _conversation = results[0] as ChatConversation;
        _messages = page.messages;
        _hasMore = page.hasMore;
      });
      await _markReadIfNeeded();
      _scrollToBottom(jump: true);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    final currentUser = ref.read(authProvider);
    if (currentUser == null ||
        _loadingMore ||
        !_hasMore ||
        _messages.isEmpty) {
      return;
    }

    setState(() => _loadingMore = true);
    try {
      final page = await ref.read(chatRepositoryProvider).listMessages(
            conversationId: widget.conversationId,
            userId: currentUser.userId,
            limit: 30,
            beforeMessageId: _messages.first.messageId,
          );
      if (!mounted) return;
      setState(() {
        _messages = [...page.messages, ..._messages];
        _hasMore = page.hasMore;
      });
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _refreshConversation() async {
    await _loadInitial();
    ref.invalidate(chatConversationsProvider);
    ref.invalidate(chatConversationDetailProvider(widget.conversationId));
  }

  Future<void> _markReadIfNeeded() async {
    final currentUser = ref.read(authProvider);
    final lastMessage = _messages.isNotEmpty ? _messages.last : null;
    if (currentUser == null ||
        lastMessage == null ||
        lastMessage.senderId == currentUser.userId) {
      return;
    }

    try {
      await ref.read(chatRepositoryProvider).markConversationRead(
            conversationId: widget.conversationId,
            userId: currentUser.userId,
            lastReadMessageId: lastMessage.messageId,
          );
      ref.invalidate(chatConversationsProvider);
      ref.invalidate(chatConversationDetailProvider(widget.conversationId));
    } catch (_) {}
  }

  Future<void> _send() async {
    var currentUser = ref.read(authProvider);
    if (currentUser == null) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      currentUser = ref.read(authProvider);
      if (currentUser == null) {
        return;
      }
    }

    final text = _textController.text.trim();
    if (text.isEmpty && _pendingShare == null) {
      return;
    }

    setState(() => _sending = true);
    try {
      final message = await ref.read(chatRepositoryProvider).sendMessage(
            conversationId: widget.conversationId,
            senderId: currentUser.userId,
            content: text,
            share: _pendingShare?.share,
          );
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, message];
        _pendingShare = null;
      });
      _textController.clear();
      ref.invalidate(chatConversationsProvider);
      ref.invalidate(chatFriendsProvider);
      ref.invalidate(chatConversationDetailProvider(widget.conversationId));
      await _refreshHeader();
      _scrollToBottom();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _refreshHeader() async {
    final currentUser = ref.read(authProvider);
    if (currentUser == null) return;

    try {
      final detail = await ref.read(chatRepositoryProvider).getConversationDetail(
            conversationId: widget.conversationId,
            userId: currentUser.userId,
          );
      if (!mounted) return;
      setState(() => _conversation = detail);
    } catch (_) {}
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      final offset = _scrollController.position.maxScrollExtent;
      if (jump) {
        _scrollController.jumpTo(offset);
        return;
      }
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _openShareTarget(ChatMessageShare share) {
    if (share.shareSourceType == 'community_post') {
      final postId =
          int.tryParse(share.resourceId) ?? _intFromDynamic(share.metadata['post_id']);
      if (postId == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CommunityPostDetailScreen(postId: postId),
        ),
      );
      return;
    }

    if (share.shareSourceType == 'market_lens') {
      final lensId = int.tryParse(share.resourceId) ??
          _intFromDynamic(share.metadata['market_lens_id']);
      if (lensId == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MarketLensDetailScreen(lensId: lensId),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('资产树预设详情入口稍后补充')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider);
    final conversation = _conversation;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
        titleSpacing: 0,
        title: conversation == null
            ? const Text('聊天中')
            : Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage:
                        resolveAdaptiveImageProvider(conversation.peerUser.avatarUrl),
                    child: conversation.peerUser.avatarUrl == null ||
                            conversation.peerUser.avatarUrl!.trim().isEmpty
                        ? const Icon(Icons.person, size: 18, color: Colors.black38)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                conversation.peerUser.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            if (conversation.peerUser.isVerified) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.verified_rounded,
                                size: 15,
                                color: AppTheme.electricIndigo,
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '@${conversation.peerUser.username}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.black.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      color: AppTheme.electricIndigo,
                      onRefresh: _refreshConversation,
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        itemCount: _messages.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            if (!_hasMore && !_loadingMore) {
                              return const SizedBox(height: 8);
                            }
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: TextButton(
                                  onPressed: _loadingMore ? null : _loadMore,
                                  child: _loadingMore
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('加载更早的消息'),
                                ),
                              ),
                            );
                          }

                          final message = _messages[index - 1];
                          final isMe = currentUser?.userId == message.senderId;
                          final peerUser = conversation?.peerUser;
                          return _ChatMessageTile(
                            message: message,
                            isMe: isMe,
                            peerAvatarUrl: peerUser?.avatarUrl,
                            onTapShare: message.share == null
                                ? null
                                : () => _openShareTarget(message.share!),
                          );
                        },
                      ),
                    ),
            ),
            _ComposerPanel(
              controller: _textController,
              sending: _sending,
              pendingShare: _pendingShare,
              onRemoveShare: () => setState(() => _pendingShare = null),
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }

  void _showError(Object error) {
    String message = '聊天操作失败，请稍后重试';
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic> && data['detail'] != null) {
        message = data['detail'].toString();
      } else if (error.message != null) {
        message = error.message!;
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ChatMessageTile extends StatelessWidget {
  const _ChatMessageTile({
    required this.message,
    required this.isMe,
    required this.peerAvatarUrl,
    this.onTapShare,
  });

  final ChatMessage message;
  final bool isMe;
  final String? peerAvatarUrl;
  final VoidCallback? onTapShare;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: resolveAdaptiveImageProvider(peerAvatarUrl),
              child: peerAvatarUrl == null || peerAvatarUrl!.trim().isEmpty
                  ? const Icon(Icons.person, size: 16, color: Colors.black38)
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (message.content.trim().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: isMe ? AppTheme.electricIndigo : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 6),
                        bottomRight: Radius.circular(isMe ? 6 : 18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Text(
                      message.content,
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black87,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ),
                if (message.share != null) ...[
                  if (message.content.trim().isNotEmpty)
                    const SizedBox(height: 8),
                  _ChatShareCard(
                    share: message.share!,
                    isMe: isMe,
                    onTap: onTapShare,
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.black.withValues(alpha: 0.38),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatShareCard extends StatelessWidget {
  const _ChatShareCard({
    required this.share,
    required this.isMe,
    this.onTap,
  });

  final ChatMessageShare share;
  final bool isMe;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final badgeLabel = share.shareType == 'post' ? '帖子分享' : '预设分享';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: 252,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isMe
                  ? AppTheme.electricIndigo.withValues(alpha: 0.28)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              _ShareCover(coverUrl: share.coverUrl, shareType: share.shareType),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.electricIndigo.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badgeLabel,
                        style: const TextStyle(
                          color: AppTheme.electricIndigo,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      share.title.trim().isEmpty ? '未命名分享' : share.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      share.summary.trim().isEmpty
                          ? '点击查看分享详情'
                          : share.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.58),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    if ((share.authorName ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        share.authorName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.42),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComposerPanel extends StatelessWidget {
  const _ComposerPanel({
    required this.controller,
    required this.sending,
    required this.pendingShare,
    required this.onRemoveShare,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final ChatComposerShareDraft? pendingShare;
  final VoidCallback onRemoveShare;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        14,
        12,
        14,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pendingShare != null)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.electricIndigo.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppTheme.electricIndigo.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                children: [
                  _ShareCover(
                    coverUrl: pendingShare!.coverUrl,
                    shareType: pendingShare!.share.shareType,
                    compact: true,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pendingShare!.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pendingShare!.summary.trim().isEmpty
                              ? '发送这条分享'
                              : pendingShare!.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.52),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onRemoveShare,
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3FB),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: '发消息...',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 46,
                height: 46,
                child: ElevatedButton(
                  onPressed: sending ? null : onSend,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: AppTheme.electricIndigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShareCover extends StatelessWidget {
  const _ShareCover({
    required this.coverUrl,
    required this.shareType,
    this.compact = false,
  });

  final String? coverUrl;
  final String shareType;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 44.0 : 58.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(compact ? 12 : 16),
      child: Container(
        width: size,
        height: size,
        color: const Color(0xFFF2EFFF),
        child: coverUrl != null && coverUrl!.trim().isNotEmpty
            ? buildAdaptiveImage(
                coverUrl,
                fit: BoxFit.cover,
                width: size,
                height: size,
                errorWidget: _ShareFallbackIcon(
                  compact: compact,
                  shareType: shareType,
                ),
              )
            : _ShareFallbackIcon(compact: compact, shareType: shareType),
      ),
    );
  }
}

class _ShareFallbackIcon extends StatelessWidget {
  const _ShareFallbackIcon({
    required this.compact,
    required this.shareType,
  });

  final bool compact;
  final String shareType;

  @override
  Widget build(BuildContext context) {
    return Icon(
      shareType == 'post' ? Icons.article_outlined : Icons.auto_awesome,
      size: compact ? 18 : 24,
      color: AppTheme.electricIndigo,
    );
  }
}

String _formatTime(DateTime time) {
  final local = time.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

int? _intFromDynamic(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}
