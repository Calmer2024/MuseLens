import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';

// --- 工具枚举 ---
enum ToolType { none, crop, adjust, lens }

enum LensCategory { l1, l2, l3, l4 }

// --- 模拟数据：原子 Lens 工具定义 ---
class LensTool {
  final String id;
  final String name;
  final IconData icon;
  final LensCategory category;

  LensTool({
    required this.id,
    required this.name,
    required this.icon,
    required this.category,
  });
}

class EditorScreen extends StatefulWidget {
  final File selectedImage;

  const EditorScreen({super.key, required this.selectedImage});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final TextEditingController _promptController = TextEditingController();

  bool _isGenerating = false;
  Uint8List? _resultImage;

  // --- 状态管理 ---
  ToolType _activeTool = ToolType.none; // 当前激活的工具类型
  String? _selectedLensId; // 当前选中的 Lens ID
  double _adjustValue = 0.0; // 模拟 Adjust 滑块值
  String _activeAdjustParam = "Exposure"; // 当前 Adjust 参数名

  // --- Lens 工具数据 ---
  final List<LensTool> _lensTools = [
    // L1
    LensTool(
      id: "lens_matting",
      name: "Matting",
      icon: Icons.person_remove,
      category: LensCategory.l1,
    ),
    LensTool(
      id: "lens_crop",
      name: "Smart Crop",
      icon: Icons.crop_free,
      category: LensCategory.l1,
    ),
    LensTool(
      id: "lens_upscale",
      name: "Upscale",
      icon: Icons.hd,
      category: LensCategory.l1,
    ),
    // L2
    LensTool(
      id: "lens_face_beauty",
      name: "Beauty",
      icon: Icons.face,
      category: LensCategory.l2,
    ),
    LensTool(
      id: "lens_replace",
      name: "Inpaint",
      icon: Icons.brush,
      category: LensCategory.l2,
    ),
    LensTool(
      id: "lens_structure",
      name: "Pose",
      icon: Icons.accessibility,
      category: LensCategory.l2,
    ),
    // L3
    LensTool(
      id: "lens_background",
      name: "BG Swap",
      icon: Icons.image,
      category: LensCategory.l3,
    ),
    LensTool(
      id: "lens_relight",
      name: "Relight",
      icon: Icons.light_mode,
      category: LensCategory.l3,
    ),
    // L4
    LensTool(
      id: "lens_dimension",
      name: "2D/3D",
      icon: Icons.animation,
      category: LensCategory.l4,
    ),
    LensTool(
      id: "lens_color_grade",
      name: "Filter",
      icon: Icons.palette,
      category: LensCategory.l4,
    ),
  ];

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  // --- 后端请求逻辑 (保持不变) ---
  Future<void> _sendToBackend() async {
    if (_promptController.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _isGenerating = true);

    try {
      String fileName = widget.selectedImage.path.split('/').last;
      FormData formData = FormData.fromMap({
        'prompt': _promptController.text,
        'image': await MultipartFile.fromFile(
          widget.selectedImage.path,
          filename: fileName,
        ),
      });

      Dio dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 10);
      var response = await dio.post(
        '${ApiConstants.baseUrl}/api/v1/editor/inpaint',
        data: formData,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode == 200) {
        setState(() {
          _resultImage = Uint8List.fromList(response.data);
        });
      }
    } catch (e) {
      debugPrint("Generation failed: $e");
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            // 1. 顶部导航栏 (含 Undo/Redo)
            _buildHeader(context),

            // 2. 中间图片画布 (Canvas)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: _buildCanvasArea(),
              ),
            ),

            // 3. 底部功能区 (工具栏 + 对话框)
            _buildBottomPanel(),
          ],
        ),
      ),
    );
  }

  // --- 1. Header with Undo/Redo ---
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Back
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 20,
            ),
          ),

          // Center: Undo/Redo
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.undo, color: Colors.white70),
                onPressed: () {}, // TODO: Undo Logic
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.redo, color: Colors.white70),
                onPressed: () {}, // TODO: Redo Logic
              ),
            ],
          ),

          // Right: Save
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.electricIndigo,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              "Save",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. Canvas Area ---
  Widget _buildCanvasArea() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black, // 画布背景
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            _resultImage != null
                ? Image.memory(_resultImage!, fit: BoxFit.contain)
                : Image.file(widget.selectedImage, fit: BoxFit.contain),

            // Crop Overlay Controls (仅在 Crop 模式显示)
            if (_activeTool == ToolType.crop)
              Positioned(
                top: 10,
                right: 10,
                child: Row(
                  children: [
                    _buildCanvasControl(Icons.flip, "Flip H"),
                    const SizedBox(width: 8),
                    _buildCanvasControl(Icons.flip_camera_android, "Mirror"),
                  ],
                ),
              ),

            // Loading
            if (_isGenerating)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.electricIndigo,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvasControl(IconData icon, String tooltip) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  // --- 3. Bottom Panel (Logic Switcher) ---
  Widget _buildBottomPanel() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // A. 如果有激活工具，显示子级参数面板
          if (_activeTool != ToolType.none) _buildSubToolPanel(),

          // B. 主工具栏 (Crop, Adjust, Lens)
          if (_activeTool == ToolType.none) _buildMainToolsRow(),

          // C. 底部对话输入框 (始终存在)
          _buildChatInput(),
        ],
      ),
    );
  }

  // === 工具栏 A: 主入口 ===
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
      onTap: () => setState(() => _activeTool = type),
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

  // === 工具栏 B: 子级面板 (根据 _activeTool 变化) ===
  Widget _buildSubToolPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: const Color(0xFF252525),
      child: Column(
        children: [
          // 1. 关闭/确认行
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => setState(() {
                    _activeTool = ToolType.none;
                    _selectedLensId = null;
                  }),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
                Text(
                  _activeTool == ToolType.crop
                      ? "Crop"
                      : _activeTool == ToolType.adjust
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
          const SizedBox(height: 10),

          // 2. 具体内容
          if (_activeTool == ToolType.crop) _buildCropOptions(),
          if (_activeTool == ToolType.adjust) _buildAdjustOptions(),
          if (_activeTool == ToolType.lens) _buildLensOptions(),
        ],
      ),
    );
  }

  // 子功能：Crop
  Widget _buildCropOptions() {
    final ratios = ["Free", "1:1", "3:4", "9:16", "16:9"];
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: ratios.length,
        itemBuilder: (context, index) {
          return Center(
            child: Container(
              margin: const EdgeInsets.only(right: 20),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white30),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                ratios[index],
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
        },
      ),
    );
  }

  // 子功能：Adjust
  Widget _buildAdjustOptions() {
    // 模拟参数列表
    final params = [
      "Exposure",
      "Brilliance",
      "Highlights",
      "Shadows",
      "Contrast",
      "Brightness",
      "Saturation",
      "Warmth",
    ];

    return Column(
      children: [
        // 滑块
        Slider(
          value: _adjustValue,
          min: -100,
          max: 100,
          activeColor: AppTheme.electricIndigo,
          inactiveColor: Colors.grey,
          onChanged: (v) => setState(() => _adjustValue = v),
        ),
        // 参数选择列表
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: params.length,
            itemBuilder: (context, index) {
              final isSelected = _activeAdjustParam == params[index];
              return GestureDetector(
                onTap: () => setState(() {
                  _activeAdjustParam = params[index];
                  _adjustValue = 0; // 重置滑块
                }),
                child: Container(
                  margin: const EdgeInsets.only(right: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? Colors.white : Colors.transparent,
                        ),
                        child: Icon(
                          Icons.tune, // 实际应用中每个参数图标不同
                          size: 18,
                          color: isSelected ? Colors.black : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        params[index],
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey,
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

  // 子功能：Lens (原子工具)
  Widget _buildLensOptions() {
    // 如果还没选具体 Lens，显示列表
    if (_selectedLensId == null) {
      return SizedBox(
        height: 80,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _lensTools.length,
          itemBuilder: (context, index) {
            final tool = _lensTools[index];
            return GestureDetector(
              onTap: () => setState(() => _selectedLensId = tool.id),
              child: Container(
                width: 70,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF333333),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(tool.icon, color: AppTheme.electricIndigo),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tool.name,
                      style: const TextStyle(color: Colors.white, fontSize: 10),
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
      // 选中了具体 Lens，显示参数 UI (模拟)
      // 这里可以根据 _selectedLensId 返回不同的 UI 组件
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              "Adjusting ${_lensTools.firstWhere((t) => t.id == _selectedLensId).name}",
              style: const TextStyle(
                color: AppTheme.electricIndigo,
                fontSize: 12,
              ),
            ),
          ),
          Slider(
            value: 0.5,
            onChanged: (v) {},
            activeColor: AppTheme.electricIndigo,
          ),
          // 返回按钮
          GestureDetector(
            onTap: () => setState(() => _selectedLensId = null),
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.arrow_upward, color: Colors.grey),
            ),
          ),
        ],
      );
    }
  }

  // --- 4. Chat Input (Shared) ---
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
                controller: _promptController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Or type instructions...",
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                ),
                onSubmitted: (_) => _sendToBackend(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _isGenerating ? null : _sendToBackend,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _isGenerating ? Colors.grey : AppTheme.electricIndigo,
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
