import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../widgets/shared/adaptive_media.dart';
import '../editor/editor_screen.dart';

class ConsultantScreen extends StatefulWidget {
  const ConsultantScreen({
    super.key,
    required this.selectedImagePath,
  });

  final String selectedImagePath;

  @override
  State<ConsultantScreen> createState() => _ConsultantScreenState();
}

class _ConsultantScreenState extends State<ConsultantScreen> {
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _openEditor() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditorScreen(
          selectedImage: File(widget.selectedImagePath),
          initialPrompt: _textController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050507),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A1324), Color(0xFF08080B), Color(0xFF050507)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      '修图意图',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: ListView(
                    children: [
                      _PreviewCard(imagePath: widget.selectedImagePath),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF101015),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '描述你想要的效果',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '不再自动生成 mock 对话。你可以直接输入修图目标，然后进入黑色编辑界面继续处理。',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.62),
                                fontSize: 13,
                                height: 1.55,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _IntentChip(
                                  label: '人像更通透',
                                  onTap: () => _textController.text = '人像更通透，肤色自然一些',
                                ),
                                _IntentChip(
                                  label: '背景更干净',
                                  onTap: () => _textController.text = '背景更干净，杂物尽量淡化',
                                ),
                                _IntentChip(
                                  label: '夕阳氛围',
                                  onTap: () => _textController.text = '整体调成偏紫色的夕阳氛围',
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            TextField(
                              controller: _textController,
                              maxLines: 6,
                              minLines: 5,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: '例如：保留人物清晰度，让天空更蓝一点，整体冷调偏紫色。',
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.28),
                                ),
                                filled: true,
                                fillColor: const Color(0xFF17171D),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _openEditor,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.electricIndigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      '进入修图',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101015),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '当前图片',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: AspectRatio(
                aspectRatio: 0.9,
                child: buildAdaptiveImage(
                  imagePath,
                  fit: BoxFit.cover,
                  errorWidget: Container(
                    color: const Color(0xFF17171D),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_outlined,
                      color: AppTheme.electricIndigo,
                      size: 36,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntentChip extends StatelessWidget {
  const _IntentChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.electricIndigo.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppTheme.electricIndigo.withValues(alpha: 0.32),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
