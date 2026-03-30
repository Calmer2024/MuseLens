import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/market_models.dart';
import '../../../data/repositories/market_repository.dart';

class MarketLensEditorScreen extends ConsumerStatefulWidget {
  final MarketLens? initialLens;

  const MarketLensEditorScreen({
    super.key,
    this.initialLens,
  });

  bool get isEditing => initialLens != null;

  @override
  ConsumerState<MarketLensEditorScreen> createState() =>
      _MarketLensEditorScreenState();
}

class _MarketLensEditorScreenState
    extends ConsumerState<MarketLensEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _lensKeyController;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _categoryController;
  late final TextEditingController _priceController;

  bool _isOfficial = false;
  bool _isSaving = false;
  String _status = 'active';

  @override
  void initState() {
    super.initState();
    final lens = widget.initialLens;
    _lensKeyController = TextEditingController(text: lens?.lensKey ?? '');
    _nameController = TextEditingController(text: lens?.name ?? '');
    _descriptionController = TextEditingController(text: lens?.description ?? '');
    _categoryController = TextEditingController(text: lens?.category ?? '');
    _priceController = TextEditingController(
      text: lens?.price.toStringAsFixed(2) ?? '0.00',
    );
    _isOfficial = lens?.isOfficial ?? false;
    _status = lens?.status ?? 'active';
  }

  @override
  void dispose() {
    _lensKeyController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = ref.read(authProvider);
    if (user == null) {
      _showMessage('请先登录再发布透镜');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final repository = ref.read(marketRepositoryProvider);
      final price = double.tryParse(_priceController.text.trim()) ?? 0;

      late final MarketLens savedLens;
      if (widget.isEditing) {
        savedLens = await repository.updateLens(
          widget.initialLens!.lensId,
          UpdateMarketLensInput(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
            category: _categoryController.text.trim().isEmpty
                ? null
                : _categoryController.text.trim(),
            price: price,
            isOfficial: _isOfficial,
            status: _status,
          ),
        );
      } else {
        savedLens = await repository.createLens(
          CreateMarketLensInput(
            lensKey: _lensKeyController.text.trim(),
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
            authorId: user.userId,
            category: _categoryController.text.trim().isEmpty
                ? null
                : _categoryController.text.trim(),
            price: price,
            isOfficial: _isOfficial,
            status: _status,
          ),
        );
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(savedLens.lensId);
    } catch (error) {
      _showMessage('保存失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEditing ? '编辑透镜' : '发布透镜';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -30,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.electricIndigo.withOpacity(0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Form(
              key: _formKey,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Row(
                        children: [
                          _buildCircleButton(
                            icon: Icons.arrow_back_rounded,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.isEditing
                                      ? '更新基础信息后即可继续发布新版本'
                                      : '先创建市场条目，随后就能继续发布版本',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.black.withOpacity(0.46),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildField(
                          controller: _nameController,
                          label: '透镜名称',
                          hint: '例如：人像柔光镜 Pro',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '请输入透镜名称';
                            }
                            return null;
                          },
                        ),
                        if (!widget.isEditing) ...[
                          const SizedBox(height: 18),
                          _buildField(
                            controller: _lensKeyController,
                            label: '唯一键',
                            hint: '例如：lens_market_portrait_v1',
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '请输入唯一键';
                              }
                              if (value.trim().length < 3) {
                                return '唯一键至少 3 个字符';
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 18),
                        _buildField(
                          controller: _descriptionController,
                          label: '描述',
                          hint: '介绍这个透镜适合什么场景、风格和效果',
                          minLines: 4,
                          maxLines: 6,
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _buildField(
                                controller: _categoryController,
                                label: '分类',
                                hint: 'portrait / anime / food',
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildField(
                                controller: _priceController,
                                label: '价格',
                                hint: '0.00',
                                keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                validator: (value) {
                                  final parsed = double.tryParse(
                                    value?.trim() ?? '',
                                  );
                                  if (parsed == null || parsed < 0) {
                                    return '请输入合法价格';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _buildSectionTitle('发布配置'),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: Colors.black.withOpacity(0.05),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '官方透镜',
                                          style: TextStyle(
                                            color: Colors.black87,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '开启后会显示官方标识，适合后台运营或官方账号发布',
                                          style: TextStyle(
                                            color:
                                                Colors.black.withOpacity(0.46),
                                            fontSize: 12,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch.adaptive(
                                    value: _isOfficial,
                                    activeColor: AppTheme.electricIndigo,
                                    onChanged: (value) {
                                      setState(() {
                                        _isOfficial = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              DropdownButtonFormField<String>(
                                initialValue: _status,
                                decoration: _fieldDecoration('状态', '选择透镜状态'),
                                borderRadius: BorderRadius.circular(18),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'active',
                                    child: Text('active'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'deprecated',
                                    child: Text('deprecated'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'removed',
                                    child: Text('removed'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  setState(() {
                                    _status = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      widget.isEditing ? '保存变更' : '创建透镜',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    int minLines = 1,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
      validator: validator,
      decoration: _fieldDecoration(label, hint),
    );
  }

  InputDecoration _fieldDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 18,
      ),
      labelStyle: TextStyle(color: Colors.black.withOpacity(0.58)),
      hintStyle: TextStyle(color: Colors.black.withOpacity(0.28)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppTheme.electricIndigo, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: Colors.black87),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
