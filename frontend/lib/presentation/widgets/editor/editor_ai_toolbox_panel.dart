import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/router_models.dart';

enum EditorAiExecutionMode { directRun, applyControls, workflow }

class EditorAiAssetSlot {
  const EditorAiAssetSlot({
    required this.assetName,
    required this.label,
    required this.hint,
  });

  final String assetName;
  final String label;
  final String hint;
}

class EditorAiToolDefinition {
  const EditorAiToolDefinition({
    required this.lensId,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.executionMode,
    this.assetSlots = const <EditorAiAssetSlot>[],
  });

  final String lensId;
  final String title;
  final String subtitle;
  final IconData icon;
  final EditorAiExecutionMode executionMode;
  final List<EditorAiAssetSlot> assetSlots;
}

const List<EditorAiToolDefinition> kEditorAiToolDefinitions = <EditorAiToolDefinition>[
  EditorAiToolDefinition(
    lensId: 'lens_upscale_4x',
    title: '画质增强',
    subtitle: '4x 超清放大与细节补全',
    icon: Icons.high_quality_rounded,
    executionMode: EditorAiExecutionMode.directRun,
  ),
  EditorAiToolDefinition(
    lensId: 'lens_flux_edit',
    title: '背景重绘',
    subtitle: '整体改写背景气氛与环境',
    icon: Icons.landscape_rounded,
    executionMode: EditorAiExecutionMode.directRun,
  ),
  EditorAiToolDefinition(
    lensId: 'lens_lora_filter',
    title: '风格滤镜',
    subtitle: 'LoRA 风格覆盖与浓度调节',
    icon: Icons.auto_awesome_rounded,
    executionMode: EditorAiExecutionMode.applyControls,
  ),
  EditorAiToolDefinition(
    lensId: 'lens_style',
    title: '参考风格迁移',
    subtitle: '上传参考图进行高级风格迁移',
    icon: Icons.style_rounded,
    executionMode: EditorAiExecutionMode.applyControls,
    assetSlots: <EditorAiAssetSlot>[
      EditorAiAssetSlot(
        assetName: 'style_reference_image',
        label: '风格参考图',
        hint: '选择一张风格参考图',
      ),
    ],
  ),
  EditorAiToolDefinition(
    lensId: 'lens_relighting',
    title: '光影重塑',
    subtitle: '3D 光球控制主光方向与色温',
    icon: Icons.wb_incandescent_rounded,
    executionMode: EditorAiExecutionMode.workflow,
  ),
  EditorAiToolDefinition(
    lensId: 'lens_depth_of_field',
    title: '景深镜头',
    subtitle: '对焦点与光圈联动模拟镜头景深',
    icon: Icons.camera_rounded,
    executionMode: EditorAiExecutionMode.workflow,
  ),
  EditorAiToolDefinition(
    lensId: 'lens_flux_inpaint',
    title: '局部重绘',
    subtitle: '自动抠出目标后局部替换',
    icon: Icons.brush_rounded,
    executionMode: EditorAiExecutionMode.workflow,
  ),
  EditorAiToolDefinition(
    lensId: 'lens_sam2_matting',
    title: '智能抠图',
    subtitle: '按文字目标提取遮罩',
    icon: Icons.content_cut_rounded,
    executionMode: EditorAiExecutionMode.directRun,
  ),
  EditorAiToolDefinition(
    lensId: 'lens_flux_reference',
    title: '单参考重绘',
    subtitle: '上传一张参考图锁定额外约束',
    icon: Icons.filter_1_rounded,
    executionMode: EditorAiExecutionMode.directRun,
    assetSlots: <EditorAiAssetSlot>[
      EditorAiAssetSlot(
        assetName: 'ref_image_1',
        label: '参考图 1',
        hint: '选择一张参考图',
      ),
    ],
  ),
  EditorAiToolDefinition(
    lensId: 'lens_flux_two_reference',
    title: '双参考融合',
    subtitle: '同时使用两张参考图进行重绘',
    icon: Icons.filter_2_rounded,
    executionMode: EditorAiExecutionMode.directRun,
    assetSlots: <EditorAiAssetSlot>[
      EditorAiAssetSlot(
        assetName: 'ref_image_1',
        label: '参考图 1',
        hint: '选择第一张参考图',
      ),
      EditorAiAssetSlot(
        assetName: 'ref_image_2',
        label: '参考图 2',
        hint: '选择第二张参考图',
      ),
    ],
  ),
  EditorAiToolDefinition(
    lensId: 'lens_depth_extract',
    title: '深度提取',
    subtitle: '提取深度图供后续空间控制',
    icon: Icons.layers_outlined,
    executionMode: EditorAiExecutionMode.directRun,
  ),
  EditorAiToolDefinition(
    lensId: 'lens_canny_extract',
    title: '边缘提取',
    subtitle: '提取结构线稿作为控制图',
    icon: Icons.gesture_rounded,
    executionMode: EditorAiExecutionMode.directRun,
  ),
  EditorAiToolDefinition(
    lensId: 'lens_pose_extract',
    title: '姿态提取',
    subtitle: '抽取人物骨架与动作控制图',
    icon: Icons.accessibility_new_rounded,
    executionMode: EditorAiExecutionMode.directRun,
  ),
  EditorAiToolDefinition(
    lensId: 'lens_watermark',
    title: '水印保护',
    subtitle: '为作品添加签名与版权标识',
    icon: Icons.branding_watermark_rounded,
    executionMode: EditorAiExecutionMode.directRun,
  ),
  EditorAiToolDefinition(
    lensId: 'lens_flux_text2image',
    title: '创意生图',
    subtitle: '直接根据文本生成新画面',
    icon: Icons.image_search_rounded,
    executionMode: EditorAiExecutionMode.directRun,
  ),
];

