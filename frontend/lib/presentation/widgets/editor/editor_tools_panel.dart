import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../screens/editor/editor_screen.dart';

const Map<String, IconData> _adjustIcons = <String, IconData>{
  '曝光': Icons.exposure,
  '高光': Icons.wb_sunny_outlined,
  '阴影': Icons.nights_stay_outlined,
  '对比': Icons.contrast,
  '亮度': Icons.brightness_6_outlined,
  '饱和': Icons.palette_outlined,
  '锐化': Icons.auto_fix_high_outlined,
};

class LensTool {
  const LensTool({
    required this.id,
    required this.name,
    required this.icon,
  });

  final String id;
  final String name;
  final IconData icon;
}

class EditorToolsPanel extends StatelessWidget {
  const EditorToolsPanel({
    super.key,
    required this.activeTool,
    required this.promptController,
    required this.isGenerating,
    required this.onToolChanged,
    required this.onSendPrompt,
    required this.onClosePanel,
    required this.cropAspectRatio,
    required this.onCropRatioChanged,
    required this.activeAdjustParam,
    required this.adjustValue,
    required this.onAdjustParamChanged,
    required this.onAdjustValueChanged,
    required this.selectedLensId,
    required this.onLensSelected,
    required this.appliedLensIds,
    required this.activeHighlightId,
  });

  final ToolType activeTool;
  final TextEditingController promptController;
  final bool isGenerating;
  final ValueChanged<ToolType> onToolChanged;
  final VoidCallback onSendPrompt;
  final VoidCallback onClosePanel;
  final double cropAspectRatio;
  final ValueChanged<double> onCropRatioChanged;
  final String activeAdjustParam;
  final double adjustValue;
  final ValueChanged<String> onAdjustParamChanged;
  final ValueChanged<double> onAdjustValueChanged;
  final String? selectedLensId;
  final ValueChanged<String?> onLensSelected;
  final List<String> appliedLensIds;
  final String? activeHighlightId;

