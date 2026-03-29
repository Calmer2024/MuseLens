import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart'; // 🔥 引入动画库
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
    required this.appliedLensIds,
    required this.activeHighlightId,
  });

  final List<LensTool> _allLenses = [
    LensTool(
      id: "lens_matting",
      name: "智能抠图",
      icon: Icons.layers_clear,
      category: "L1",
    ),
    LensTool(
      id: "lens_crop",
      name: "智能裁剪",
      icon: Icons.crop_free,
      category: "L1",
    ),
    LensTool(
      id: "lens_upscale",
      name: "画质增强",
      icon: Icons.high_quality,
      category: "L1",
    ),
    LensTool(
      id: "lens_face_beauty",
      name: "美颜",
      icon: Icons.face_retouching_natural,
      category: "L2",
    ),
    LensTool(
      id: "lens_replace",
      name: "涂抹消除",
      icon: Icons.brush,
      category: "L2",
    ),
    LensTool(
      id: "lens_structure",
      name: "姿态重构",
      icon: Icons.accessibility_new,
      category: "L2",
    ),
    LensTool(
      id: "lens_background",
      name: "背景替换",
      icon: Icons.wallpaper,
      category: "L3",
    ),
    LensTool(
      id: "lens_relight",
      name: "光影重塑",
      icon: Icons.light_mode,
      category: "L3",
    ),
    LensTool(
      id: "lens_effect",
      name: "特效玩法",
      icon: Icons.auto_fix_high,
      category: "L3",
    ),
    LensTool(
      id: "lens_dimension",
      name: "多维转换",
      icon: Icons.animation,
      category: "L4",
    ),
    LensTool(
      id: "lens_color_grade",
      name: "色彩增强",
      icon: Icons.palette,
      category: "L4",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // 判断是否进入了 Lens 的二级详情页
    final bool isLensDetailMode =
        activeTool == ToolType.lens && selectedLensId != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. 工具区域 (Main Tools 或 Sub Tools)
          // 使用 AnimatedSwitcher 实现平滑切换，而不是生硬的 if/else
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: activeTool == ToolType.none
                ? _buildMainToolsRow() // 显示主菜单 (Crop/Adjust/Lens)
                : _buildSubToolContent(isLensDetailMode), // 显示子功能
          ),

          // 2. 对话输入框 (🔥 永远显示在最底部)
          // 即使进入了工具详情，这里也不会消失
          _buildChatInput(),
        ],
      ),
    );
  }

  // --- 主菜单入口 ---
  Widget _buildMainToolsRow() {
    return Container(
      height: 100, // 给足够的高度
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildToolItem(Icons.crop, "裁剪", ToolType.crop),
          _buildToolItem(Icons.tune, "调节", ToolType.adjust),
          _buildToolItem(Icons.auto_awesome, "AI滤镜", ToolType.lens),
        ],
      ),
    );
  }

  // --- 子功能面板 ---
  Widget _buildSubToolContent(bool isLensDetailMode) {
    return Container(
      color: Colors.grey[50],
      child: Column(
        children: [
          // 通用 Header (Close | Title | Check)
          // 如果是 Lens 详情模式，会有专门的底部栏，所以这里隐藏通用 Header
          if (!isLensDetailMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: onClosePanel,
                    child: const Icon(Icons.close, color: Colors.black87),
                  ),
                  Text(
                    activeTool == ToolType.crop
                        ? "裁剪"
                        : activeTool == ToolType.adjust
                        ? "调节"
                        : "滤镜实验室",
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Icon(Icons.check, color: AppTheme.electricIndigo),
                ],
              ),
            ),

          // 具体内容
          if (activeTool == ToolType.crop) _buildCropBody(),
          if (activeTool == ToolType.adjust) _buildAdjustBody(),
          if (activeTool == ToolType.lens) _buildLensBody(isLensDetailMode),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // --- Lens Body (核心动画区域) ---
  Widget _buildLensBody(bool isDetailMode) {
    if (!isDetailMode) {
      // --- A. Lens Library (列表模式 + 左侧工作栈) ---
      return SizedBox(
        height: 110, // 增加高度给动画留空间
        child: Row(
          children: [
            // --- 1. 左侧：工作区 (Workflow Stack) ---
            if (appliedLensIds.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Row(
                  children: appliedLensIds.map((id) {
                    final tool = _allLenses.firstWhere(
                      (t) => t.id == id,
                      orElse: () => _allLenses[0],
                    );
                    final isActive = id == activeHighlightId;

                    return Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 70,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 图标容器
                          AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  // 高亮则紫色，否则(历史)为深灰色
                                  color: isActive
                                      ? AppTheme.electricIndigo
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isActive
                                        ? Colors.white
                                        : Colors.black12,
                                    width: isActive ? 2 : 1,
                                  ),
                                  boxShadow: isActive
                                      ? [
                                          BoxShadow(
                                            color: AppTheme.electricIndigo
                                                .withOpacity(0.6),
                                            blurRadius: 12,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Icon(
                                  tool.icon,
                                  color: isActive
                                      ? Colors.white
                                      : Colors.black54,
                                  size: 26,
                                ),
                              )
                              // 🔥 进场动画：弹跳 + 淡入
                              .animate(
                                key: ValueKey(id),
                              ) // Key 很重要，告诉 Flutter 这是新元素
                              .fade(duration: 400.ms)
                              .scale(
                                duration: 400.ms,
                                curve: Curves.easeOutBack,
                              ) // 弹跳效果
                              // 🔥 高亮状态：持续呼吸动画
                              .animate(target: isActive ? 1 : 0)
                              .shimmer(
                                duration: 1500.ms,
                                color: AppTheme.electricIndigo.withOpacity(0.5),
                              ),

                          const SizedBox(height: 8),
                          Text(
                            tool.name,
                            style: TextStyle(
                              color: isActive ? AppTheme.electricIndigo : Colors.black54,
                              fontSize: 11,
                              fontWeight: isActive
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

              // 分隔线
              Container(
                width: 1,
                height: 60,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: Colors.black12,
              ),
            ],

            // --- 2. 右侧：Lens Library (剩余工具) ---
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _allLenses.length,
                itemBuilder: (context, index) {
                  final tool = _allLenses[index];
                  // 简单的点击交互
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
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.black12),
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
                              color: Colors.black54,
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
            ),
          ],
        ),
      );
    } else {
      // --- B. 详情模式 (Specific UI) ---
      final activeLens = _allLenses.firstWhere(
        (t) => t.id == selectedLensId,
        orElse: () => _allLenses[0],
      );
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: _buildSpecificLensUI(activeLens),
          ),
          // 详情模式下的底部操作栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.black12)),
              color: Colors.white,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => onLensSelected(null),
                  child: const Row(
                    children: [
                      Icon(Icons.arrow_back, color: Colors.black54, size: 20),
                      SizedBox(width: 4),
                      Text("图库", style: TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
                Text(
                  activeLens.name,
                  style: const TextStyle(
                    color: AppTheme.electricIndigo,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () => onLensSelected(null),
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

  // --- 辅助方法 (保持不变) ---
  Widget _buildCropBody() {
    final ratios = ["自由", "原图", "1:1", "3:4", "9:16", "16:9"];
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: ratios.length,
        separatorBuilder: (c, i) => const SizedBox(width: 12),
        itemBuilder: (c, i) => Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(ratios[i], style: const TextStyle(color: Colors.black87)),
          ),
        ),
      ),
    );
  }

  Widget _buildAdjustBody() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.tune, color: Colors.black54),
        ),
        SizedBox(
          height: 70,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _adjustIcons.keys
                .map(
                  (k) => Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      k,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSpecificLensUI(LensTool tool) {
    return Center(
      child: Text(
        "正在调节 ${tool.name}",
        style: const TextStyle(color: Colors.black54),
      ),
    );
  }

  Widget _buildToolItem(IconData icon, String label, ToolType type) {
    return GestureDetector(
      onTap: () => onToolChanged(type),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.black54),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.black12)),
        color: Colors.white,
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
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.black12),
              ),
              child: TextField(
                controller: promptController,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(
                  hintText: "或者输入指令...",
                  hintStyle: TextStyle(color: Colors.black38),
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
