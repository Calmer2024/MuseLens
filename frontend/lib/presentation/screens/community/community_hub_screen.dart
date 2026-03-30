import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/community_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/community_models.dart';
import '../../widgets/community/community_post_card.dart';
import '../profile/user_detail_screen.dart';
import '../auth/login_screen.dart';
import 'chat_detail_screen.dart';
import 'package:image_picker/image_picker.dart' as image_picker;
import 'community_post_detail_screen.dart';
import 'create_post_screen.dart';
import 'search_screen.dart';

class CommunityHubScreen extends ConsumerStatefulWidget {
  const CommunityHubScreen({super.key});

  @override
  ConsumerState<CommunityHubScreen> createState() => _CommunityHubScreenState();
}

class _CommunityHubScreenState extends ConsumerState<CommunityHubScreen>
    with SingleTickerProviderStateMixin {
  static const _allPostsQuery = CommunityPostQuery();

  late final TabController _tabController;
  int _currentTab = 0;
  String? _selectedTag;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {
          _currentTab = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = CommunityPostQuery(tagName: _selectedTag);
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _currentTab == 0 ? _buildCreateButton() : null,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCircleButton(
                    icon: Icons.local_fire_department_outlined,
                    onTap: () => setState(() => _selectedTag = null),
                  ),
                  _buildHeaderTabs(),
                  _buildCircleButton(icon: Icons.search, onTap: _openSearch),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: [
                  _DiscoverTab(
                    selectedTag: _selectedTag,
                    query: query,
                    onSelectTag: (tag) => setState(() => _selectedTag = tag),
                    onOpenPost: _openPostDetail,
                    onOpenAuthor: _openAuthorProfile,
                    onRefreshAll: () {
                      ref.invalidate(communityTagsProvider);
                      ref.invalidate(communityPostsProvider(_allPostsQuery));
                      ref.invalidate(communityPostsProvider(query));
                    },
                  ),
                  const _MessagesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderTabs() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: 156,
          height: 42,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.62)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                alignment: _currentTab == 0
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Container(
                  width: 74,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD9D1FF), Color(0xFFF3EFFF)],
                    ),
                    border: Border.all(
                      color: AppTheme.electricIndigo.withValues(alpha: 0.22),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.electricIndigo.withValues(alpha: 0.16),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(child: _buildTabItem(0, '发现')),
                  Expanded(child: _buildTabItem(1, '消息')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, String label) {
    final isActive = _currentTab == index;
    return GestureDetector(
      onTap: () => _tabController.animateTo(index),
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: isActive
                ? AppTheme.electricIndigo
                : Colors.black.withValues(alpha: 0.55),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.black87, size: 18),
      ),
    );
  }

  Widget _buildCreateButton() {
    return Padding(
      padding: const EdgeInsets.only(right: 2, bottom: 84),
      child: Material(
        color: AppTheme.electricIndigo,
        shape: const CircleBorder(),
        elevation: 8,
        shadowColor: AppTheme.electricIndigo.withValues(alpha: 0.4),
        child: InkWell(
          onTap: _openCreatePost,
          customBorder: const CircleBorder(),
          child: Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
          ),
        ),
      ),
    );
  }

  Future<void> _openSearch() async {
    final selected = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => SearchScreen(initialKeyword: _selectedTag),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _selectedTag = selected.trim().isEmpty ? null : selected.trim();
      });
    }
  }

  Future<void> _openCreatePost() async {
    final currentUser = ref.read(authProvider);
    if (currentUser == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    final picker = image_picker.ImagePicker();
    final pickedFiles = await picker.pickMultiImage();

    if (pickedFiles.isEmpty || !mounted) return;

    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePostScreen(initialImages: pickedFiles),
      ),
    );

    if (created == true) {
      ref.invalidate(communityPostsProvider(_allPostsQuery));
      ref.invalidate(
        communityPostsProvider(CommunityPostQuery(tagName: _selectedTag)),
      );
      ref.invalidate(communityTagsProvider);
    }
  }

  void _openPostDetail(CommunityPostView post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityPostDetailScreen(postId: post.post.postId),
      ),
    );
  }

  void _openAuthorProfile(CommunityPostView post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserDetailScreen(userId: post.author.userId),
      ),
    );
  }
}

class _DiscoverTab extends ConsumerWidget {
  const _DiscoverTab({
    required this.selectedTag,
    required this.query,
    required this.onSelectTag,
    required this.onOpenPost,
    required this.onOpenAuthor,
    required this.onRefreshAll,
  });

