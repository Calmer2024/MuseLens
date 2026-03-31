import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/market_models.dart';
import '../../../data/repositories/router_repository.dart';
import '../../widgets/shared/adaptive_media.dart';

class TemplateApplyDraft {
  final Map<String, String> initialInputs;
  final Map<String, Map<String, dynamic>> paramOverrides;
  final bool executeNow;

  const TemplateApplyDraft({
    required this.initialInputs,
    required this.paramOverrides,
    required this.executeNow,
  });
}

class TemplateApplySheet extends ConsumerStatefulWidget {
  final String title;
  final MarketLensVersion version;

  const TemplateApplySheet({
    super.key,
    required this.title,
    required this.version,
  });

  @override
  ConsumerState<TemplateApplySheet> createState() => _TemplateApplySheetState();
}

class _TemplateApplySheetState extends ConsumerState<TemplateApplySheet> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _paramOverridesController = TextEditingController(
    text: '{}',
  );

  late final Map<String, String> _initialInputs;
  final Map<String, String> _localPreviews = <String, String>{};
  final Set<String> _uploadingSlots = <String>{};
  bool _executeNow = true;

  @override
  void initState() {
    super.initState();
    _initialInputs = {
      for (final input in widget.version.requiredInputs) input: '',
    };
  }

  @override
  void dispose() {
    _paramOverridesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ModalScaffold(
      title: '应用模板',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.black.withOpacity(0.52),
            ),
          ),
          const SizedBox(height: 18),
          if (widget.version.requiredInputs.isEmpty)
            _buildInfoHint('当前版本没有额外输入槽位，可以直接应用。')
          else
            Column(
              children: widget.version.requiredInputs.map((input) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildInputSlot(input),
                );
              }).toList(),
            ),
          const SizedBox(height: 10),
          SwitchListTile.adaptive(
            value: _executeNow,
            contentPadding: EdgeInsets.zero,
            activeColor: AppTheme.electricIndigo,
            title: const Text('立即执行'),
            subtitle: Text(
              _executeNow ? '后端会直接执行模板' : '只生成可复用的 MuseDNA',
              style: TextStyle(color: Colors.black.withOpacity(0.48)),
            ),
            onChanged: (value) {
              setState(() {
                _executeNow = value;
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _paramOverridesController,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: '参数覆盖 JSON（可选）',
              hintText: '{"step_1_template_edit":{"strength":0.8}}',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _canSubmit ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: Text(_executeNow ? '上传并执行模板' : '生成模板配置'),
            ),
          ),
        ],
      ),
    );
  }

  bool get _canSubmit {
    if (_uploadingSlots.isNotEmpty) {
      return false;
    }
    for (final entry in _initialInputs.entries) {
      if (entry.value.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  Widget _buildInfoHint(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.electricIndigo.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildInputSlot(String inputName) {
    final uploadedName = _initialInputs[inputName]?.trim() ?? '';
    final previewPath = _localPreviews[inputName];
    final isUploading = _uploadingSlots.contains(inputName);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            inputName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            uploadedName.isEmpty ? '请选择并上传图片' : uploadedName,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black.withOpacity(0.5),
            ),
          ),
          if (previewPath != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 1.2,
                child: buildAdaptiveImage(
                  previewPath,
                  fit: BoxFit.cover,
                  placeholder: Container(color: const Color(0xFFF1F3F6)),
                  errorWidget: Container(color: const Color(0xFFF1F3F6)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isUploading ? null : () => _pickAndUpload(inputName),
              icon: isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_library_outlined, size: 18),
              label: Text(isUploading ? '上传中...' : '选择图片'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUpload(String inputName) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _uploadingSlots.add(inputName);
      _localPreviews[inputName] = picked.path;
    });

    try {
      final result = await ref
          .read(routerRepositoryProvider)
          .uploadBaseImage(filePath: picked.path);
      if (!mounted) {
        return;
      }
      setState(() {
        _initialInputs[inputName] = result.filename;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('图片上传失败：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _uploadingSlots.remove(inputName);
        });
      }
    }
  }

  void _submit() {
    try {
      final overrides = _paramOverridesController.text.trim().isEmpty
          ? const <String, Map<String, dynamic>>{}
          : _parseOverrides(_paramOverridesController.text.trim());
      Navigator.of(context).pop(
        TemplateApplyDraft(
          initialInputs: Map<String, String>.from(_initialInputs),
          paramOverrides: overrides,
          executeNow: _executeNow,
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('参数覆盖 JSON 解析失败：$error')));
    }
  }

  Map<String, Map<String, dynamic>> _parseOverrides(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('根节点必须是对象');
    }

    return decoded.map<String, Map<String, dynamic>>((key, value) {
      if (value is! Map<String, dynamic>) {
        throw FormatException('$key 必须是对象');
      }
      return MapEntry(key, Map<String, dynamic>.from(value));
    });
  }
}

class _ModalScaffold extends StatelessWidget {
  final String title;
  final Widget child;

  const _ModalScaffold({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
