import 'package:flutter/material.dart';
import 'dart:ui'; // 用于 ImageFilter
import '../../../core/theme/app_theme.dart';
import '../../../data/models/lens_template_mock.dart';
import '../lens/lens_detail_screen.dart'; // Lens 详情页
import 'community_screen.dart'; // 引用 CommunityPostMock
import 'post_detail_screen.dart'; // 帖子详情页

// 消息类型枚举
enum MessageType { text, lens, post }

// 简单的消息模型
class ChatMessageMock {
  final bool isMe;
  final MessageType type;
  final String content; // 文本内容 或 Lens名称
  final String? imageUrl; // 图片链接
  final String time; // --- 新增：时间字段 ---
  final dynamic data; // 关联的数据对象 (LensTemplateMock 或 CommunityPostMock)

  ChatMessageMock({
    required this.isMe,
    required this.type,
    required this.content,
    required this.time, // --- 新增 ---
    this.imageUrl,
    this.data,
  });
}

class ChatDetailScreen extends StatefulWidget {
  final String userName;
  final String avatarUrl;

  const ChatDetailScreen({
    super.key,
    required this.userName,
    required this.avatarUrl,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _textController = TextEditingController();
  late List<ChatMessageMock> _messages;

  @override
  void initState() {
    super.initState();
    // --- 模拟对话数据 (中文 + 时间) ---

    // 获取一些 Mock 数据用于跳转
    final mockLens = LensTemplateMock.getTemplates().isNotEmpty
        ? LensTemplateMock.getTemplates().first
        : null;

    final mockPost = CommunityPostMock.getPosts().isNotEmpty
        ? CommunityPostMock.getPosts().first
        : null;

    _messages = [
      ChatMessageMock(
        isMe: false,
        type: MessageType.text,
        content: "嘿！你试过那个最新的 V2 更新了吗？",
        time: "上午 10:20",
      ),
      ChatMessageMock(
        isMe: true,
        type: MessageType.text,
        content: "试了！效果太惊艳了。看看我刚修的这张图，感觉完全不一样了。",
        time: "上午 10:22",
      ),
      // 模拟对方分享了一个 Lens
      if (mockLens != null)
        ChatMessageMock(
          isMe: false,
          type: MessageType.lens,
          content: "霓虹东京 V2",
          imageUrl: mockLens.beforeImage,
          time: "上午 10:25",
          data: mockLens,
        ),
      // 模拟我分享了一个帖子
      if (mockPost != null)
        ChatMessageMock(
          isMe: true,
          type: MessageType.post,
          content: "夜之城街拍",
          imageUrl: mockPost.imageUrl,
          time: "上午 10:30",
          data: mockPost,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // 纯黑背景
      body: SafeArea(
        top: false, // 让 Header 延伸到顶部
        child: Column(
          children: [
            // 1. 自定义顶部导航栏
            _buildHeader(context),

            // 2. 消息列表
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  // 可以在这里添加逻辑：如果当前消息和上一条间隔很久，先显示一个居中的时间标签
                  return _buildMessageRow(msg);
                },
              ),
            ),

            // 3. 底部输入栏
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  // --- 顶部导航栏 ---
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 12,
        left: 16,
        right: 16,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF121212), // Matte Black
        border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 16),
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey[800],
            backgroundImage: _getImageProvider(widget.avatarUrl),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: const [
                    Icon(Icons.circle, size: 8, color: Colors.greenAccent),
                    SizedBox(width: 4),
                    Text(
                      "在线",
                      style: TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.more_horiz, color: Colors.white),
        ],
      ),
    );
  }

  // --- 消息行构建器 (UI 优化核心) ---
  Widget _buildMessageRow(ChatMessageMock msg) {
    // 决定气泡内容
    Widget bubbleContent;
    if (msg.type == MessageType.text) {
      bubbleContent = _buildTextBubble(msg);
    } else if (msg.type == MessageType.lens) {
      bubbleContent = _buildLensCard(msg);
    } else {
      bubbleContent = _buildPostCard(msg);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: msg.isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end, // 底部对齐
        children: [
          // 使用 Column 垂直排列：气泡在上，时间在下
          Column(
            crossAxisAlignment: msg.isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              // 气泡主体
              bubbleContent,
              const SizedBox(height: 4),
              // 时间标签
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  msg.time,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 1. 文本气泡
  Widget _buildTextBubble(ChatMessageMock msg) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: msg.isMe ? AppTheme.electricIndigo : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(msg.isMe ? 20 : 4),
          bottomRight: Radius.circular(msg.isMe ? 4 : 20),
        ),
      ),
      child: Text(
        msg.content,
        style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
      ),
    );
  }

  // 2. Lens 分享卡片
  Widget _buildLensCard(ChatMessageMock msg) {
    return GestureDetector(
      onTap: () {
        if (msg.data is LensTemplateMock) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LensDetailScreen(template: msg.data),
            ),
          );
        }
      },
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.electricIndigo.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.electricIndigo.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // 左侧：图片缩略图
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                image: DecorationImage(
                  image: _getImageProvider(msg.imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
              child: Center(
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.compare_arrows,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 右侧：标题和按钮
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.content,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.electricIndigo,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "去修图",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. 帖子分享卡片
  Widget _buildPostCard(ChatMessageMock msg) {
    final post = msg.data as CommunityPostMock;

    return GestureDetector(
      onTap: () {
        if (msg.data is CommunityPostMock) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostDetailScreen(post: msg.data),
            ),
          );
        }
      },
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 3.1 顶部大图
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: Image(
                  image: _getImageProvider(msg.imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // 3.2 底部内容区
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.grey[800],
                        backgroundImage: _getImageProvider(post.authorAvatar),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          post.authorName,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 底部输入栏 ---
  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      color: const Color(0xFF121212),
      child: Row(
        children: [
          const Icon(Icons.mic_none, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Center(
                child: TextField(
                  controller: _textController,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: AppTheme.electricIndigo,
                  decoration: const InputDecoration(
                    hintText: "发消息...",
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.emoji_emotions_outlined,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppTheme.electricIndigo,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.send_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider _getImageProvider(String? url) {
    if (url == null || url.isEmpty) {
      return const NetworkImage("https://via.placeholder.com/150");
    }
    if (url.startsWith('http')) {
      return NetworkImage(url);
    } else {
      return AssetImage(url);
    }
  }
}
