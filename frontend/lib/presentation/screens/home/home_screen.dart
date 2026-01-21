import 'package:flutter/material.dart';
import '../../widgets/home/hero_create_card.dart';
import '../../widgets/home/recipe_list_item.dart';
import '../../../data/models/recipe_mock.dart';
import '../../../core/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 获取 Mock 数据
    final recipes = RecipeMock.getRecentRecipes();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false, // 让内容延伸到底部，因为导航栏是悬浮的
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. Top Header ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Good morning, Creator",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  // Avatar
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                      image: const DecorationImage(
                        image: NetworkImage(
                          "https://i.pravatar.cc/150?img=12",
                        ), // 随机头像
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // --- 2. Hero Section (Start Creating) ---
              const HeroCreateCard(),

              const SizedBox(height: 30),

              // --- 3. My Recent Recipes Section ---
              const Text(
                "My Recent Recipes",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 16),

              // Horizontal Carousel
              SizedBox(
                height: 180, // 卡片高度
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: recipes.length,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    return RecipeListItem(recipe: recipes[index]);
                  },
                ),
              ),

              // 底部留白，防止被悬浮导航栏遮挡
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}