  final String? selectedTag;
  final CommunityPostQuery query;
  final ValueChanged<String?> onSelectTag;
  final ValueChanged<CommunityPostView> onOpenPost;
  final ValueChanged<CommunityPostView> onOpenAuthor;
  final VoidCallback onRefreshAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(communityTagsProvider);
    final postsAsync = ref.watch(communityPostsProvider(query));

    return Column(
      children: [
        SizedBox(
          height: 52,
          child: tagsAsync.when(
            data: (tags) => ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _TagChip(
                  label: '全部',
                  isActive: selectedTag == null,
                  onTap: () => onSelectTag(null),
                ),
                const SizedBox(width: 8),
                ...tags
                    .take(12)
                    .map(
                      (tag) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _TagChip(
                          label: '#${tag.name}',
                          subtitle: '${tag.postCount}',
                          isActive: selectedTag == tag.name,
                          onTap: () => onSelectTag(tag.name),
                        ),
                      ),
                    ),
              ],
            ),
            loading: () => const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppTheme.electricIndigo,
            onRefresh: () async {
              onRefreshAll();
              await ref.read(communityPostsProvider(query).future);
            },
            child: postsAsync.when(
              data: (posts) {
                if (posts.isEmpty) {
                  return const _EmptyList(
                    title: '这里还没有内容',
                    description: '换个标签看看，或者发第一条帖子把灵感点亮。',
                  );
                }
                return MasonryGridView.count(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return CommunityPostCard(
                      post: post,
                      onTap: () => onOpenPost(post),
                      onAuthorTap: () => onOpenAuthor(post),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  _EmptyList(title: '加载失败', description: '$error'),
            ),
          ),
        ),
      ],
    );
  }
}

class _MessagesTab extends StatelessWidget {
  const _MessagesTab();

  @override
  Widget build(BuildContext context) {
    const items = [
      _MessageItemData(
        name: 'MuseLens 官方小助手',
        avatar: 'assets/images/logo.png',
        message: '现在社区帖子、评论、点赞、收藏都已经接入后端了，可以直接试用。',
        time: '刚刚',
        isOfficial: true,
        isLocalImage: true,
      ),
      _MessageItemData(
        name: 'Tim',
        avatar: 'assets/images/profile.png',
        message: '夜景那个标签页终于不是摆设了，我已经刷到你的帖子了。',
        time: '昨天',
        isLocalImage: true,
      ),
      _MessageItemData(
        name: '设计大师',
        avatar: 'assets/images/profile.png',
        message: '你下次发作品记得叫我，我想试试评论回复。',
        time: '周一',
        isLocalImage: true,
      ),
    ];

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatDetailScreen(
                  userName: item.name,
                  avatarUrl: item.avatar,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black.withOpacity(0.05)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.grey.shade100,
                      child: ClipOval(
                        child: item.isLocalImage
                            ? Image.asset(
                                item.avatar,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                              )
                            : Image.network(
                                item.avatar,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.person),
                              ),
                      ),
                    ),
                    if (item.isOfficial)
                      const Positioned(
                        right: 0,
                        bottom: 0,
                        child: Icon(
                          Icons.verified_rounded,
                          color: AppTheme.electricIndigo,
                          size: 16,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Text(
                            item.time,
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.4),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.62),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.onTap,
    this.subtitle,
    this.isActive = false,
  });

  final String label;
  final String? subtitle;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFE7DEFF) : const Color(0xFFF5F0FF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive
                ? AppTheme.electricIndigo
                : AppTheme.electricIndigo.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? AppTheme.electricIndigo
                    : const Color(0xFF6D5AE6),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(width: 6),
              Text(
                subtitle!,
                style: TextStyle(
                  color: isActive
                      ? AppTheme.electricIndigo.withValues(alpha: 0.78)
                      : AppTheme.electricIndigo.withValues(alpha: 0.66),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 90, 24, 120),
      children: [
        Icon(
          Icons.auto_awesome_mosaic_outlined,
          size: 52,
          color: Colors.black.withOpacity(0.14),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black.withOpacity(0.48),
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _MessageItemData {
  final String name;
  final String avatar;
  final String message;
  final String time;
  final bool isOfficial;
  final bool isLocalImage;

  const _MessageItemData({
    required this.name,
    required this.avatar,
    required this.message,
    required this.time,
    this.isOfficial = false,
    this.isLocalImage = false,
  });
}
