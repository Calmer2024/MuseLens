import 'package:flutter/material.dart';
import '../../../data/models/recipe_mock.dart';
import '../../../core/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';

class RecipeListItem extends StatelessWidget {
  final RecipeMock recipe;

  const RecipeListItem({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140, // 原型图中是偏方形的
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.transparent,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 图片背景
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: ShaderMask(
              shaderCallback: (rect) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ).createShader(
                  Rect.fromLTRB(0, rect.height * 0.5, rect.width, rect.height),
                );
              },
              blendMode: BlendMode.srcOver,
              child: CachedNetworkImage(
                imageUrl: recipe.imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: AppTheme.cardSurface),
              ),
            ),
          ),

          // 底部文字和图标
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: Colors.white.withOpacity(0.8),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    recipe.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
