import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/lens_template_mock.dart';
import '../../screens/lens/lens_detail_screen.dart';

class LensMarketCard extends StatelessWidget {
  final LensTemplateMock template;

  const LensMarketCard({super.key, required this.template});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LensDetailScreen(template: template),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // 1. 背景图 (Before) - 始终铺满
              AspectRatio(
                aspectRatio: 1 / template.aspectRatio,
                child: Container(
                  color: Colors.grey[800],
                  child: _buildSmartImage(
                    template.beforeImage,
                    color: Colors.black.withOpacity(0.3),
                    blendMode: BlendMode.darken,
                  ),
                ),
              ),

              // 2. 前景图 (After) + 动态裁剪
              ClipPath(
                clipper: template.splitStyle == LensSplitStyle.vertical
                    ? VerticalSplitClipper()
                    : DiagonalSplitClipper(),
                child: AspectRatio(
                  aspectRatio: 1 / template.aspectRatio,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.electricIndigo.withOpacity(0.2),
                          Colors.purpleAccent.withOpacity(0.2),
                        ],
                      ),
                    ),
                    child: _buildSmartImage(
                      template.afterImage,
                      color: AppTheme.electricIndigo.withOpacity(0.3),
                      blendMode: BlendMode.colorBurn,
                    ),
                  ),
                ),
              ),

              // 3. 分割线 + 动态绘制
              Positioned.fill(
                child: CustomPaint(
                  painter: template.splitStyle == LensSplitStyle.vertical
                      ? VerticalLinePainter()
                      : DiagonalLinePainter(),
                ),
              ),

              // 4. 官方标签
              if (template.isOfficial)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.electricIndigo,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.electricIndigo.withOpacity(0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.verified, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text(
                          "Official",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 5. 底部信息遮罩
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                        Colors.black,
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 8,
                            backgroundColor: Colors.grey[800],
                            child: ClipOval(
                              child: Image.network(
                                template.authorAvatar,
                                width: 16,
                                height: 16,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => const Icon(
                                  Icons.person,
                                  size: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              template.author,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.play_arrow_rounded,
                            size: 14,
                            color: Colors.white.withOpacity(0.6),
                          ),
                          Text(
                            template.usageCount,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 智能图片加载方法 (支持本地和网络) ---
  Widget _buildSmartImage(String path, {Color? color, BlendMode? blendMode}) {
    if (path.startsWith('http')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        color: color,
        colorBlendMode: blendMode,
        headers: const {'User-Agent': 'Mozilla/5.0'},
        errorBuilder: (context, error, stackTrace) =>
            Container(color: const Color(0xFF2A2A2A)),
      );
    } else {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        color: color,
        colorBlendMode: blendMode,
        errorBuilder: (context, error, stackTrace) => Container(
          color: const Color(0xFF2A2A2A),
          child: const Center(
            child: Text(
              "Asset Not Found",
              style: TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
        ),
      );
    }
  }
}

// --- 剪裁器与画笔 ---

class DiagonalSplitClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.moveTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width * 0.3, size.height);
    path.lineTo(size.width * 0.7, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class VerticalSplitClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.addRect(Rect.fromLTRB(size.width * 0.5, 0, size.width, size.height));
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class DiagonalLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final p1 = Offset(size.width * 0.7, 0);
    final p2 = Offset(size.width * 0.3, size.height);

    canvas.drawLine(p1, p2, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class VerticalLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final p1 = Offset(size.width * 0.5, 0);
    final p2 = Offset(size.width * 0.5, size.height);

    canvas.drawLine(p1, p2, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
