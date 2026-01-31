import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../screens/editor/editor_screen.dart';

// --- Adjust Icons (优化：对应参数的图标) ---
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
  "Sharpness": Icons.change_history, // 三角形代表锐化
  "Definition": Icons.high_quality,
};

// --- Lens 数据模型 ---
class LensTool {
  final String id;
  final String name;
  final IconData icon;
  final String category;
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

  // Crop
  final double cropAspectRatio;
  final ValueChanged<double> onCropRatioChanged;

  // Adjust
  final String activeAdjustParam;
  final double adjustValue;
  final ValueChanged<String> onAdjustParamChanged;
  final ValueChanged<double> onAdjustValueChanged;

  // Lens
  final String? selectedLensId;
  final ValueChanged<String?> onLensSelected;

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
  });

  @override
  Widget build(BuildContext context) {
    // 判断是否处于 Lens 详情模式 (Lens工具且已选中具体功能)
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
          // 1. 动画容器：子工具面板 (上下滑动动画)
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

          // 2. 主工具栏 (仅在非工具模式下显示)
          if (activeTool == ToolType.none) _buildMainToolsRow(),

          // 3. 对话输入框 (Lens详情模式下隐藏，避免干扰)
          if (!isLensDetailMode) _buildChatInput(),
        ],
      ),
    );
  }

  // 主工具栏入口
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

  // --- 子面板内容 ---
  Widget _buildSubToolContent(bool isLensDetailMode) {
    return Container(
      color: const Color(0xFF252525),
      child: Column(
        children: [
          // A. 通用头部 (Close | Title | Check)
          // 仅在非 Lens 详情模式下显示
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

          // B. 具体工具体
          if (activeTool == ToolType.crop) _buildCropBody(),
          if (activeTool == ToolType.adjust) _buildAdjustBody(),
          if (activeTool == ToolType.lens) _buildLensBody(isLensDetailMode),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // --- Crop Body (包含所有比例) ---
  Widget _buildCropBody() {
    final ratios = [
      {"label": "Custom", "value": -1.0}, // Free
      {"label": "Original", "value": 0.0},
      {"label": "1:1", "value": 1.0},
      {"label": "3:4", "value": 0.75},
      {"label": "4:3", "value": 1.33},
      {"label": "9:16", "value": 0.56},
      {"label": "16:9", "value": 1.77},
      {"label": "2:3", "value": 0.66},
      {"label": "3:2", "value": 1.5},
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

  // --- Adjust Body ---
  Widget _buildAdjustBody() {
    return Column(
      children: [
        // Slider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Slider(
            value: adjustValue,
            min: -100,
            max: 100,
            activeColor: AppTheme.electricIndigo,
            inactiveColor: Colors.grey[800],
            onChanged: onAdjustValueChanged,
          ),
        ),
        // Icon List
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

  // --- Lens Body (核心重构：详情模式) ---
  Widget _buildLensBody(bool isDetailMode) {
    // 模拟 Lens 数据
    final lenses = [
      LensTool(
        id: "lens_matting",
        name: "Matting",
        icon: Icons.person_remove,
        category: "L1",
      ),
      LensTool(
        id: "lens_crop",
        name: "Smart Crop",
        icon: Icons.crop_free,
        category: "L1",
      ),
      LensTool(
        id: "lens_face_beauty",
        name: "Beauty",
        icon: Icons.face_retouching_natural,
        category: "L2",
      ),
      LensTool(
        id: "lens_relight",
        name: "Relight",
        icon: Icons.light_mode,
        category: "L3",
      ),
      LensTool(
        id: "lens_filter",
        name: "Style",
        icon: Icons.filter_b_and_w,
        category: "L4",
      ),
    ];

    if (!isDetailMode) {
      // 1. 列表模式：显示所有 Lens 图标
      return SizedBox(
        height: 90,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: lenses.length,
          itemBuilder: (context, index) {
            final tool = lenses[index];
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
      // 2. 详情模式：特定工具 UI + 底部导航栏
      final activeLens = lenses.firstWhere(
        (t) => t.id == selectedLensId,
        orElse: () => lenses[0],
      );
      return Column(
        children: [
          // 工具具体参数 UI (例如 Slider)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                Text(
                  "Adjusting ${activeLens.name}",
                  style: const TextStyle(
                    color: AppTheme.electricIndigo,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Slider(
                    value: 0.5,
                    onChanged: (v) {},
                    activeColor: AppTheme.electricIndigo,
                  ),
                ),
              ],
            ),
          ),

          // 底部操作栏：左返回，右确认
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 左侧：返回图标
                GestureDetector(
                  onTap: () => onLensSelected(null), // 返回 Lens 列表
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 24,
                  ),
                ),

                // 右侧：确认图标
                GestureDetector(
                  onTap: () {
                    // TODO: 应用效果逻辑
                    onLensSelected(null); // 应用后返回
                  },
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

  // --- 聊天输入框 ---
  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white10)),
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
