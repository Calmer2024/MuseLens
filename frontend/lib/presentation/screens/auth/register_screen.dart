import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'login_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nicknameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(authProvider.notifier).register(
            username: _usernameController.text.trim(),
            password: _passwordController.text,
            nickname: _nicknameController.text.trim().isEmpty
                ? null
                : _nicknameController.text.trim(),
            email: _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
            bio: _bioController.text.trim().isEmpty
                ? null
                : _bioController.text.trim(),
          );
      if (mounted) {
        Navigator.of(context).pop(true); // 返回 true 表示注册+登录成功
      }
    } on DioException catch (e) {
      if (mounted) {
        String message = context.tr('register_error_username');
        if (e.response?.statusCode == 409) {
          final data = e.response?.data;
          if (data is Map && data['detail'] != null) {
            final detail = data['detail'].toString().toLowerCase();
            if (detail.contains('email') || detail.contains('邮箱')) {
              message = context.tr('register_error_email');
            }
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 顶部紫色光晕
          Positioned(
            top: -120,
            left: -50,
            right: -50,
            child: Container(
              height: 350,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 0.9,
                  colors: [
                    AppTheme.electricIndigo.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // 关闭按钮
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.black54,
                          size: 20,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 标题
                  Center(
                    child: Text(
                      context.tr('register'),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ).animate().fade(duration: 400.ms),

                  const SizedBox(height: 32),

                  // 表单
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // 用户名 *
                        _buildInputField(
                          controller: _usernameController,
                          label: '${context.tr('username')} *',
                          icon: Icons.person_outline_rounded,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return context.tr('field_required');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // 密码 *
                        _buildInputField(
                          controller: _passwordController,
                          label: '${context.tr('password')} *',
                          icon: Icons.lock_outline_rounded,
                          obscure: _obscurePassword,
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: Colors.black38,
                              size: 20,
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return context.tr('field_required');
                            }
                            if (v.length < 6) {
                              return '密码至少需要6个字符';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // 确认密码 *
                        _buildInputField(
                          controller: _confirmPasswordController,
                          label: '${context.tr('confirm_password')} *',
                          icon: Icons.lock_outline_rounded,
                          obscure: _obscureConfirm,
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm),
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: Colors.black38,
                              size: 20,
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return context.tr('field_required');
                            }
                            if (v != _passwordController.text) {
                              return context.tr('password_mismatch');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // 昵称（可选）
                        _buildInputField(
                          controller: _nicknameController,
                          label: context.tr('nickname'),
                          icon: Icons.badge_outlined,
                        ),
                        const SizedBox(height: 14),

                        // 邮箱（可选）
                        _buildInputField(
                          controller: _emailController,
                          label: context.tr('email'),
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 14),

                        // 个人简介（可选）
                        _buildInputField(
                          controller: _bioController,
                          label: context.tr('bio'),
                          icon: Icons.notes_rounded,
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ).animate().fade(duration: 400.ms, delay: 150.ms).moveY(
                        begin: 20,
                        end: 0,
                        duration: 400.ms,
                        curve: Curves.easeOut,
                      ),

                  const SizedBox(height: 32),

                  // 注册按钮
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.electricIndigo,
                              strokeWidth: 2.5,
                            ),
                          )
                        : GestureDetector(
                            onTap: _handleRegister,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: const LinearGradient(
                                  colors: [
                                    AppTheme.electricIndigo,
                                    Color(0xFF584CF4),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.electricIndigo
                                        .withOpacity(0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  context.tr('register_button'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 17,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ).animate().fade(duration: 400.ms, delay: 300.ms),

                  const SizedBox(height: 24),

                  // 已有账号 → 登录
                  Center(
                    child: GestureDetector(
                      onTap: _goToLogin,
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black.withOpacity(0.5),
                          ),
                          children: [
                            TextSpan(text: context.tr('have_account')),
                            const TextSpan(text: ' '),
                            TextSpan(
                              text: context.tr('login'),
                              style: const TextStyle(
                                color: AppTheme.electricIndigo,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).animate().fade(duration: 400.ms, delay: 400.ms),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: obscure ? 1 : maxLines,
      style: const TextStyle(fontSize: 15, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.black.withOpacity(0.4),
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, color: Colors.black38, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppTheme.electricIndigo, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
    );
  }
}