class EditorAiToolboxPanel extends StatelessWidget {
  const EditorAiToolboxPanel({
    super.key,
    required this.selectedToolId,
    required this.paramValues,
    required this.controlValues,
    required this.localAssetPaths,
    required this.isRunning,
    required this.statusText,
    required this.stepResults,
    required this.onToolSelected,
    required this.onParamChanged,
    required this.onControlChanged,
    required this.onPickAsset,
    required this.onExecute,
  });

  final String? selectedToolId;
  final Map<String, dynamic> paramValues;
  final Map<String, dynamic> controlValues;
  final Map<String, String> localAssetPaths;
  final bool isRunning;
  final String? statusText;
  final List<RouterStepResult> stepResults;
  final ValueChanged<String> onToolSelected;
  final void Function(String key, dynamic value) onParamChanged;
  final void Function(String key, dynamic value) onControlChanged;
  final ValueChanged<String> onPickAsset;
  final VoidCallback onExecute;

  @override
  Widget build(BuildContext context) {
    final selectedTool = kEditorAiToolDefinitions.firstWhere(
      (tool) => tool.lensId == selectedToolId,
      orElse: () => kEditorAiToolDefinitions.first,
    );

    return Column(
      key: const ValueKey<String>('ai-toolbox'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PanelTitle(
          title: 'AI 工具箱',
          subtitle: '每个透镜都是一个真实可执行的 AI 工具',
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kEditorAiToolDefinitions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final tool = kEditorAiToolDefinitions[index];
              final selected = tool.lensId == selectedTool.lensId;
              return _ToolCard(
                tool: tool,
                selected: selected,
                onTap: () => onToolSelected(tool.lensId),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF121217),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C60FF), AppTheme.electricIndigo],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(selectedTool.icon, color: Colors.white, size: 19),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedTool.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selectedTool.subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.52),
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ..._buildToolControls(selectedTool),
              if (statusText != null && statusText!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    statusText!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
              if (stepResults.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '最近一次输出：${stepResults.length} 个结果节点',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.56),
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isRunning ? null : onExecute,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.electricIndigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    isRunning ? '正在执行 ${selectedTool.title}...' : '运行 ${selectedTool.title}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildToolControls(EditorAiToolDefinition tool) {
    final widgets = <Widget>[];
    for (final slot in tool.assetSlots) {
      widgets.add(_AssetPickerTile(
        label: slot.label,
        hint: localAssetPaths[slot.assetName] ?? slot.hint,
        onTap: () => onPickAsset(slot.assetName),
      ));
      widgets.add(const SizedBox(height: 10));
    }
    switch (tool.lensId) {
      case 'lens_upscale_4x':
        widgets.addAll([
          _slider(
            keyId: 'upscale_by',
            label: '放大倍数',
            value: (paramValues['upscale_by'] as num?)?.toDouble() ?? 4,
            min: 1,
            max: 4,
            divisions: 3,
            displayValueBuilder: (value) => '${value.toStringAsFixed(1)}x',
            onChanged: (value) => onParamChanged('upscale_by', value),
          ),
          _slider(
            keyId: 'denoise',
            label: '细节重绘',
            value: (paramValues['denoise'] as num?)?.toDouble() ?? 0.25,
            min: 0,
            max: 0.8,
            onChanged: (value) => onParamChanged('denoise', value),
          ),
          _multilineField(
            fieldKey: 'lens_upscale_4x.prompt',
            label: '细节补充方向',
            initialValue: paramValues['prompt']?.toString() ?? 'ultra sharp details, clean edges, refined textures',
            onChanged: (value) => onParamChanged('prompt', value),
          ),
        ]);
        break;
      case 'lens_flux_edit':
        widgets.addAll([
          _PresetWrap(
            label: '重绘方向',
            options: const <String>[
              '改成电影感黄昏',
              '改成高级展厅空间',
              '改成通透自然背景',
              '改成夜景霓虹氛围',
            ],
            selected: paramValues['prompt']?.toString(),
            onSelected: (value) => onParamChanged('prompt', value),
          ),
          const SizedBox(height: 10),
          _multilineField(
            fieldKey: 'lens_flux_edit.prompt',
            label: '背景重绘描述',
            initialValue: paramValues['prompt']?.toString() ?? '',
            onChanged: (value) => onParamChanged('prompt', value),
          ),
          _slider(
            keyId: 'steps',
            label: '重绘力度',
            value: (paramValues['steps'] as num?)?.toDouble() ?? 24,
            min: 12,
            max: 40,
            divisions: 14,
            onChanged: (value) => onParamChanged('steps', value.round()),
          ),
        ]);
        break;
      case 'lens_lora_filter':
        widgets.addAll([
          _PresetWrap(
            label: '滤镜风格',
            options: const <String>['ghibli', 'cyberpunk', 'clay', 'vintage'],
            selected: controlValues['filter_selector']?.toString(),
            labelBuilder: (raw) => switch (raw) {
              'ghibli' => '宫崎骏',
              'cyberpunk' => '赛博朋克',
              'clay' => '黏土',
              'vintage' => '复古手绘',
              _ => raw,
            },
            onSelected: (value) => onControlChanged('filter_selector', value),
          ),
          const SizedBox(height: 10),
          _slider(
            keyId: 'filter_opacity',
            label: '滤镜浓度',
            value: (controlValues['filter_opacity'] as num?)?.toDouble() ?? 0.8,
            min: 0.1,
            max: 1.2,
            onChanged: (value) => onControlChanged('filter_opacity', value),
          ),
        ]);
        break;
      case 'lens_style':
        widgets.addAll([
          _multilineField(
            fieldKey: 'lens_style.prompt',
            label: '风格要求',
            initialValue: paramValues['prompt']?.toString() ?? 'preserve the main subject and overall composition',
            onChanged: (value) => onParamChanged('prompt', value),
          ),
          _slider(
            keyId: 'style_intensity',
            label: '风格强度',
            value: (controlValues['style_intensity'] as num?)?.toDouble() ?? 0.8,
            min: 0,
            max: 1,
            onChanged: (value) => onControlChanged('style_intensity', value),
          ),
          _slider(
            keyId: 'structure_preservation',
            label: '结构保留',
            value: (controlValues['structure_preservation'] as num?)?.toDouble() ?? 0.72,
            min: 0,
            max: 1,
            onChanged: (value) => onControlChanged('structure_preservation', value),
          ),
        ]);
        break;
      case 'lens_relighting':
        widgets.addAll([
          _multilineField(
            fieldKey: 'lens_relighting.scene_hint',
            label: '光影目标',
            initialValue: controlValues['scene_hint']?.toString() ?? 'warm cinematic sunset light',
            onChanged: (value) => onControlChanged('scene_hint', value),
          ),
          _LightOrbControl(
            x: (controlValues['light_x'] as num?)?.toDouble() ?? 0.75,
            y: (controlValues['light_y'] as num?)?.toDouble() ?? 0.28,
            onChanged: (x, y) {
              onControlChanged('light_x', x);
              onControlChanged('light_y', y);
            },
          ),
          _slider(
            keyId: 'light_z',
            label: '光源距离',
            value: (controlValues['light_z'] as num?)?.toDouble() ?? 0.72,
            min: 0,
            max: 1,
            onChanged: (value) => onControlChanged('light_z', value),
          ),
          _slider(
            keyId: 'light_intensity',
            label: '光照强度',
            value: (controlValues['light_intensity'] as num?)?.toDouble() ?? 0.82,
            min: 0,
            max: 1,
            onChanged: (value) => onControlChanged('light_intensity', value),
          ),
          _slider(
            keyId: 'light_temperature',
            label: '色温',
            value: (controlValues['light_temperature'] as num?)?.toDouble() ?? 4200,
            min: 2800,
            max: 7800,
            divisions: 10,
            displayValueBuilder: (value) => '${value.round()}K',
            onChanged: (value) => onControlChanged('light_temperature', value),
          ),
        ]);
        break;
      case 'lens_depth_of_field':
        widgets.addAll([
          _FocusStripControl(
            focusValue: (controlValues['focus_depth_value'] as num?)?.toDouble() ?? 0.42,
            onChanged: (value) => onControlChanged('focus_depth_value', value),
          ),
          const SizedBox(height: 8),
          _slider(
            keyId: 'aperture_value',
            label: '光圈强度',
            value: (controlValues['aperture_value'] as num?)?.toDouble() ?? 0.6,
            min: 0,
            max: 1,
            onChanged: (value) => onControlChanged('aperture_value', value),
          ),
        ]);
        break;
      case 'lens_flux_inpaint':
        widgets.addAll([
          _multilineField(
            fieldKey: 'lens_flux_inpaint.target_prompt',
            label: '先选中要重绘的区域',
            initialValue: controlValues['target_prompt']?.toString() ?? '',
            onChanged: (value) => onControlChanged('target_prompt', value),
          ),
          _multilineField(
            fieldKey: 'lens_flux_inpaint.prompt',
            label: '重绘成什么',
            initialValue: paramValues['prompt']?.toString() ?? '',
            onChanged: (value) => onParamChanged('prompt', value),
          ),
        ]);
        break;
      case 'lens_sam2_matting':
        widgets.add(
          _multilineField(
            fieldKey: 'lens_sam2_matting.prompt',
            label: '抠图目标',
            initialValue: paramValues['prompt']?.toString() ?? '',
            onChanged: (value) => onParamChanged('prompt', value),
          ),
        );
        break;
      case 'lens_flux_reference':
      case 'lens_flux_two_reference':
        widgets.add(
          _multilineField(
            fieldKey: '${tool.lensId}.prompt',
            label: '参考重绘描述',
            initialValue: paramValues['prompt']?.toString() ?? '',
            onChanged: (value) => onParamChanged('prompt', value),
          ),
        );
        break;
      case 'lens_watermark':
        widgets.addAll([
          _multilineField(
            fieldKey: 'lens_watermark.text',
            label: '水印文字',
            initialValue: paramValues['text']?.toString() ?? '',
            onChanged: (value) => onParamChanged('text', value),
          ),
          _slider(
            keyId: 'font_size',
            label: '字号',
            value: (paramValues['font_size'] as num?)?.toDouble() ?? 36,
            min: 16,
            max: 72,
            onChanged: (value) => onParamChanged('font_size', value.round()),
          ),
          _PresetWrap(
            label: '水平位置',
            options: const <String>['left', 'center', 'right'],
            selected: paramValues['justify']?.toString(),
            labelBuilder: (raw) => switch (raw) {
              'left' => '左侧',
              'center' => '居中',
              'right' => '右侧',
              _ => raw,
            },
            onSelected: (value) => onParamChanged('justify', value),
          ),
          const SizedBox(height: 10),
          _PresetWrap(
            label: '垂直位置',
            options: const <String>['top', 'center', 'bottom'],
            selected: paramValues['align']?.toString(),
            labelBuilder: (raw) => switch (raw) {
              'top' => '顶部',
              'center' => '中部',
              'bottom' => '底部',
              _ => raw,
            },
            onSelected: (value) => onParamChanged('align', value),
          ),
          const SizedBox(height: 10),
          _slider(
            keyId: 'margins',
            label: '边距',
            value: (paramValues['margins'] as num?)?.toDouble() ?? 28,
            min: 0,
            max: 96,
            onChanged: (value) => onParamChanged('margins', value.round()),
          ),
        ]);
        break;
      case 'lens_flux_text2image':
        widgets.addAll([
          _multilineField(
            fieldKey: 'lens_flux_text2image.prompt',
            label: '创意描述',
            initialValue: paramValues['prompt']?.toString() ?? '',
            onChanged: (value) => onParamChanged('prompt', value),
          ),
          _PresetWrap(
            label: '生成尺寸',
            options: const <String>['1024x1024', '1024x1365', '1365x1024'],
            selected: '${paramValues['width'] ?? 1024}x${paramValues['height'] ?? 1024}',
            onSelected: (value) {
              final segments = value.split('x');
              if (segments.length == 2) {
                onParamChanged('width', int.tryParse(segments[0]) ?? 1024);
                onParamChanged('height', int.tryParse(segments[1]) ?? 1024);
              }
            },
          ),
        ]);
        break;
      default:
        widgets.add(
          Text(
            '这个工具可以直接执行，无需额外控件。',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 12,
            ),
          ),
        );
    }
    return widgets;
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.tool,
    required this.selected,
    required this.onTap,
  });

  final EditorAiToolDefinition tool;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        width: 104,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFF7C60FF), AppTheme.electricIndigo],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : const Color(0xFF15151B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.18)
                    : AppTheme.electricIndigo.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                tool.icon,
                color: selected ? Colors.white : AppTheme.electricIndigo,
                size: 18,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              tool.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.98),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetPickerTile extends StatelessWidget {
  const _AssetPickerTile({
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF17171D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppTheme.electricIndigo.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add_photo_alternate_outlined, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.52),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetWrap extends StatelessWidget {
  const _PresetWrap({
    required this.label,
    required this.options,
    required this.onSelected,
    this.selected,
    this.labelBuilder,
  });

  final String label;
  final List<String> options;
  final String? selected;
  final String Function(String raw)? labelBuilder;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final active = option == selected;
            return GestureDetector(
              onTap: () => onSelected(option),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: active
                      ? AppTheme.electricIndigo.withValues(alpha: 0.18)
                      : const Color(0xFF17171D),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: active
                        ? AppTheme.electricIndigo
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  labelBuilder?.call(option) ?? option,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: active ? 0.98 : 0.74),
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

Widget _multilineField({
  required String fieldKey,
  required String label,
  required String initialValue,
  required ValueChanged<String> onChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.78),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      TextFormField(
        key: ValueKey<String>(fieldKey),
        initialValue: initialValue,
        minLines: 2,
        maxLines: 4,
        onChanged: onChanged,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          height: 1.45,
        ),
        decoration: InputDecoration(
          hintText: '输入更具体的描述',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.28),
            fontSize: 12,
          ),
          filled: true,
          fillColor: const Color(0xFF17171D),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide(color: AppTheme.electricIndigo),
          ),
        ),
      ),
      const SizedBox(height: 10),
    ],
  );
}

