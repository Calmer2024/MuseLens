import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class EditorHeader extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onMenuTap;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onSave;
  final VoidCallback onExport; // 新增

  const EditorHeader({
    super.key,
    required this.onBack,
    required this.onMenuTap,
    required this.onUndo,
    required this.onRedo,
    required this.onSave,
    required this.onExport, // 新增
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Back + History
          Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: onMenuTap,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.history,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),

          // Center: Undo/Redo
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.undo_rounded, color: Colors.white70),
                onPressed: onUndo,
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.redo_rounded, color: Colors.white70),
                onPressed: onRedo,
              ),
            ],
          ),

          // Right: Save + Export
          Row(
            children: [
              GestureDetector(
                onTap: onSave,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white30),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Save",
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onExport,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.electricIndigo,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.ios_share,
                    color: Colors.white,
                    size: 16,
                  ), // 导出图标
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
