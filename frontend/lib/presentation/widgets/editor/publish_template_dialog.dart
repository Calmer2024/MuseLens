import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/market_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/market_models.dart';
import '../../../data/repositories/market_repository.dart';

/// 发布模板到市场的底部对话框
class PublishTemplateDialog extends ConsumerStatefulWidget {
  const PublishTemplateDialog({
    super.key,
    required this.resultNodeId,
    required this.projectId,
  });

  final String resultNodeId;
  final String? projectId;

  @override
  ConsumerState<PublishTemplateDialog> createState() =>
      _PublishTemplateDialogState();
}

class _PublishTemplateDialogState extends ConsumerState<PublishTemplateDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _tagsController = TextEditingController();

  bool _isPublishing = false;
  String? _errorText;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _handlePublish() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorText = '请输入模板标题');
      return;
    }

    final user = ref.read(authProvider);
    if (user == null) {
      setState(() => _errorText = '请先登录后再发布模板');
      return;
    }

    final tags = _tagsController.text
        .split(RegExp(r'[,，\s]+'))
        .where((tag) => tag.trim().isNotEmpty)
        .map((tag) => tag.trim())
        .toList();

    setState(() {
      _isPublishing = true;
      _errorText = null;
    });

    try {
      final input = PublishTemplateFromNodeInput(
        authorId: user.userId,
        title: title,
        description: _descriptionController.text.trim(),
        resultAssetNodeId: widget.resultNodeId,
        tagNames: tags,
        category: _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
      );

      await ref.read(marketRepositoryProvider).publishTemplateFromNode(input);

      // 刷新模板市场列表
      ref.invalidate(marketLensListProvider);
      ref.invalidate(marketAuthoredLensesProvider);

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('模板发布成功！其他用户现在可以在模板市场中使用你的修图方案')),
      );
    } catch (error) {
      if (!mounted) return;
      String message = '发布失败，请稍后重试';
      if (error is DioException) {
        final data = error.response?.data;
        if (data is Map<String, dynamic> && data['detail'] != null) {
          message = data['detail'].toString();
        }
      } else if (error is Exception) {
        message = error.toString().replaceFirst('Exception: ', '');
      }
      setState(() {
        _isPublishing = false;
        _errorText = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0E0E14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- 拖拽指示条 ---
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // --- 标题 ---
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.electricIndigo, Color(0xFF9B59B6)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.cloud_upload_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '上传到模板市场',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white54, size: 22),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '你的修图方案将被分享到模板市场，其他用户可以一键应用到自己的图片上。',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),

                // --- 模板标题 ---
                _buildLabel('模板标题', required: true),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _titleController,
                  hintText: '例如：日系清新胶片风',
                  maxLength: 40,
                ),
                const SizedBox(height: 16),

                // --- 模板说明 ---
                _buildLabel('模板说明'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _descriptionController,
                  hintText: '描述一下你的修图思路（可选）',
                  maxLines: 3,
                  maxLength: 200,
                ),
                const SizedBox(height: 16),

                // --- 分类 ---
                _buildLabel('分类'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _categoryController,
                  hintText: '例如：人像、风景、美食（可选）',
                  maxLength: 20,
                ),
                const SizedBox(height: 16),

                // --- 标签 ---
                _buildLabel('标签'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _tagsController,
                  hintText: '用空格或逗号分隔，例如：胶片 日系 清新',
                  maxLength: 100,
                ),
                const SizedBox(height: 24),

                // --- 错误提示 ---
                if (_errorText != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _errorText!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // --- 发布按钮 ---
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _isPublishing ? null : _handlePublish,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.electricIndigo,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppTheme.electricIndigo.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isPublishing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            '确认发布',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
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

  Widget _buildLabel(String text, {bool required = false}) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (required)
          const Text(
            ' *',
            style: TextStyle(color: Colors.redAccent, fontSize: 14),
          ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        hintText: hintText,
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.28),
          fontSize: 14,
        ),
        counterStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.3),
          fontSize: 11,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppTheme.electricIndigo,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
