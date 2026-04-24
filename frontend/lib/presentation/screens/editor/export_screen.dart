import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/editor/publish_template_dialog.dart';
import '../../widgets/shared/adaptive_media.dart';

/// 导出成功界面 —— 参考美图秀秀导出页设计，使用 MuseLens 主题配色
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({
    super.key,
    required this.exportedImagePath,
    this.projectId,
    this.currentNodeId,
  });

  /// 已导出到本地相册的图片路径
  final String exportedImagePath;

  /// 资产树项目 ID（用于发布模板）
  final String? projectId;

  /// 当前节点 ID（用于发布模板）
  final String? currentNodeId;

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(_fadeAnimation);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _showComingSoon(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name 功能开发中，敬请期待'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleEditAnother() {
    // 返回到编辑器
    Navigator.of(context).pop();
  }

  void _handleGoHome() {
    // 返回到首页（弹出所有路由直到根）
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _handlePublishToMarket() async {
    final user = ref.read(authProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录后再上传到模板市场')),
      );
      return;
    }

    final nodeId = widget.currentNodeId;
    if (nodeId == null || nodeId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前画面尚未保存到资产树，请先保存后再发布')),
      );
      return;
    }

    if (!mounted) return;
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PublishTemplateDialog(
        resultNodeId: nodeId,
        projectId: widget.projectId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060609),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF1A1324),
              Color(0xFF0F0A16),
              Color(0xFF060609),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, 0.35, 1],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  // --- 顶部导航栏 ---
                  _buildTopBar(),

                  // --- 主内容 ---
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),

                          // --- 导出成功提示 ---
                          _buildSuccessBadge(),
                          const SizedBox(height: 24),

                          // --- 图片预览 ---
                          _buildImagePreview(),
                          const SizedBox(height: 28),

                          // --- 操作按钮 ---
                          _buildActionButtons(),
                          const SizedBox(height: 32),

                          // --- 分享区域 ---
                          _buildShareSection(),
                          const SizedBox(height: 32),

                          // --- 精选功能 ---
                          _buildFeatureSection(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 14, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: Colors.white70, size: 20),
          ),
          const Spacer(),
          InkWell(
            onTap: _handleGoHome,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.home_rounded, color: Colors.white70, size: 16),
                  SizedBox(width: 4),
                  Text(
                    '首页',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.electricIndigo.withValues(alpha: 0.18),
            const Color(0xFF9B59B6).withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.electricIndigo.withValues(alpha: 0.3),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded,
              color: Color(0xFF7C6FF0), size: 18),
          SizedBox(width: 6),
          Text(
            '已保存到相册',
            style: TextStyle(
              color: Color(0xFFB8ADFF),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 320),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.electricIndigo.withValues(alpha: 0.15),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: buildAdaptiveImage(
          widget.exportedImagePath,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // 再修一张
        SizedBox(
          width: double.infinity,
          height: 52,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFF8E7CF3)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.electricIndigo.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FilledButton(
              onPressed: _handleEditAnother,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                '再修一张',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 上传到模板市场
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _handlePublishToMarket,
            icon: const Icon(Icons.cloud_upload_rounded, size: 20),
            label: const Text(
              '上传到模板市场',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1.2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShareSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '分享到',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _ShareIcon(
                icon: Icons.photo_album_rounded,
                label: '闪传相册',
                color: const Color(0xFF3498DB),
                onTap: () => _showComingSoon('闪传相册'),
              ),
              _ShareIcon(
                icon: Icons.chat_rounded,
                label: '微信好友',
                color: const Color(0xFF2ECC71),
                onTap: () => _showComingSoon('微信好友'),
              ),
              _ShareIcon(
                icon: Icons.group_rounded,
                label: '朋友圈',
                color: const Color(0xFF27AE60),
                onTap: () => _showComingSoon('朋友圈'),
              ),
              _ShareIcon(
                icon: Icons.music_note_rounded,
                label: '抖音',
                color: const Color(0xFFE74C3C),
                onTap: () => _showComingSoon('抖音'),
              ),
              _ShareIcon(
                icon: Icons.auto_stories_rounded,
                label: '小红书',
                color: const Color(0xFFE74C3C),
                onTap: () => _showComingSoon('小红书'),
              ),
              _ShareIcon(
                icon: Icons.question_answer_rounded,
                label: 'QQ',
                color: const Color(0xFF3498DB),
                onTap: () => _showComingSoon('QQ'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '精选功能',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _FeatureCard(
              icon: Icons.dashboard_customize_rounded,
              label: '海报设计',
              color: const Color(0xFF6C5CE7),
              onTap: () => _showComingSoon('海报设计'),
            ),
            const SizedBox(width: 12),
            _FeatureCard(
              icon: Icons.auto_fix_high_rounded,
              label: '帮我修图',
              color: const Color(0xFFE84393),
              onTap: () => _showComingSoon('帮我修图'),
            ),
            const SizedBox(width: 12),
            _FeatureCard(
              icon: Icons.badge_rounded,
              label: '证件照',
              color: const Color(0xFF00B894),
              onTap: () => _showComingSoon('证件照'),
            ),
            const SizedBox(width: 12),
            _FeatureCard(
              icon: Icons.diamond_rounded,
              label: '会员中心',
              color: const Color(0xFFFDAA5E),
              onTap: () => _showComingSoon('会员中心'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ShareIcon extends StatelessWidget {
  const _ShareIcon({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 60,
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: color.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