Widget _slider({
  required String keyId,
  required String label,
  required double value,
  required double min,
  required double max,
  required ValueChanged<double> onChanged,
  int? divisions,
  String Function(double value)? displayValueBuilder,
}) {
  return Column(
    key: ValueKey<String>(keyId),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            displayValueBuilder?.call(value) ?? value.toStringAsFixed(2),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      SliderTheme(
        data: SliderThemeData(
          activeTrackColor: AppTheme.electricIndigo,
          inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
          thumbColor: Colors.white,
          overlayColor: AppTheme.electricIndigo.withValues(alpha: 0.18),
          trackHeight: 3,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 15),
        ),
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ),
      const SizedBox(height: 4),
    ],
  );
}

class _LightOrbControl extends StatelessWidget {
  const _LightOrbControl({
    required this.x,
    required this.y,
    required this.onChanged,
  });

  final double x;
  final double y;
  final void Function(double x, double y) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '主光方向',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            const height = 132.0;
            final knobCenter = Offset(x.clamp(0.0, 1.0) * width, y.clamp(0.0, 1.0) * height);

            void update(Offset localPosition) {
              final normalizedX = (localPosition.dx / width).clamp(0.0, 1.0);
              final normalizedY = (localPosition.dy / height).clamp(0.0, 1.0);
              onChanged(normalizedX, normalizedY);
            }

