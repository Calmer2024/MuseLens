import 'dart:io';
import 'dart:math' as math; // 用于 3D 翻转计算
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

// 引入解耦后的组件
import '../../widgets/editor/editor_header.dart';
import '../../widgets/editor/editor_canvas.dart';
import '../../widgets/editor/editor_tools_panel.dart';
import '../../widgets/editor/chat_history_drawer.dart';
import '../../widgets/editor/image_history_tree.dart'; // 新增：图片树组件

enum ToolType { none, crop, adjust, lens }

class EditorScreen extends StatefulWidget {
  final File selectedImage;

  const EditorScreen({super.key, required this.selectedImage});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _promptController = TextEditingController();

  // --- 动画控制器 (3D 翻转) ---
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isFlipped = false; // 是否处于翻转状态 (背面)

  bool _isGenerating = false;
  Uint8List? _resultImage;

  // --- 状态管理 ---
  ToolType _activeTool = ToolType.none;
  double _cropAspectRatio = -1;
  String _activeAdjustParam = "Exposure";
  double _adjustValue = 0.0;
  String? _selectedLensId;

  @override
  void initState() {
    super.initState();
    // 初始化翻转动画
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  // --- 触发翻转 ---
  void _toggleFlip() {
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() => _isFlipped = !_isFlipped);
  }

  // --- 后端请求逻辑 (略) ---
  Future<void> _sendToBackend(String text) async {
    /* ... */
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF121212),
      resizeToAvoidBottomInset: false,
      drawer: const ChatHistoryDrawer(),
      body: SafeArea(
        child: GestureDetector(
          // 长按屏幕触发翻转 (进入图片树模式)
          onLongPress: _toggleFlip,
          child: AnimatedBuilder(
            animation: _flipAnimation,
            builder: (context, child) {
              // 3D 翻转矩阵计算
              final angle = _flipAnimation.value * math.pi;
              final transform = Matrix4.identity()
                ..setEntry(3, 2, 0.001) // 透视效果
                ..rotateY(angle);

              return Transform(
                transform: transform,
                alignment: Alignment.center,
                child: _flipAnimation.value < 0.5
                    ? _buildFrontSide() // 正面：编辑器
                    : Transform(
                        // 背面需要先镜像翻转一次，否则文字是反的
                        transform: Matrix4.identity()..rotateY(math.pi),
                        alignment: Alignment.center,
                        child: _buildBackSide(), // 背面：图片树
                      ),
              );
            },
          ),
        ),
      ),
    );
  }

  // --- 正面：修图编辑器 ---
  Widget _buildFrontSide() {
    return Column(
      children: [
        // 1. 顶部栏 (Updated with Export)
        EditorHeader(
          onBack: () => Navigator.pop(context),
          onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
          onUndo: () {},
          onRedo: () {},
          onSave: () {
            // TODO: 保存当前节点到树中
          },
          onExport: () {
            // TODO: 导出图片逻辑
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text("Exporting image...")));
          },
        ),

        // 2. 画布区域
        Expanded(
          child: EditorCanvas(
            originalImage: widget.selectedImage,
            resultImage: _resultImage,
            isGenerating: _isGenerating,
            activeTool: _activeTool,
            onFlipHorizontal: () {},
            onMirror: () {},
          ),
        ),

        // 3. 底部工具面板
        EditorToolsPanel(
          activeTool: _activeTool,
          promptController: _promptController,
          isGenerating: _isGenerating,
          onToolChanged: (tool) {
            setState(() {
              _activeTool = (_activeTool == tool) ? ToolType.none : tool;
              _selectedLensId = null;
            });
          },
          onSendPrompt: () => _sendToBackend(_promptController.text),
          onClosePanel: () => setState(() {
            _activeTool = ToolType.none;
            _selectedLensId = null;
          }),
          // Crop Params
          cropAspectRatio: _cropAspectRatio,
          onCropRatioChanged: (ratio) =>
              setState(() => _cropAspectRatio = ratio),
          // Adjust Params
          activeAdjustParam: _activeAdjustParam,
          adjustValue: _adjustValue,
          onAdjustParamChanged: (param) => setState(() {
            _activeAdjustParam = param;
            _adjustValue = 0.0;
          }),
          onAdjustValueChanged: (val) => setState(() => _adjustValue = val),
          // Lens Params
          selectedLensId: _selectedLensId,
          onLensSelected: (id) => setState(() => _selectedLensId = id),
        ),
      ],
    );
  }

  // --- 背面：图片树视图 ---
  Widget _buildBackSide() {
    return Container(
      color: const Color(0xFF1E1E1E), // 背面背景色
      child: Column(
        children: [
          // 背面顶部栏
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Version History",
                  // --- 核心修改：使用 Orbitron 字体 ---
                  style: GoogleFonts.orbitron(
                    textStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _toggleFlip, // 点击关闭翻转回来
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10),

          // 图片树组件
          Expanded(
            child: ImageHistoryTree(
              originalImage: widget.selectedImage,
              onNodeSelected: (nodeData) {
                // TODO: 恢复到选中的节点状态
                _toggleFlip(); // 选完后翻转回正面
              },
            ),
          ),
        ],
      ),
    );
  }
}
