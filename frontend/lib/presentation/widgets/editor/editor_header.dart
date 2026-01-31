import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class EditorHeader extends StatelessWidget {
  final VoidCallback onBack; // 新增：返回上一页
  final VoidCallback onMenuTap; // 打开历史记录
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onSave;

  const EditorHeader({
    super.key,
    required this.onBack,
    required this.onMenuTap,
    required this.onUndo,
    required this.onRedo,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left Group: Back + History
          Row(
            children: [
              // 1. Back Button
              GestureDetector(
                onTap: onBack,
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              // 2. History Button
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

          // Center Group: Undo/Redo
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.undo_rounded, color: Colors.white70),
                onPressed: onUndo,
                tooltip: "Undo",
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.redo_rounded, color: Colors.white70),
                onPressed: onRedo,
                tooltip: "Redo",
              ),
            ],
          ),

          // Right Group: Save
          GestureDetector(
            onTap: onSave,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.electricIndigo,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "Save",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
