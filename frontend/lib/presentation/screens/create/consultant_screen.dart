import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../editor/editor_screen.dart';

// 消息模型
class ConsultantMessage {
  final bool isAi;
  final String content;
  final bool isTyping;

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

  final List<ConsultantMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _startConversationDemo();
  }

  // --- 全自动对话演示流程 ---
  Future<void> _startConversationDemo() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    _addMessage(
      ConsultantMessage(
        isAi: true,
        content:
            "已收到您的照片。这是一张非常唯美的人像，光线柔和，草地背景也很自然。\n\n您希望将场景转换为【海边黄昏】，并对人物进行【美化】，是吗？",
      ),
    );

    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    _addMessage(
      ConsultantMessage(
        isAi: false,
        content: "是的，背景换成那种金色的沙滩和大海，夕阳的光打在身上。人脸稍微精致一点，但不要太假。",
      ),
    );

    await _simulateAiThinking();
    if (!mounted) return;
    _addMessage(
      ConsultantMessage(
        isAi: true,
        content:
            "明白了。方案如下：\n1. 场景重构：将草地背景替换为【日落海滩】，调整环境光为暖色调的【夕阳余晖】。\n2. 人物美化：保留皮肤质感的同时进行微磨皮，提亮眼神，优化五官立体感。\n\n您觉得这个方向如何？",
      ),
    );

    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    _addMessage(
      ConsultantMessage(
        isAi: false,
        content: "听起来不错。对了，衣服能不能也稍微调整一下？让它看起来更飘逸一点，符合海边的感觉。",
      ),
    );

    await _simulateAiThinking();
    if (!mounted) return;
    _addMessage(
      ConsultantMessage(
        isAi: true,
        content:
            "没问题。已追加【服饰优化】节点，将增强薄纱袖口的飘逸感，使其与海风环境更融合。\n\n一切准备就绪，请点击下方按钮开始生成。",
      ),
    );
  }

  Future<void> _simulateAiThinking() async {
    if (!mounted) return;
    setState(() {
      _messages.add(ConsultantMessage(isAi: true, content: "", isTyping: true));
    });
    _scrollToBottom();

    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;
    setState(() {
      _messages.removeLast();
    });
  }

  void _addMessage(ConsultantMessage msg) {
    setState(() {
      _messages.add(msg);
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
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

  void _handleUserSend() {
    if (_textController.text.isNotEmpty) {
      _addMessage(
        ConsultantMessage(isAi: false, content: _textController.text),
      );
      _textController.clear();
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
                    _buildTag("Portrait"),
                    _buildTag("Nature"),
                    _buildTag("Soft Light"),
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

  Widget _buildMessageBubble(ConsultantMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: msg.isAi
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      ? const TypingIndicator()
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
          // 🔥 核心修改：点击 Confirm 跳转到 Editor 并开启自动模拟
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditorScreen(
                    selectedImage: File(widget.selectedImagePath),
                    autoStartSimulation: true, // 开启自动模拟
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
