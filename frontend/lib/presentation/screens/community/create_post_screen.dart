import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/community_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/community_models.dart';
import '../../../data/repositories/community_repository.dart';
import '../../../data/services/upload_service.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key, required this.initialImages});

  final List<XFile> initialImages;

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagController = TextEditingController();

  late List<XFile> _selectedImages;
  final List<String> _tags = [];
  bool _submitting = false;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedImages = List.from(widget.initialImages);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTag() {
    final text = _tagController.text.trim();
    if (text.isNotEmpty && !_tags.contains(text)) {
      setState(() {
        _tags.add(text.startsWith('#') ? text.substring(1) : text);
        _tagController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 80,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            '取消',
            style: TextStyle(color: Colors.black54, fontSize: 16),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.electricIndigo,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      '发布',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. 图片预览 (小红书风格轮播)
              _buildImageCarousel(),

              const SizedBox(height: 24),

              // 2. 标题输入
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextFormField(
                  controller: _titleController,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  decoration: const InputDecoration(
                    hintText: '填写标题会有更多赞哦~',
                    hintStyle: TextStyle(
                      color: Colors.black26,
                      fontWeight: FontWeight.normal,
                    ),
                    border: InputBorder.none,
                    counterText: '',
                  ),
                  maxLength: 30,
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Divider(color: Colors.grey.shade100, height: 1),
              ),

              // 3. 正文输入
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: TextFormField(
                  controller: _contentController,
                  maxLines: null,
                  minLines: 5,
                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                  decoration: const InputDecoration(
                    hintText: '添加正文',
                    hintStyle: TextStyle(color: Colors.black26),
                    border: InputBorder.none,
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return '内容不能为空';
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 12),

              // 4. 标签区域
              _buildTagSection(),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageCarousel() {
    return Container(
      height: 480,
      width: double.infinity,
      color: Colors.grey.shade50,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            itemCount: _selectedImages.length,
            onPageChanged: (index) =>
                setState(() => _currentImageIndex = index),
            itemBuilder: (context, index) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(_selectedImages[index].path),
                    fit: BoxFit.cover,
                  ),
                  // 删除按钮
                  Positioned(
                    top: 16,
                    right: 16,
                    child: GestureDetector(
                      onTap: () {
                        if (_selectedImages.length > 1) {
                          setState(() {
                            _selectedImages.removeAt(index);
                            if (_currentImageIndex >= _selectedImages.length) {
                              _currentImageIndex = _selectedImages.length - 1;
                            }
                          });
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('至少需要保留一张图片')),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          if (_selectedImages.length > 1)
            Positioned(
              bottom: 16,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_selectedImages.length, (index) {
                  final active = index == _currentImageIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active ? Colors.white : Colors.white54,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTagSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._tags.map((tag) => _buildTagChip(tag)),
              GestureDetector(
                onTap: () => _showAddTagSheet(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 14, color: AppTheme.electricIndigo),
                      SizedBox(width: 4),
                      Text(
                        '添加标签',
                        style: TextStyle(
                          color: AppTheme.electricIndigo,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.electricIndigo.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '#$tag',
            style: const TextStyle(
              color: AppTheme.electricIndigo,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => setState(() => _tags.remove(tag)),
            child: const Icon(
              Icons.close,
              size: 14,
              color: AppTheme.electricIndigo,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTagSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '添加标签',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _tagController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '输入标签名称...',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.check,
                      color: AppTheme.electricIndigo,
                    ),
                    onPressed: () {
                      _addTag();
                      Navigator.pop(context);
                    },
                  ),
                ),
                onSubmitted: (_) {
                  _addTag();
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final user = ref.read(authProvider);
    if (user == null) return;

    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final imageInputs = await Future.wait(
        _selectedImages.asMap().entries.map((entry) async {
          final index = entry.key;
          final file = entry.value;
          final imageSize = await _readImageSize(file);
          final uploadResult = await UploadService.instance.uploadXFile(
            file,
            purpose: 'community_post',
          );
          final resolvedUrl = UploadService.resolveDownloadUrl(
            uploadResult.downloadUrl,
          );
          return CreatePostImageInput(
            imageUrl: resolvedUrl,
            width: imageSize?.$1,
            height: imageSize?.$2,
            orderIndex: index,
          );
        }),
      );

      final input = CreatePostInput(
        userId: user.userId,
        title: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
        content: _contentController.text.trim(),
        isPublic: true,
        images: imageInputs,
        tagNames: _tags,
      );

      final repository = ref.read(communityRepositoryProvider);
      await repository.createPost(input, actingUserId: user.userId);

      ref.invalidate(communityTagsProvider);
      ref.invalidate(communityPostsProvider);
      ref.invalidate(communityFavoritePostsProvider);
      ref.invalidate(userDetailProvider(user.userId));
      await ref.read(authProvider.notifier).refreshUser();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已成功发布到创作广场')));
      Navigator.pop(context, true);
    } on DioException catch (e) {
      final detail = e.response?.data is Map
          ? e.response?.data['detail']
          : e.message;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('发布失败: $detail')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('发布失败，请重试')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<(int, int)?> _readImageSize(XFile file) async {
    try {
      final bytes = await File(file.path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return (frame.image.width, frame.image.height);
    } catch (_) {
      return null;
    }
  }
}
