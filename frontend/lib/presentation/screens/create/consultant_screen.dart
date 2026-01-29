import 'package:flutter/material.dart';
import 'dart:io';
import '../../../core/theme/app_theme.dart';
import '../editor/editor_screen.dart';

// 消息模型
class ConsultantMessage {
  final bool isAi;
  final String content;

  ConsultantMessage({required this.isAi, required this.content});
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

  final List<ConsultantMessage> _messages = [
    ConsultantMessage(
      isAi: true,
      content:
          "我已分析了您的照片。这张夜景构图很稳，光线层次丰富。\n\n目前的风格偏向写实，您是想增强这种“电影氛围感”，还是想彻底改变风格（比如变成动漫或赛博朋克）？",
    ),
    ConsultantMessage(isAi: false, content: "我想让它看起来像雨天，更有赛博朋克的感觉。"),
    ConsultantMessage(
      isAi: true,
      content: "明白了。增加“雨天湿地反射”效果，并强化霓虹灯的“蓝紫色调”。\n\n还需要添加一些科幻元素（如全息投影）来丰富细节吗？",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Matte Black
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // --- 1. Top Header ---
            _buildHeader(),

            // --- 2. Image Preview Panel (Fixed Top) ---
            // 核心修改：将图片放在 Column 中，固定在对话上方，不再遮挡
            _buildProjectContextPanel(),

            // --- 3. Chat Area ---
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

            // --- 4. Bottom Interaction Area ---
            _buildBottomArea(),
          ],
        ),
      ),
    );
  }

  // --- 顶部导航栏 ---
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

  // --- 🔥 核心修改：项目看板区域 ---
  // 图片固定在这里，不会随对话滚动，也不会遮挡文字
  Widget _buildProjectContextPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181818), // 比背景稍亮一点，区分区域
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
          // 1. 左侧：大缩略图卡片
          Container(
            width: 100, // 足够大的尺寸
            height: 130, // 4:3 比例
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

                  // "Original" 标签
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

          // 2. 右侧：项目信息
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
                // 模拟的 AI 分析标签
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
                  "The AI is ready to receive your instructions.",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 辅助 Tag 组件
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

          // Bubble Content
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
              child: Text(
                msg.content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
          ),

          if (!msg.isAi) const SizedBox(width: 4),
        ],
      ),
    );
  }

  // --- 底部交互区 ---
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
          // 1. Confirm Button
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

          // 2. Input Row
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
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Send Button
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
                  onPressed: () {
                    if (_textController.text.isNotEmpty) {
                      setState(() {
                        _messages.add(
                          ConsultantMessage(
                            isAi: false,
                            content: _textController.text,
                          ),
                        );
                        _textController.clear();
                        Future.delayed(const Duration(milliseconds: 100), () {
                          _scrollController.animateTo(
                            _scrollController.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        });
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
