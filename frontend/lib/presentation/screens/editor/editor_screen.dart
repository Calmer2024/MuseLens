import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';

// 引入解耦后的组件
import '../../widgets/editor/editor_header.dart';
import '../../widgets/editor/editor_canvas.dart';
import '../../widgets/editor/editor_tools_panel.dart';
import '../../widgets/editor/chat_history_drawer.dart'; // 新增对话历史侧边栏

enum ToolType { none, crop, adjust, lens }

class EditorScreen extends StatefulWidget {
  final File selectedImage;

  const EditorScreen({super.key, required this.selectedImage});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _promptController = TextEditingController();

  bool _isGenerating = false;
  Uint8List? _resultImage;

  // --- 状态管理 ---
  ToolType _activeTool = ToolType.none;
  double _cropAspectRatio = -1;
  String _activeAdjustParam = "Exposure";
  double _adjustValue = 0.0;
  String? _selectedLensId;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  // --- 后端请求逻辑 (略，保持不变) ---
  Future<void> _sendToBackend(String text) async {
    /* ... 同前 ... */
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF121212),
      resizeToAvoidBottomInset: false,
      drawer: const ChatHistoryDrawer(), // 侧边栏
      body: SafeArea(
        child: Column(
          children: [
            // 1. 顶部栏 (Updated)
            EditorHeader(
              onBack: () => Navigator.pop(context), // 恢复返回按钮功能
              onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
              onUndo: () {},
              onRedo: () {},
              onSave: () {},
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
                  if (_activeTool == tool) {
                    _activeTool = ToolType.none;
                  } else {
                    _activeTool = tool;
                  }
                  _selectedLensId = null; // 切换工具时重置 Lens 选择
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
        ),
      ),
    );
  }
}
