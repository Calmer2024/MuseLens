import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';

import '../../widgets/editor/editor_header.dart';
import '../../widgets/editor/editor_canvas.dart';
import '../../widgets/editor/editor_tools_panel.dart';
import '../../widgets/editor/chat_history_drawer.dart';
import '../../widgets/editor/image_history_tree.dart'; // 引入新的动态树

enum ToolType { none, crop, adjust, lens }

class EditorScreen extends StatefulWidget {
  final File selectedImage;
  final bool autoStartSimulation;

  const EditorScreen({
    super.key,
    required this.selectedImage,
    this.autoStartSimulation = false,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _promptController = TextEditingController();

  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isFlipped = false;

  bool _isGenerating = false;
  Uint8List? _resultImage;
  String? _simulationAssetPath; // 当前显示的图片路径

  // --- 状态管理 ---
  ToolType _activeTool = ToolType.none;
  double _cropAspectRatio = -1;
  String _activeAdjustParam = "Exposure";
  double _adjustValue = 0.0;
  String? _selectedLensId;

  // Workflow State
  List<String> _appliedLensIds = [];
  String? _activeHighlightId;

  // 🔥 动态图片树状态
  // Key: Node ID
  final Map<String, HistoryNode> _historyNodes = {};
  String _currentTreeHeadId = "root"; // 当前指针指向的节点 ID

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );

    // 🔥 初始化根节点 (原图)
    _historyNodes["root"] = HistoryNode(
      id: "root",
      parentId: null,
      label: "Original",
      imageSource: widget.selectedImage,
    );

    if (widget.autoStartSimulation) {
      _runSimulationSequence();
    }
  }

  // --- 🔥 动态添加节点的方法 ---
  void _addHistoryNode(
    String label,
    dynamic imageSource, {
    String? fromParentId,
  }) {
    final newId = DateTime.now().millisecondsSinceEpoch.toString(); // 简单生成 ID
    final parentId = fromParentId ?? _currentTreeHeadId; // 默认挂在当前节点下

    final newNode = HistoryNode(
      id: newId,
      parentId: parentId,
      label: label,
      imageSource: imageSource,
    );

    setState(() {
      _historyNodes[newId] = newNode;
      _currentTreeHeadId = newId; // 更新指针到最新
    });
  }