            return GestureDetector(
              onPanDown: (details) => update(details.localPosition),
              onPanUpdate: (details) => update(details.localPosition),
              child: Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1D1B29), Color(0xFF0F1015)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: RadialGradient(
                            center: Alignment((x * 2) - 1, (y * 2) - 1),
                            radius: 0.42,
                            colors: [
                              Colors.white.withValues(alpha: 0.26),
                              Colors.white.withValues(alpha: 0.04),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: knobCenter.dx - 14,
                      top: knobCenter.dy - 14,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFE7A6), Color(0xFFFFB13B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFC84A).withValues(alpha: 0.55),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.light_mode_rounded, color: Colors.black, size: 16),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 8,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '拖拽光球决定主光方向',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.52),
                                fontSize: 10,
                              ),
                            ),
                          ),
                          Text(
                            '${(x * 100).round()} / ${(y * 100).round()}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.34),
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _FocusStripControl extends StatelessWidget {
  const _FocusStripControl({
    required this.focusValue,
    required this.onChanged,
  });

  final double focusValue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '对焦平面',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '${(focusValue * 100).round()}%',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            void update(double dx) {
              onChanged((dx / width).clamp(0.0, 1.0));
            }

            return GestureDetector(
              onTapDown: (details) => update(details.localPosition.dx),
              onHorizontalDragUpdate: (details) => update(details.localPosition.dx),
              child: Container(
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFF17171D),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.06),
                                Colors.white.withValues(alpha: 0.18),
                                Colors.white.withValues(alpha: 0.06),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: (width - 20) * focusValue.clamp(0.0, 1.0),
                      top: 9,
                      child: Container(
                        width: 20,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: AppTheme.electricIndigo,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.electricIndigo.withValues(alpha: 0.4),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
