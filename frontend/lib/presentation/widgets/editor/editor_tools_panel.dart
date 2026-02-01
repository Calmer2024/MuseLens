import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../screens/editor/editor_screen.dart';

// --- Adjust Icons ---
final Map<String, IconData> _adjustIcons = {
  "Exposure": Icons.exposure,
  "Brilliance": Icons.flare,
  "Highlights": Icons.wb_sunny,
  "Shadows": Icons.nights_stay_outlined,
  "Contrast": Icons.contrast,
  "Brightness": Icons.brightness_6,
  "Black Point": Icons.hdr_strong,
  "Saturation": Icons.color_lens,
  "Vibrance": Icons.leak_add,
  "Warmth": Icons.thermostat,
  "Tint": Icons.colorize,
  "Sharpness": Icons.change_history,
  "Definition": Icons.high_quality,
};

// --- Lens Data Model ---
class LensTool {
  final String id;
  final String name;
  final IconData icon;
  final String category; // L1, L2...

  LensTool({
    required this.id,
    required this.name,
    required this.icon,
    required this.category,
  });
}

class EditorToolsPanel extends StatelessWidget {
  final ToolType activeTool;
  final TextEditingController promptController;
  final bool isGenerating;

  final ValueChanged<ToolType> onToolChanged;
  final VoidCallback onSendPrompt;
  final VoidCallback onClosePanel;

  // Crop State
  final double cropAspectRatio;
  final ValueChanged<double> onCropRatioChanged;

  // Adjust State
  final String activeAdjustParam;
  final double adjustValue;
  final ValueChanged<String> onAdjustParamChanged;
  final ValueChanged<double> onAdjustValueChanged;

  // Lens State
  final String? selectedLensId;
  final ValueChanged<String?> onLensSelected;

  EditorToolsPanel({
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
  });