  // --- 模拟流水线 (自动添加节点) ---
  Future<void> _runSimulationSequence() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _activeTool = ToolType.lens);

    // 1. 美颜
    setState(() => _isGenerating = true);
    await Future.delayed(const Duration(seconds: 5));
    if (!mounted) return;
    setState(() {
      _isGenerating = false;
      _simulationAssetPath = "assets/images/simulation/beauty.png";
      _appliedLensIds.add("lens_face_beauty");
      _activeHighlightId = "lens_face_beauty";
    });
    // 🔥 自动添加节点
    _addHistoryNode("Beauty", "assets/images/simulation/beauty.png");

    // 2. 造景
    setState(() => _isGenerating = true);
    await Future.delayed(const Duration(seconds: 5));
    if (!mounted) return;
    setState(() {
      _isGenerating = false;
      _simulationAssetPath = "assets/images/simulation/scenery.png";
      _appliedLensIds.add("lens_background");
      _activeHighlightId = "lens_background";
    });
    // 🔥 自动添加节点
    _addHistoryNode("Scenery", "assets/images/simulation/scenery.png");

    // 3. 光影 (最终结果)
    setState(() => _isGenerating = true);
    await Future.delayed(const Duration(seconds: 5));
    if (!mounted) return;
    setState(() {
      _isGenerating = false;
      _simulationAssetPath = "assets/images/simulation/lighting.png";
      _appliedLensIds.add("lens_relight");
      _activeHighlightId = "lens_relight";
    });
    // 🔥 自动添加节点
    _addHistoryNode("Lighting", "assets/images/simulation/lighting.png");

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("AI Enhancement Complete ✨"),
        backgroundColor: AppTheme.electricIndigo,
      ),
    );
  }

  // --- 用户手动微调 (文字指令) ---
  Future<void> _handleUserCommand(String text) async {
    FocusScope.of(context).unfocus();
    _promptController.clear();

    if (text.contains("光球") || text.contains("光影")) {
      // 模拟微调产生新分支
      // 假设用户是在 "root" -> ... -> "Lighting" (V1) 基础上改的
      // 我们需要找到 Lighting 节点作为父节点 (这里简化为使用 currentHead)

      await _simulateFineTuning(
        targetLensId: "lens_relight",
        resultAsset: "assets/images/simulation/branch1.png",
        nodeLabel: "Light Fix",
      );
    } else if (text.contains("背景") || text.contains("埃菲尔")) {
      await _simulateFineTuning(
        targetLensId: "lens_background",
        resultAsset: "assets/images/simulation/branch2.png",
        nodeLabel: "Eiffel BG",
      );
    }
  }

  Future<void> _simulateFineTuning({
    required String targetLensId,
    required String resultAsset,
    required String nodeLabel,
  }) async {
    setState(() {
      _isGenerating = true;
      if (!_appliedLensIds.contains(targetLensId)) {
        _appliedLensIds.add(targetLensId);
      }
      _activeHighlightId = targetLensId;
    });

    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;
    setState(() {
      _isGenerating = false;
      _simulationAssetPath = resultAsset;
    });

    // 🔥 关键：生成新节点，挂在当前选中的节点下
    _addHistoryNode(nodeLabel, resultAsset);
  }

  // --- 手动保存 ---
  void _handleSave() {
    // 这里的逻辑是：用户觉得当前调整得不错，手动点保存，生成一个 Checkpoint
    // 实际项目中应该是将当前 Canvas 渲染成图片
    // 这里我们直接用当前的 simulationPath
    if (_simulationAssetPath != null) {
      _addHistoryNode("Manual Save", _simulationAssetPath!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Snapshot Saved to History")),
      );
    }
  }

  // --- 点击树节点回溯 ---
  void _onTreeNodeSelected(String nodeId) {
    final node = _historyNodes[nodeId];
    if (node == null) return;

    setState(() {
      _currentTreeHeadId = nodeId;

      // 恢复图片显示
      if (node.imageSource is String) {
        _simulationAssetPath = node.imageSource;
        _resultImage = null;
      } else if (node.imageSource is File) {
        _simulationAssetPath = null;
        // 实际上 EditorCanvas 需要处理 File 类型显示，这里简化为清空模拟路径显示原图
        // 如果需要显示特定的 File，需要传给 EditorCanvas
      }

      // TODO: 实际项目中还需要根据节点恢复 _appliedLensIds 等状态
      // 这里为了演示流畅性，暂时只切换图片
    });

    // 翻转回正面
    _toggleFlip();
  }

  @override
  void dispose() {
    _promptController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() => _isFlipped = !_isFlipped);
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
          onLongPress: _toggleFlip,
          child: AnimatedBuilder(
            animation: _flipAnimation,
            builder: (context, child) {
              final angle = _flipAnimation.value * math.pi;
              final transform = Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(angle);

              return Transform(
                transform: transform,
                alignment: Alignment.center,
                child: _flipAnimation.value < 0.5
                    ? _buildFrontSide()
                    : Transform(
                        transform: Matrix4.identity()..rotateY(math.pi),
                        alignment: Alignment.center,
                        child: _buildBackSide(),
                      ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFrontSide() {
    return Column(
      children: [
        EditorHeader(
          onBack: () => Navigator.pop(context),
          onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
          onUndo: () {},
          onRedo: () {},
          // 🔥 绑定手动保存事件
          onSave: _handleSave,
          onExport: () {},
        ),

        Expanded(
          child: EditorCanvas(
            originalImage: widget.selectedImage,
            simulationImagePath: _simulationAssetPath,
            resultImage: _resultImage,
            isGenerating: _isGenerating,
            activeTool: _activeTool,
            onFlipHorizontal: () {},
            onMirror: () {},
          ),
        ),

        EditorToolsPanel(
          activeTool: _activeTool,
          promptController: _promptController,
          isGenerating: _isGenerating,
          appliedLensIds: _appliedLensIds,
          activeHighlightId: _activeHighlightId,
          onToolChanged: (tool) => setState(
            () => _activeTool = tool == _activeTool ? ToolType.none : tool,
          ),
          onSendPrompt: () => _handleUserCommand(_promptController.text),
          onClosePanel: () => setState(() => _activeTool = ToolType.none),
          cropAspectRatio: _cropAspectRatio,
          onCropRatioChanged: (ratio) =>
              setState(() => _cropAspectRatio = ratio),
          activeAdjustParam: _activeAdjustParam,
          adjustValue: _adjustValue,
          onAdjustParamChanged: (param) => setState(() {
            _activeAdjustParam = param;
            _adjustValue = 0.0;
          }),
          onAdjustValueChanged: (val) => setState(() => _adjustValue = val),
          selectedLensId: _selectedLensId,
          onLensSelected: (id) => setState(() => _selectedLensId = id),
        ),
      ],
    );
  }

  Widget _buildBackSide() {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Version History",
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
                  onPressed: _toggleFlip,
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10),
          Expanded(
            child: ImageHistoryTree(
              nodes: _historyNodes, // 🔥 传入动态数据
              currentNodeId: _currentTreeHeadId,
              onNodeSelected: _onTreeNodeSelected,
            ),
          ),
        ],
      ),
    );
  }
}
