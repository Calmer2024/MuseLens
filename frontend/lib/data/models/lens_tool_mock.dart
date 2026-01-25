import 'package:flutter/material.dart';

class LensToolMock {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> glowColors; // 专属渐变色

  LensToolMock({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.glowColors,
  });

  static List<LensToolMock> getRealityTools() {
    return [
      LensToolMock(
        title: "Magic Light",
        subtitle: "AI-powered relighting & atmosphere",
        icon: Icons.light_mode_rounded, // 模拟光球
        glowColors: [Colors.cyanAccent, Colors.purpleAccent],
      ),
      LensToolMock(
        title: "Reality Retouch",
        subtitle: "Professional portrait enhancement",
        icon: Icons.face_retouching_natural_rounded, // 模拟人脸网格
        glowColors: [Colors.purpleAccent, Colors.pinkAccent],
      ),
    ];
  }

  static List<LensToolMock> getCreativeTools() {
    return [
      LensToolMock(
        title: "Dimension Hop",
        subtitle: "Convert photos to art styles",
        icon: Icons.cyclone_rounded, // 模拟漩涡
        glowColors: [Colors.deepPurpleAccent, Colors.blueAccent],
      ),
      LensToolMock(
        title: "Element Inject",
        subtitle: "Seamlessly add objects via prompt",
        icon: Icons.add_to_photos_rounded, // 模拟添加物体
        glowColors: [Colors.indigoAccent, Colors.deepPurple],
      ),
    ];
  }
}
