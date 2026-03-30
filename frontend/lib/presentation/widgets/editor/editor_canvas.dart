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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildImageContent(),
              if (activeTool == ToolType.crop)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Row(
                    children: [
                      _buildControl(Icons.flip, onFlipHorizontal),
                      const SizedBox(width: 8),
                      _buildControl(Icons.swap_horiz, onMirror),
                    ],
                  ),
                ),
              if (isGenerating)
                Container(
                  color: Colors.white70,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.electricIndigo,
                    ),
                  ),
                ),
            ],
          ),
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
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) {
            return child;
          }
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            child: child,
          );
        },
      );
    }
    if (originalImage != null) {
      return Image.file(originalImage!, fit: BoxFit.contain);
    }
    return const _CanvasFallback();
  }

  Widget _buildControl(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black12),
        ),
        child: Icon(icon, color: Colors.black87, size: 20),
      ),
    );
  }
}

class _CanvasFallback extends StatelessWidget {
  const _CanvasFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade100,
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        size: 42,
        color: AppTheme.electricIndigo,
      ),
    );
  }
}
