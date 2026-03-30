import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../screens/editor/editor_screen.dart';
import '../shared/adaptive_media.dart';

class EditorCanvas extends StatelessWidget {
  const EditorCanvas({
    super.key,
    this.originalImage,
    this.currentImagePath,
    this.resultImage,
    required this.isGenerating,
    required this.activeTool,
    required this.onFlipHorizontal,
    required this.onMirror,
  });

  final File? originalImage;
  final String? currentImagePath;
  final Uint8List? resultImage;
  final bool isGenerating;
  final ToolType activeTool;
  final VoidCallback onFlipHorizontal;
  final VoidCallback onMirror;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF060609),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.42),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF14141A), Color(0xFF050507)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: _buildImageContent(),
              ),
            ),
            const _CanvasShading(),
            if (activeTool == ToolType.crop)
              Positioned(
                right: 16,
                bottom: 18,
                child: Row(
                  children: [
                    _CanvasActionButton(
                      icon: Icons.flip,
                      onTap: onFlipHorizontal,
                    ),
                    const SizedBox(width: 8),
                    _CanvasActionButton(
                      icon: Icons.swap_horiz_rounded,
                      onTap: onMirror,
                    ),
                  ],
                ),
              ),
            if (isGenerating)
              Container(
                color: Colors.black.withValues(alpha: 0.28),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14141A),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: AppTheme.electricIndigo,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          '正在记录本次编辑',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageContent() {
    if (resultImage != null) {
      return Image.memory(resultImage!, fit: BoxFit.contain);
    }
    if (currentImagePath != null && currentImagePath!.trim().isNotEmpty) {
      return buildAdaptiveImage(
        currentImagePath,
        fit: BoxFit.contain,
        placeholder: const _CanvasFallback(),
        errorWidget: const _CanvasFallback(),
      );
    }
    if (originalImage != null) {
      return Image.file(originalImage!, fit: BoxFit.contain);
    }
    return const _CanvasFallback();
  }
}

class _CanvasActionButton extends StatelessWidget {
  const _CanvasActionButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _CanvasFallback extends StatelessWidget {
  const _CanvasFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF101015),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_outlined,
            size: 44,
            color: AppTheme.electricIndigo,
          ),
          SizedBox(height: 10),
          Text(
            '等待画面载入',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _CanvasShading extends StatelessWidget {
  const _CanvasShading();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black.withValues(alpha: 0.16),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.18),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0, 0.24, 1],
          ),
        ),
      ),
    );
  }
}
