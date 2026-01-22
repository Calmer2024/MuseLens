import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../widgets/community/community_search_bar.dart';
import '../../widgets/community/community_post_card.dart';
import '../../../data/models/community_post_mock.dart';
import '../../../core/theme/app_theme.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final posts = CommunityPostMock.getMockPosts();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  // 1. 顶部搜索栏
                  const CommunitySearchBar(),
                  const SizedBox(height: 20),

                  // 2. 瀑布流内容
                  Expanded(
                    child: MasonryGridView.count(
                      crossAxisCount: 2, // 两列
                      mainAxisSpacing: 16, // 垂直间距
                      crossAxisSpacing: 16, // 水平间距
                      itemCount: posts.length,
                      // 底部留白，防止被悬浮导航栏遮挡
                      padding: const EdgeInsets.only(bottom: 120),
                      itemBuilder: (context, index) {
                        return CommunityPostCard(post: posts[index]);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. 悬浮加号按钮 (Floating Action Button)
          // 原型图中按钮在右下角，位于导航栏上方
          Positioned(
            bottom: 110, // 位于导航栏(70) + 间距(30) 上方
            right: 20,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF6A5AE0), Color(0xFF9666FF)], // 紫色渐变
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryPurple.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    print("Create Post Clicked");
                  },
                  child: const Icon(Icons.add, color: Colors.white, size: 32),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
