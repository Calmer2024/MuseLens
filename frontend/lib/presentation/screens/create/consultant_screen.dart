import 'package:flutter/material.dart';
import 'dart:io';
import '../../../core/theme/app_theme.dart';
import '../editor/editor_screen.dart';

// 模拟消息模型
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
      // 防止键盘顶起布局导致图片位置错乱，根据需要开启或关闭
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // --- 1. Top Header (Simplified) ---
            // 顶部只保留标题，缩略图移走
            _buildHeader(),

            // --- 2. Main Content Area (Stack) ---
            Expanded(
              child: Stack(
                children: [
                  // Layer A: Chat List
                  ListView.builder(
                    controller: _scrollController,
                    // 给顶部留出一点空间，或者给右侧留出一点空间防止遮挡(可选)
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 20,
                      bottom: 180, // 底部留白给浮动卡片和输入框，防止遮挡最后一条消息
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),

                  // Layer B: Floating Image Card (Right Middle)
                  // 放在右侧中部，稍微靠上一点，避免遮挡底部最新的对话
                  Positioned(
                    top: 20, // 距离 Header 底部 20
                    right: 16, // 距离右侧 16
                    child: _buildFloatingImageCard(),
                  ),
                ],
              ),
            ),

            // --- 3. Bottom Interaction Area ---
            _buildBottomArea(),
          ],
        ),
      ),
    );
  }

  // --- 悬浮图片卡片 (New Design) ---
  Widget _buildFloatingImageCard() {
    return Container(
      width: 120, // 卡片宽度加大
      height: 160, // 卡片高度加大 (4:3 比例左右)
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // 图片区域
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
              child: widget.selectedImagePath.startsWith('assets')
                  ? Image.asset(
                      widget.selectedImagePath,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    )
                  : Image.file(
                      File(widget.selectedImagePath),
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
            ),
          ),
          // 底部小标签
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF2A2A2A),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
            ),
            child: const Center(
              child: Text(
                "Original",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 顶部导航栏 ---
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
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
          // 右侧可以放一个 More 按钮或者留空
          const Icon(Icons.more_horiz, color: Colors.white),
        ],
      ),
    );
  }

  // --- 消息气泡 ---
  Widget _buildMessageBubble(ConsultantMessage msg) {
    // 为了防止气泡被右侧的大卡片遮挡，如果是用户消息(右侧)，可以增加右边距
    // 但因为卡片是悬浮的，有时遮挡也是一种设计风格(层级感)。
    // 这里我们稍微给 User 消息加一点 Right Padding 避让顶部区域
    // 实际更复杂的做法是计算位置，这里做简单处理。

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
              // 如果是第一条 AI 消息，为了不被右侧图片遮挡太多，可以限制一下最大宽度
              // 或者让它自然换行
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

          // 如果是用户消息，右侧留出一点空隙 (可选)
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
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