  // --- Lens Definition List (L1 - L4) ---
  final List<LensTool> _allLenses = [
    // L1: Foundation
    LensTool(
      id: "lens_matting",
      name: "Matting",
      icon: Icons.layers_clear,
      category: "L1",
    ),
    LensTool(
      id: "lens_crop",
      name: "Smart Crop",
      icon: Icons.crop_free,
      category: "L1",
    ),
    LensTool(
      id: "lens_upscale",
      name: "Upscale",
      icon: Icons.high_quality,
      category: "L1",
    ),
    // L2: Subject
    LensTool(
      id: "lens_face_beauty",
      name: "Beauty",
      icon: Icons.face_retouching_natural,
      category: "L2",
    ),
    LensTool(
      id: "lens_replace",
      name: "Inpaint",
      icon: Icons.brush,
      category: "L2",
    ),
    LensTool(
      id: "lens_structure",
      name: "Pose",
      icon: Icons.accessibility_new,
      category: "L2",
    ),
    // L3: Environment
    LensTool(
      id: "lens_background",
      name: "BG Swap",
      icon: Icons.wallpaper,
      category: "L3",
    ),
    LensTool(
      id: "lens_relight",
      name: "Relight",
      icon: Icons.light_mode,
      category: "L3",
    ),
    LensTool(
      id: "lens_effect",
      name: "Effects",
      icon: Icons.auto_fix_high,
      category: "L3",
    ),
    // L4: Style
    LensTool(
      id: "lens_dimension",
      name: "Dimension",
      icon: Icons.animation,
      category: "L4",
    ),
    LensTool(
      id: "lens_color_grade",
      name: "Color",
      icon: Icons.palette,
      category: "L4",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Lens详情模式判断
    final bool isLensDetailMode =
        activeTool == ToolType.lens && selectedLensId != null;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. 动画容器：子工具面板
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: SizedBox(
              width: double.infinity,
              child: activeTool != ToolType.none
                  ? _buildSubToolContent(isLensDetailMode)
                  : const SizedBox.shrink(),
            ),
          ),

          // 2. 主工具栏 (仅在未选中任何工具时显示)
          if (activeTool == ToolType.none) _buildMainToolsRow(),

          // 3. 对话输入框 (始终显示，即便在 Lens 详情模式下)
          _buildChatInput(),
        ],
      ),
    );
  }

  // --- Sub Tool Content Manager ---
  Widget _buildSubToolContent(bool isLensDetailMode) {
    return Container(
      color: const Color(0xFF252525),
      child: Column(
        children: [
          // 通用 Header (仅在非 Lens 详情模式显示，Lens 详情有自己的底部操作栏)
          if (!isLensDetailMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: onClosePanel,
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                  Text(
                    activeTool == ToolType.crop
                        ? "Crop"
                        : activeTool == ToolType.adjust
                        ? "Adjust"
                        : "Lens Lab",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Icon(Icons.check, color: AppTheme.electricIndigo),
                ],
              ),
            ),

          // 具体工具 Body
          if (activeTool == ToolType.crop) _buildCropBody(),
          if (activeTool == ToolType.adjust) _buildAdjustBody(),
          if (activeTool == ToolType.lens) _buildLensBody(isLensDetailMode),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // --- 1. Crop Body ---
  Widget _buildCropBody() {
    final ratios = [
      {"label": "Free", "value": -1.0},
      {"label": "Original", "value": 0.0},
      {"label": "1:1", "value": 1.0},
      {"label": "3:4", "value": 0.75},
      {"label": "4:3", "value": 1.33},
      {"label": "9:16", "value": 0.56},
      {"label": "16:9", "value": 1.77},
    ];

    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: ratios.length,
        separatorBuilder: (c, i) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = ratios[index];
          final isSelected = cropAspectRatio == item["value"];
          return GestureDetector(
            onTap: () => onCropRatioChanged(item["value"] as double),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.electricIndigo
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.electricIndigo
                        : Colors.white30,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  item["label"] as String,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- 2. Adjust Body ---
  Widget _buildAdjustBody() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Icon(Icons.remove, size: 16, color: Colors.grey),
              Expanded(
                child: Slider(
                  value: adjustValue,
                  min: -100,
                  max: 100,
                  activeColor: AppTheme.electricIndigo,
                  inactiveColor: Colors.grey[800],
                  onChanged: onAdjustValueChanged,
                ),
              ),
              const Icon(Icons.add, size: 16, color: Colors.grey),
            ],
          ),
        ),
        SizedBox(
          height: 70,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _adjustIcons.length,
            itemBuilder: (context, index) {
              final key = _adjustIcons.keys.elementAt(index);
              final icon = _adjustIcons.values.elementAt(index);
              final isSelected = activeAdjustParam == key;
              return GestureDetector(
                onTap: () => onAdjustParamChanged(key),
                child: Container(
                  margin: const EdgeInsets.only(right: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF333333),
                        ),
                        child: Icon(
                          icon,
                          size: 20,
                          color: isSelected ? Colors.black : Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        key,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- 3. Lens Body (核心重构) ---
  Widget _buildLensBody(bool isDetailMode) {
    if (!isDetailMode) {
      // --- A. Lens Library (列表模式) ---
      return SizedBox(
        height: 90,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _allLenses.length,
          itemBuilder: (context, index) {
            final tool = _allLenses[index];
            return GestureDetector(
              onTap: () => onLensSelected(tool.id),
              child: Container(
                width: 70,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF333333),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Icon(
                        tool.icon,
                        color: AppTheme.electricIndigo,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tool.name,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } else {
      // --- B. Specific Lens UI (详情模式) ---
      final activeLens = _allLenses.firstWhere(
        (t) => t.id == selectedLensId,
        orElse: () => _allLenses[0],
      );

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. 动态生成特定工具的 UI
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: _buildSpecificLensUI(activeLens),
          ),

          // 2. 返回与确认栏 (悬浮在对话框上方)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white10)),
              color: Color(0xFF2A2A2A), // 稍微区分背景
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back Button
                GestureDetector(
                  onTap: () => onLensSelected(null), // 返回列表
                  child: const Row(
                    children: [
                      Icon(Icons.arrow_back, color: Colors.white70, size: 20),
                      SizedBox(width: 4),
                      Text("Library", style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),

                // Title
                Text(
                  activeLens.name,
                  style: const TextStyle(
                    color: AppTheme.electricIndigo,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                // Apply Button
                GestureDetector(
                  onTap: () => onLensSelected(null), // Confirm logic
                  child: const Icon(
                    Icons.check,
                    color: AppTheme.electricIndigo,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
  }

  // --- 动态生成各个 Lens 的专属 UI ---
  Widget _buildSpecificLensUI(LensTool tool) {
    switch (tool.id) {
      case "lens_matting":
        return const Center(
          child: Text(
            "Auto Background Removal Active",
            style: TextStyle(color: Colors.white54),
          ),
        );

      case "lens_crop":
        // 复用 Crop 的 UI，或者提供更智能的选项
        return _buildChipSelector(["Auto", "Person", "Object", "Sky"]);

      case "lens_upscale":
        return _buildChipSelector(["2x", "4x", "Ultra"]);

      case "lens_face_beauty":
        return _buildSliderUI("Smoothness");

      case "lens_replace":
        return const Center(
          child: Text(
            "Select area & Describe below",
            style: TextStyle(color: Colors.white54),
          ),
        );

      case "lens_structure":
        return _buildChipSelector(["Pose", "Depth", "Canny", "Lineart"]);

      case "lens_background":
        return _buildChipSelector(["Studio", "Nature", "City", "Cyberpunk"]);

      case "lens_relight":
        // 模拟光照方向盘
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.light_mode, color: Colors.yellow, size: 20),
            const SizedBox(width: 10),
            Container(
              width: 100,
              height: 20,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.blue, Colors.purple, Colors.orange],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              "Color",
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        );

      case "lens_effect":
        return _buildChipSelector(["Rain", "Snow", "Fog", "Flare", "Bokeh"]);

      case "lens_dimension":
        return _buildChipSelector([
          "2D Anime",
          "3D Pixar",
          "Sketch",
          "Oil Painting",
        ]);

      case "lens_color_grade":
        return _buildChipSelector([
          "Cyberpunk",
          "Film Noir",
          "Vintage",
          "Warm",
        ]);

      default:
        return _buildSliderUI("Intensity");
    }
  }

  // 辅助：构建滑块 UI
  Widget _buildSliderUI(String label) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Slider(
            value: 0.5,
            onChanged: (v) {},
            activeColor: AppTheme.electricIndigo,
            inactiveColor: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  // 辅助：构建标签选择器
  Widget _buildChipSelector(List<String> options) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        itemBuilder: (context, index) {
          final isSelected = index == 0; // 模拟选中第一个
          return Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.electricIndigo
                  : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: isSelected ? null : Border.all(color: Colors.white24),
            ),
            child: Text(
              options[index],
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Main Tools Row (Entrance) ---
  Widget _buildMainToolsRow() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildToolItem(Icons.crop, "Crop", ToolType.crop),
          _buildToolItem(Icons.tune, "Adjust", ToolType.adjust),
          _buildToolItem(Icons.auto_awesome, "Lens AI", ToolType.lens),
        ],
      ),
    );
  }

  Widget _buildToolItem(IconData icon, String label, ToolType type) {
    return GestureDetector(
      onTap: () => onToolChanged(type),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white70),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // --- Chat Input ---
  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white10)),
        color: Color(0xFF1E1E1E), // 确保有背景色，防止内容穿透
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: AppTheme.electricIndigo,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mic, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white10),
              ),
              child: TextField(
                controller: promptController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Or type instructions...",
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                ),
                onSubmitted: (_) => onSendPrompt(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: isGenerating ? null : onSendPrompt,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isGenerating ? Colors.grey : AppTheme.electricIndigo,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
