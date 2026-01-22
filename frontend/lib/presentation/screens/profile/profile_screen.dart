import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/profile_mock.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final creations = ProfileCreationMock.getCreations();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), // 比纯黑稍微浅一点点的哑光黑
      body: Stack(
        children: [
          // 背景微光 (可选，增加氛围)
          Positioned(
            top: -100,
            left: 0,
            right: 0,
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 0.8,
                  colors: [
                    AppTheme.electricIndigo.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 10),

                  // --- 1. Header (Title & Settings) ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 40), // 占位，保持 Title 居中
                      const Text(
                        "Profile",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      // Settings Icon (Glassmorphic)
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: const Icon(
                          Icons.settings_outlined,
                          color: AppTheme.electricIndigo,
                          size: 20,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // --- 2. User Info (Avatar & Glow) ---
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.electricIndigo.withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: -5,
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(3), // 边框宽度
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppTheme.electricIndigo, Color(0xFF8E2DE2)],
                        ),
                      ),
                      child: const CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.black,
                        backgroundImage: NetworkImage(
                          "https://i.pravatar.cc/300?img=12",
                        ), // 用户头像
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    "Alex Creator",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "@alex_makes_art",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "AI art enthusiast & style explorer.",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- 3. Edit Profile Button ---
                  Container(
                    width: 200,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        colors: [AppTheme.electricIndigo, Color(0xFF584CF4)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.electricIndigo.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        "Edit Profile",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- 4. Stats Row ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatItem("1.2k", "Followers"),
                      _buildStatItem("85", "Following"),
                      _buildStatItem("4.5k", "Likes"),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // --- 5. Tabs ---
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _TabItem(label: "My Recipes", isActive: true),
                      _TabItem(label: "Saved", isActive: false),
                      _TabItem(label: "About", isActive: false),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // --- 6. Content Grid ---
                  // 使用 GridView.builder
                  GridView.builder(
                    shrinkWrap: true, // 关键：允许在 ScrollView 中嵌套
                    physics:
                        const NeverScrollableScrollPhysics(), // 禁用 Grid 自身滚动
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75, // 调整长宽比以匹配原型图
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemCount: creations.length,
                    padding: const EdgeInsets.only(bottom: 120), // 避开底部导航栏
                    itemBuilder: (context, index) {
                      return _buildGridItem(creations[index]);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildStatItem(String count, String label) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Dark Charcoal
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(ProfileCreationMock item) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF1E1E1E),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: CachedNetworkImage(
                imageUrl: item.imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (context, url) =>
                    Container(color: const Color(0xFF2C2C2C)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              item.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final bool isActive;

  const _TabItem({required this.label, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white.withOpacity(0.5),
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 6),
        // Active Indicator
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 3,
          width: isActive ? 40 : 0,
          decoration: BoxDecoration(
            color: AppTheme.electricIndigo,
            borderRadius: BorderRadius.circular(2),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppTheme.electricIndigo.withOpacity(0.6),
                      blurRadius: 8,
                    ),
                  ]
                : [],
          ),
        ),
      ],
    );
  }
}
