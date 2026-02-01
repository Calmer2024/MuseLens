import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';

class ChatHistoryDrawer extends StatelessWidget {
  const ChatHistoryDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    // 模拟的对话历史数据 (数据内容为中文)
    final List<Map<String, String>> historyItems = [
      {
        "summary": "把这张图改成赛博朋克风...",
        "user": "把这张图改成赛博朋克风，加点霓虹灯。",
        "ai": "已应用“霓虹东京”滤镜，并增强了画面对比度与蓝紫色调。",
      },
      {
        "summary": "帮我把背景换成埃菲尔铁塔...",
        "user": "帮我把背景换成埃菲尔铁塔，要黄昏的感觉。",
        "ai": "已完成背景替换，并调整了光影以匹配黄昏氛围。",
      },
      {
        "summary": "这张照片太模糊了，修清楚一点...",
        "user": "这张照片太模糊了，能修清楚一点吗？",
        "ai": "已使用超清画质增强功能，面部细节已修复。",
      },
      {
        "summary": "去掉路人，只保留主角...",
        "user": "把后面的路人去掉，只保留主角。",
        "ai": "已移除背景中的干扰人物，并自动填充了背景。",
      },
      {
        "summary": "想要一种胶片电影的感觉...",
        "user": "想要一种王家卫电影那种胶片质感。",
        "ai": "已添加颗粒质感与复古滤镜，色调已调整。",
      },
    ];

    return Drawer(
      backgroundColor: const Color(0xFF1E1E1E),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header: History ---
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                "History", // UI 保持英文
                style: GoogleFonts.orbitron(
                  textStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const Divider(color: Colors.white10),

            // --- List: Sessions ---
            Expanded(
              child: ListView.builder(
                itemCount: historyItems.length,
                itemBuilder: (context, index) {
                  final item = historyItems[index];
                  // Session 编号倒序显示 (Session #5, #4...)
                  final sessionNumber = historyItems.length - index;

                  return Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      leading: const Icon(
                        Icons.chat_bubble_outline,
                        color: AppTheme.electricIndigo,
                      ),
                      title: Text(
                        "Project Session #$sessionNumber", // UI 保持英文
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        item["summary"]!, // 数据显示中文
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      iconColor: AppTheme.electricIndigo,
                      collapsedIconColor: Colors.white54,
                      children: [
                        // 展开后的具体对话内容
                        Container(
                          color: Colors.black26,
                          padding: const EdgeInsets.all(16),
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHistoryMsg(
                                "User", // UI 保持英文
                                item["user"]!, // 数据显示中文
                              ),
                              const SizedBox(height: 8),
                              _buildHistoryMsg(
                                "AI", // UI 保持英文
                                item["ai"]!, // 数据显示中文
                              ),
                              const SizedBox(height: 12),

                              // 恢复会话按钮
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text(
                                    "Restore Session", // UI 保持英文
                                    style: TextStyle(
                                      color: AppTheme.electricIndigo,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryMsg(String role, String msg) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: "$role: ",
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          TextSpan(
            text: msg,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
