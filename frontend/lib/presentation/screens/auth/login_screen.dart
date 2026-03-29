import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(authProvider.notifier).login(
            username: _usernameController.text.trim(),
            password: _passwordController.text,
          );
      if (mounted) {
        Navigator.of(context).pop(true); // 返回 true 表示登录成功
      }
    } on DioException catch (e) {
      if (mounted) {
        String message = context.tr('login_error');
        if (e.response?.statusCode == 401) {
          message = context.tr('login_error');
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

  void _goToRegister() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
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
                    AppTheme.electricIndigo.withOpacity(0.18),
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

                  const SizedBox(height: 20),

                  // Logo
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.electricIndigo.withOpacity(0.35),
                            blurRadius: 30,
                            spreadRadius: -5,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/app_icon.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ).animate().fade(duration: 500.ms).scale(
                        begin: const Offset(0.8, 0.8),
                        end: const Offset(1, 1),
                        duration: 500.ms,
                        curve: Curves.easeOutBack,
                      ),

                  const SizedBox(height: 28),

                  // 标题
                  Center(
                    child: Text(
                      context.tr('login'),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ).animate().fade(duration: 400.ms, delay: 100.ms),

                  const SizedBox(height: 8),

                  Center(
                    child: Text(
                      context.tr('login_prompt'),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ),
                  ).animate().fade(duration: 400.ms, delay: 200.ms),

                  const SizedBox(height: 40),

                  // 表单
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // 用户名
                        _buildInputField(
                          controller: _usernameController,
                          label: context.tr('username'),
                          icon: Icons.person_outline_rounded,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return context.tr('field_required');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        // 密码
                        _buildInputField(
                          controller: _passwordController,
                          label: context.tr('password'),
                          icon: Icons.lock_outline_rounded,
                          obscure: _obscurePassword,
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
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
                            return null;
                          },
                        ),
                      ],
                    ),
                  ).animate().fade(duration: 400.ms, delay: 300.ms).moveY(
                        begin: 20,
                        end: 0,
                        duration: 400.ms,
                        curve: Curves.easeOut,
                      ),

                  const SizedBox(height: 36),

                  // 登录按钮
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
                            onTap: _handleLogin,
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
                                    color:
                                        AppTheme.electricIndigo.withOpacity(0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  context.tr('login_button'),
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
                  ).animate().fade(duration: 400.ms, delay: 400.ms),

                  const SizedBox(height: 28),

                  // 去注册
                  Center(
                    child: GestureDetector(
                      onTap: _goToRegister,
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black.withOpacity(0.5),
                          ),
                          children: [
                            TextSpan(text: context.tr('no_account')),
                            const TextSpan(text: ' '),
                            TextSpan(
                              text: context.tr('register'),
                              style: const TextStyle(
                                color: AppTheme.electricIndigo,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).animate().fade(duration: 400.ms, delay: 500.ms),

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
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
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
