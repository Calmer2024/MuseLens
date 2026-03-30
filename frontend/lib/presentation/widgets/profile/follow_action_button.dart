import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';
import '../../screens/auth/login_screen.dart';

class FollowActionButton extends ConsumerStatefulWidget {
  const FollowActionButton({
    super.key,
    required this.targetUserId,
    this.compact = false,
    this.hideForSelf = true,
    this.onChanged,
  });

  final int targetUserId;
  final bool compact;
  final bool hideForSelf;
  final VoidCallback? onChanged;

  @override
  ConsumerState<FollowActionButton> createState() => _FollowActionButtonState();
}

class _FollowActionButtonState extends ConsumerState<FollowActionButton> {
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider);
    final isMe = currentUser?.userId == widget.targetUserId;
    if (widget.hideForSelf && isMe) {
      return const SizedBox.shrink();
    }

    final isFollowingAsync = ref.watch(userIsFollowingProvider(widget.targetUserId));
    final isFollowing = isFollowingAsync.value ?? false;
    final label = isFollowing ? context.tr('following_state') : context.tr('follow');
    final backgroundColor = Colors.white;
    final textColor = isFollowing ? Colors.black87 : AppTheme.electricIndigo;
    final borderColor = isFollowing
        ? const Color(0xFFD9D9DE)
        : AppTheme.electricIndigo;

    return GestureDetector(
      onTap: _submitting ? null : () => _handleTap(currentUser, isFollowing),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? 12 : 18,
          vertical: widget.compact ? 7 : 10,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(widget.compact ? 16 : 22),
          border: Border.all(
            color: borderColor,
          ),
          boxShadow: const [],
        ),
        child: _submitting
            ? SizedBox(
                width: widget.compact ? 14 : 16,
                height: widget.compact ? 14 : 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: textColor,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: textColor,
                      fontSize: widget.compact ? 12 : 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _handleTap(User? currentUser, bool isFollowing) async {
    if (currentUser == null) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final apiService = ref.read(userApiServiceProvider);
      if (isFollowing) {
        await apiService.unfollowUser(widget.targetUserId, currentUser.userId);
      } else {
        await apiService.followUser(widget.targetUserId, currentUser.userId);
      }

      ref.invalidate(userIsFollowingProvider(widget.targetUserId));
      ref.invalidate(userDetailProvider(widget.targetUserId));
      ref.invalidate(userDetailProvider(currentUser.userId));
      ref.invalidate(followersProvider(widget.targetUserId));
      ref.invalidate(followingProvider(currentUser.userId));
      await ref.read(authProvider.notifier).refreshUser();
      widget.onChanged?.call();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}
