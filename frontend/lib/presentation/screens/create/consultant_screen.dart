import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter_animate/flutter_animate.dart'; // 动画库
import '../../../core/theme/app_theme.dart';
import '../editor/editor_screen.dart';

// 消息模型
class ConsultantMessage {
  final bool isAi;
  final String content;
  final bool isTyping; // 是否为输入状态 (...)

  ConsultantMessage({
    required this.isAi,
    required this.content,
    this.isTyping = false,
  });
}

class ConsultantScreen extends StatefulWidget {
  final String selectedImagePath;

  const ConsultantScreen({
    super.key,
    this.selectedImagePath = "assets/images/home_hero.jpg",
  });

  @override
  State<ConsultantScreen> createState() => _ConsultantScreenState();
}

class _ConsultantScreenState extends State<ConsultantScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // 初始为空，通过动画逐条添加
  final List<ConsultantMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    // 启动对话演示
    _startConversationDemo();
  }

  // --- 🔥 核心逻辑：全自动对话演示流程 ---
  Future<void> _startConversationDemo() async {
    // 1. AI: 开场分析 (延迟 500ms)
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    _addMessage(
      ConsultantMessage(
        isAi: true,
        content:
            "已完成图像深度分析。📸\n\n识别到【夜景、街道、人像】要素。构图很稳，光影层次丰富。您希望保持这种“电影质感”，还是尝试彻底的风格化改造？",
      ),
    );

    // 2. User: 提出需求 (延迟 1500ms)
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    _addMessage(
      ConsultantMessage(isAi: false, content: "我想试试赛博朋克风格，感觉这里的霓虹灯光很适合。"),
    );

    // 3. AI: 思考 + 确认方案 (先显示 Typing, 再显示内容)
    await _simulateAiThinking(); // 显示 ... 动画
    if (!mounted) return;
    _addMessage(
      ConsultantMessage(
        isAi: true,
        content:
            "收到。正在构建赛博朋克方案... 🤖\n\n建议增强“蓝紫色调”的对比度，并添加“雨天湿地反射”效果来增强氛围感。需要为您添加一些科幻元素细节吗？",
      ),
    );

    // 4. User: 补充细节 (延迟 2000ms)
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    _addMessage(
      ConsultantMessage(isAi: false, content: "听起来不错！可以加一点全息投影的招牌或者是飞行汽车吗？"),
    );

    // 5. AI: 最终确认 (先显示 Typing)
    await _simulateAiThinking();
    if (!mounted) return;
    _addMessage(
      ConsultantMessage(
        isAi: true,
        content: "没问题。已添加 [全息投影] 和 [未来载具] 节点。\n\n所有参数已就绪，请点击下方按钮确认并开始生成。",
      ),
    );
  }

  // 模拟 AI 思考过程 (显示 Typing Indicator 1.5秒)
  Future<void> _simulateAiThinking() async {
    if (!mounted) return;
    // 添加 Typing 状态
    setState(() {
      _messages.add(ConsultantMessage(isAi: true, content: "", isTyping: true));
    });
    _scrollToBottom();

    // 等待 1.5秒
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;
    // 移除 Typing 状态
    setState(() {
      _messages.removeLast();
    });
  }

  // 添加消息并滚动的辅助方法
  void _addMessage(ConsultantMessage msg) {
    setState(() {
      _messages.add(msg);
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    // 稍微延迟以确保 ListView 渲染完成
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  // 用户手动发送消息
  void _handleUserSend() {
    if (_textController.text.isNotEmpty) {
      _addMessage(
        ConsultantMessage(isAi: false, content: _textController.text),
      );
      _textController.clear();

      // 触发 AI 简单回复 (为了闭环逻辑)
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted)
          _simulateAiThinking().then((_) {
            _addMessage(ConsultantMessage(isAi: true, content: "好的，已记录您的新需求。"));
          });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildProjectContextPanel(),

            // --- Chat Area ---
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _buildMessageBubble(_messages[index]);
                },
              ),
            ),

            _buildBottomArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Photo Consultant",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "AI Analysis in progress...",
                  style: TextStyle(
                    color: AppTheme.electricIndigo,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.more_horiz, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildProjectContextPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 80,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              color: Colors.black,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  widget.selectedImagePath.startsWith('assets')
                      ? Image.asset(widget.selectedImagePath, fit: BoxFit.cover)
                      : Image.file(
                          File(widget.selectedImagePath),
                          fit: BoxFit.cover,
                        ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      color: Colors.black.withOpacity(0.6),
                      child: const Center(
                        child: Text(
                          "Original",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Current Project",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildTag("Night Scene"),
                    _buildTag("High Contrast"),
                    _buildTag("Street"),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  "AI is establishing a conversation context...",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.electricIndigo.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.electricIndigo.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.electricIndigo,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // --- 消息气泡 ---
  Widget _buildMessageBubble(ConsultantMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: msg.isAi
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Avatar
          if (msg.isAi) ...[
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFF2A2A2A),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: AppTheme.electricIndigo,
                size: 16,
              ),
            ),
          ],

          // Bubble
          Flexible(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: msg.isAi
                        ? const Color(0xFF2A2A2A)
                        : AppTheme.electricIndigo,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(msg.isAi ? 4 : 20),
                      bottomRight: Radius.circular(msg.isAi ? 20 : 4),
                    ),
                  ),
                  child: msg.isTyping
                      ? const TypingIndicator() // 显示跳动动画
                      : Text(
                          msg.content,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                ),
              )
              // 消息出现动画：淡入 + 上浮
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.1, end: 0, curve: Curves.easeOut),

          if (!msg.isAi) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildBottomArea() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Confirm Button
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditorScreen(
                    selectedImage: File(widget.selectedImagePath),
                  ),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.electricIndigo, Color(0xFF584CF4)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.electricIndigo.withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Confirm Requirement",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Input Row
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF000000),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.mic,
                        color: AppTheme.electricIndigo,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Type your request...",
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onSubmitted: (_) => _handleUserSend(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: _handleUserSend,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Typing Indicator 组件 ---
class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (index) {
          return Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.white70,
                  shape: BoxShape.circle,
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(
                delay: (index * 200).ms,
                duration: 600.ms,
                begin: const Offset(0.5, 0.5),
                end: const Offset(1.2, 1.2),
              );
        }),
      ),
    );
  }
}
