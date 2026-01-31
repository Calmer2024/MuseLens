import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../screens/editor/editor_screen.dart';

class EditorCanvas extends StatelessWidget {
  final File originalImage;
  final Uint8List? resultImage;
  final bool isGenerating;
  final ToolType activeTool;
  final VoidCallback onFlipHorizontal;
  final VoidCallback onMirror;

  const EditorCanvas({
    super.key,
    required this.originalImage,
    required this.resultImage,
    required this.isGenerating,
    required this.activeTool,
    required this.onFlipHorizontal,
    required this.onMirror,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Image Layer
              resultImage != null
                  ? Image.memory(resultImage!, fit: BoxFit.contain)
                  : Image.file(originalImage, fit: BoxFit.contain),

              // 2. Crop Overlay Controls
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

              // 3. Loading Layer
              if (isGenerating)
                Container(
                  color: Colors.black54,
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

  Widget _buildControl(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
