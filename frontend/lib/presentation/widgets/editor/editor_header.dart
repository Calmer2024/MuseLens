import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class EditorHeader extends StatelessWidget {
  const EditorHeader({
    super.key,
    required this.onBack,
    required this.onHelp,
    required this.onOpenAssetTree,
    required this.onSave,
    required this.onExport,
  });

  final VoidCallback onBack;
  final VoidCallback onHelp;
  final VoidCallback onOpenAssetTree;
  final VoidCallback onSave;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Row(
        children: [
          _GhostIconButton(
            icon: Icons.close_rounded,
            onTap: onBack,
          ),
          const SizedBox(width: 8),
          _HelpIconButton(onTap: onHelp),
          const Spacer(),
          _TreeIconButton(onTap: onOpenAssetTree),
          const SizedBox(width: 8),
          _CompactActionButton(
            label: '保存',
            onTap: onSave,
          ),
          const SizedBox(width: 8),
          _CompactActionButton(
            label: '导出',
            onTap: onExport,
            filled: true,
          ),
        ],
      ),
    );
  }
}

class _GhostIconButton extends StatelessWidget {
  const _GhostIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: 21),
      splashRadius: 18,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      padding: EdgeInsets.zero,
    );
  }
}

class _HelpIconButton extends StatelessWidget {
  const _HelpIconButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.92),
            width: 1.3,
          ),
        ),
        child: const Icon(
          Icons.question_mark_rounded,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }
}

class _TreeIconButton extends StatelessWidget {
  const _TreeIconButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        child: const Icon(
          Icons.account_tree_outlined,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}

class _CompactActionButton extends StatelessWidget {
  const _CompactActionButton({
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? AppTheme.electricIndigo : const Color(0xFF242426),
          borderRadius: BorderRadius.circular(8),
          border: filled
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
