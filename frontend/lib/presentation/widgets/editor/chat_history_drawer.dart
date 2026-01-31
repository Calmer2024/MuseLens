import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // 需要引入 google_fonts
import '../../../../core/theme/app_theme.dart';

class ChatHistoryDrawer extends StatelessWidget {
  const ChatHistoryDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF1E1E1E),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                "History",
                // 字体保持一致 (Orbitron)
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
            Expanded(
              child: ListView.builder(
                itemCount: 5,
                itemBuilder: (context, index) {
                  // 使用 ExpansionTile 实现展开详情
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
                        "Project Session #${5 - index}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        "Make it cyberpunk style...",
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
                                "User",
                                "Make it cyberpunk style with neon lights.",
                              ),
                              const SizedBox(height: 8),
                              _buildHistoryMsg(
                                "AI",
                                "I've applied a Neon Tokyo filter and adjusted the contrast.",
                              ),
                              const SizedBox(height: 12),
                              // 恢复会话按钮
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text(
                                    "Restore Session",
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
