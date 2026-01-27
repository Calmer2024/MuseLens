import 'package:flutter/material.dart';
import 'dart:ui'; // 用于 ImageFilter
import '../../../core/theme/app_theme.dart';
import '../../../data/models/lens_template_mock.dart';

class LensDetailScreen extends StatefulWidget {
  final LensTemplateMock template;

  const LensDetailScreen({super.key, required this.template});

  @override
  State<LensDetailScreen> createState() => _LensDetailScreenState();
}

class _LensDetailScreenState extends State<LensDetailScreen> {
  double _splitValue = 0.5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInteractiveSlider(context),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.template.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (widget.template.isOfficial)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.amber),
                                borderRadius: BorderRadius.circular(6),
                                color: Colors.amber.withOpacity(0.1),
                              ),
                              child: const Text(
                                "PRO",
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.grey[800],
                            child: ClipOval(
                              child: Image.network(
                                widget.template.authorAvatar,
                                width: 32,
                                height: 32,
                                fit: BoxFit.cover,
                                headers: const {'User-Agent': 'Mozilla/5.0'},
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 20,
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.template.author,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                "Digital Artist",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.electricIndigo,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.electricIndigo.withOpacity(
                                    0.4,
                                  ),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Text(
                              "Follow",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.05),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatItem("4.5★", "Rating"),
                            _buildDivider(),
                            _buildStatItem(widget.template.usageCount, "Uses"),
                            _buildDivider(),
                            _buildStatItem("35MB", "Model"),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        "Workflow DNA",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildDnaCard(
                              1,
                              Icons.face_retouching_natural,
                              "FaceID",
                            ),
                            _buildDnaCard(2, Icons.light_mode, "Relight"),
                            _buildDnaCard(3, Icons.brush, "Style Transfer"),
                            _buildDnaCard(4, Icons.auto_fix_high, "Upscale"),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: ClipOval(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            width: 44,
                            height: 44,
                            color: Colors.black.withOpacity(0.3),
                            child: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        _buildGlassIcon(Icons.share),
                        const SizedBox(width: 12),
                        _buildGlassIcon(Icons.more_horiz),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {},
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppTheme.electricIndigo,
                                  Color(0xFF8E2DE2),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.electricIndigo.withOpacity(
                                    0.4,
                                  ),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.auto_fix_normal,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  "Apply to Image",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite_border,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveSlider(BuildContext context) {
    final double height = MediaQuery.of(context).size.height * 0.55;

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. After Image (智能加载)
          _buildSmartImage(
            widget.template.afterImage,
            color: AppTheme.electricIndigo.withOpacity(0.1),
            blendMode: BlendMode.colorBurn,
          ),

          // 2. Before Image (智能加载 + 裁剪)
          ClipRect(
            clipper: _SliderClipper(_splitValue),
            child: _buildSmartImage(
              widget.template.beforeImage,
              color: Colors.black.withOpacity(0.3),
              blendMode: BlendMode.darken,
            ),
          ),

          // 3. 分割线
          Positioned(
            left: MediaQuery.of(context).size.width * _splitValue - 1.5,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 5,
                  ),
                ],
              ),
            ),
          ),

          // 4. 手柄
          Positioned(
            left: MediaQuery.of(context).size.width * _splitValue - 40,
            top: height / 2 - 20,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  double newValue =
                      details.globalPosition.dx /
                      MediaQuery.of(context).size.width;
                  _splitValue = newValue.clamp(0.0, 1.0);
                });
              },
              child: Container(
                width: 80,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      "Before",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    VerticalDivider(width: 8, color: Colors.grey),
                    Text(
                      "After",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 智能图片加载方法 ---
  Widget _buildSmartImage(String path, {Color? color, BlendMode? blendMode}) {
    if (path.startsWith('http')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        color: color,
        colorBlendMode: blendMode,
        headers: const {'User-Agent': 'Mozilla/5.0'},
        errorBuilder: (context, error, stackTrace) => Container(
          color: const Color(0xFF2A2A2A),
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.white24),
          ),
        ),
      );
    } else {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        color: color,
        colorBlendMode: blendMode,
        errorBuilder: (context, error, stackTrace) =>
            Container(color: const Color(0xFF2A2A2A)),
      );
    }
  }

  // --- 辅助组件 ---
  Widget _buildGlassIcon(IconData icon) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 44,
          height: 44,
          color: Colors.black.withOpacity(0.3),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildDivider() =>
      Container(width: 1, height: 24, color: Colors.white.withOpacity(0.1));

  Widget _buildDnaCard(int index, IconData icon, String label) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.electricIndigo.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.electricIndigo.withOpacity(0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 8,
            left: 10,
            child: Text(
              "$index",
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppTheme.electricIndigo, size: 28),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
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

class _SliderClipper extends CustomClipper<Rect> {
  final double splitValue;
  _SliderClipper(this.splitValue);
  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, 0, size.width * splitValue, size.height);
  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) => true;
}