  final List<LensTool> _lenses = const <LensTool>[
    LensTool(id: 'lens_matting', name: '智能抠图', icon: Icons.layers_clear),
    LensTool(id: 'lens_crop', name: '智能裁剪', icon: Icons.crop_free),
    LensTool(id: 'lens_upscale', name: '超清修复', icon: Icons.high_quality),
    LensTool(id: 'lens_face_beauty', name: '人像美化', icon: Icons.face_retouching_natural),
    LensTool(id: 'lens_replace', name: '涂抹消除', icon: Icons.brush_outlined),
    LensTool(id: 'lens_background', name: '背景替换', icon: Icons.wallpaper_outlined),
    LensTool(id: 'lens_relight', name: '光影重塑', icon: Icons.light_mode_outlined),
    LensTool(id: 'lens_color_grade', name: '氛围调色', icon: Icons.color_lens_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF08080B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.42),
            blurRadius: 36,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 8),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _buildActivePanel(),
                ),
              ),
              const SizedBox(height: 6),
              _buildToolTabs(),
              const SizedBox(height: 8),
              _buildChatInput(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivePanel() {
    return switch (activeTool) {
      ToolType.crop => _buildCropPanel(),
      ToolType.adjust => _buildAdjustPanel(),
      ToolType.lens => _buildLensPanel(),
      ToolType.templates => _buildLensPanel(showTitle: false),
      ToolType.none => _buildLensPanel(showTitle: false),
    };
  }

  Widget _buildCropPanel() {
    const ratios = <(String, double)>[
      ('自由', -1),
      ('原图', 0),
      ('1:1', 1),
      ('3:4', 3 / 4),
      ('9:16', 9 / 16),
      ('16:9', 16 / 9),
    ];

    return Column(
      key: const ValueKey<String>('crop'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PanelTitle(
          title: '裁剪比例',
          subtitle: '快速切换适配不同发布场景',
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ratios.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final ratio = ratios[index];
              final selected = cropAspectRatio == ratio.$2;
              return _ChoiceChipCard(
                label: ratio.$1,
                selected: selected,
                onTap: () => onCropRatioChanged(ratio.$2),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAdjustPanel() {
    return Column(
      key: const ValueKey<String>('adjust'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PanelTitle(
          title: '精细调节',
          subtitle: '保留当前画面，细调局部观感',
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 30,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _adjustIcons.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final entry = _adjustIcons.entries.elementAt(index);
              final selected = entry.key == activeAdjustParam;
              return _ChoiceChipCard(
                label: entry.key,
                icon: entry.value,
                selected: selected,
                onTap: () => onAdjustParamChanged(entry.key),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppTheme.electricIndigo,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
            thumbColor: Colors.white,
            overlayColor: AppTheme.electricIndigo.withValues(alpha: 0.18),
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: adjustValue,
            min: -100,
            max: 100,
            onChanged: onAdjustValueChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildLensPanel({bool showTitle = true}) {
    return Column(
      key: ValueKey<String>('lens-$showTitle'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle)
          const _PanelTitle(
            title: 'AI 模板',
            subtitle: '点击选择一个修图方向，指令会记录到资产树',
          )
        else
          Row(
            children: [
              const Expanded(
                child: Text(
                  '热门模板',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (activeHighlightId != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.electricIndigo.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '已记录 ${appliedLensIds.length} 次',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ),
            ],
          ),
        const SizedBox(height: 8),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _lenses.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final lens = _lenses[index];
              final selected = selectedLensId == lens.id;
              final used = appliedLensIds.contains(lens.id);
              final highlighted = activeHighlightId == lens.id;
              return _LensCard(
                lens: lens,
                selected: selected,
                used: used,
                highlighted: highlighted,
                onTap: () => onLensSelected(selected ? null : lens.id),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildToolTabs() {
    final items = <(ToolType, IconData, String)>[
      (ToolType.lens, Icons.auto_awesome_outlined, 'AI 修图'),
      (ToolType.templates, Icons.local_fire_department_outlined, '热门模板'),
      (ToolType.crop, Icons.crop_outlined, '裁剪'),
      (ToolType.adjust, Icons.tune_rounded, '调节'),
    ];

    return SizedBox(
      height: 48,
      child: Row(
        children: items.map((item) {
          final selected = activeTool == item.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => onToolChanged(item.$1),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item.$2,
                    size: 20,
                    color: selected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.45),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.$3,
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: selected ? 22 : 0,
                    height: 2,
                    decoration: BoxDecoration(
                      color: AppTheme.electricIndigo,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF121217),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.electricIndigo.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.graphic_eq_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: promptController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: selectedLensId == null
                    ? '输入你的修图想法，例如：天空更通透一些'
                    : '继续描述 ${_lensNameById(selectedLensId!)} 的效果',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.32),
                  fontSize: 13,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
              onSubmitted: (_) => isGenerating ? null : onSendPrompt(),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isGenerating ? null : onSendPrompt,
              borderRadius: BorderRadius.circular(18),
              child: Ink(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isGenerating
                      ? const Color(0xFF2A2A31)
                      : AppTheme.electricIndigo,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  isGenerating ? Icons.hourglass_top_rounded : Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _lensNameById(String id) {
    for (final lens in _lenses) {
      if (lens.id == id) return lens.name;
    }
    return 'AI 修图';
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

class _ChoiceChipCard extends StatelessWidget {
  const _ChoiceChipCard({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 34),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.electricIndigo.withValues(alpha: 0.2)
                  : const Color(0xFF17171D),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? AppTheme.electricIndigo
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white70, size: 15),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: selected ? 0.98 : 0.78),
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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

class _LensCard extends StatelessWidget {
  const _LensCard({
    required this.lens,
    required this.selected,
    required this.used,
    required this.highlighted,
    required this.onTap,
  });

  final LensTool lens;
  final bool selected;
  final bool used;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: 92,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                  : highlighted
                      ? AppTheme.electricIndigo.withValues(alpha: 0.72)
                      : Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppTheme.electricIndigo.withValues(alpha: 0.32),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.18)
                          : AppTheme.electricIndigo.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      lens.icon,
                      color: selected ? Colors.white : AppTheme.electricIndigo,
                      size: 17,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lens.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.98),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
              if (used || highlighted)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: highlighted
                          ? Colors.white
                          : AppTheme.electricIndigo.withValues(alpha: 0.72),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
