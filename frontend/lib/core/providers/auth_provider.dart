import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/user_model.dart';
import '../../data/models/providers/services/api_client.dart';
import '../../data/models/providers/services/user_api_service.dart';

// ─────────────────────────────────────────────────────
// SharedPreferences Provider
// ─────────────────────────────────────────────────────
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main()');
});

// ─────────────────────────────────────────────────────
// User API Service Provider
// ─────────────────────────────────────────────────────
final userApiServiceProvider = Provider<UserApiService>((ref) {
  return UserApiService();
});

// ─────────────────────────────────────────────────────
// Auth Notifier
// ─────────────────────────────────────────────────────
class AuthNotifier extends Notifier<User?> {
  late SharedPreferences _prefs;
  late UserApiService _apiService;

  @override
  User? build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    _apiService = ref.watch(userApiServiceProvider);

    final userJson = _prefs.getString(ApiClient.userKey);
    if (userJson != null && userJson.isNotEmpty) {
      try {
        return User.fromJsonString(userJson);
      } catch (_) {
        _prefs.remove(ApiClient.userKey);
      }
    }
    return null;
  }

  /// 登录
  Future<void> login({
    required String username,
    required String password,
  }) async {
    final result = await _apiService.login(
      username: username,
      password: password,
    );

    // 如果后端返回 token，保存
    if (result.token != null) {
      await ApiClient.saveToken(result.token!);
    }

    // 缓存用户信息
    await _prefs.setString(ApiClient.userKey, result.user.toJsonString());
    state = result.user;
  }

  /// 注册 → 自动登录
  Future<void> register({
    required String username,
    required String password,
    String? nickname,
    String? email,
    String? bio,
  }) async {
    // 1. 注册
    await _apiService.register(
      username: username,
      password: password,
      nickname: nickname,
      email: email,
      bio: bio,
    );

    // 2. 注册成功后自动登录
    await login(username: username, password: password);
  }

  /// 退出登录
  Future<void> logout() async {
    await _prefs.remove(ApiClient.userKey);
    await ApiClient.clearToken();
    state = null;
  }

  /// 更新用户资料
  Future<void> updateProfile(Map<String, dynamic> updates) async {
    if (state == null) return;

    final updatedUser = await _apiService.updateUser(state!.userId, updates);
    await _prefs.setString(ApiClient.userKey, updatedUser.toJsonString());
    state = updatedUser;
  }

  /// 从后端刷新用户数据
  Future<void> refreshUser() async {
    if (state == null) return;

    try {
      final freshUser = await _apiService.getUserById(state!.userId);
      await _prefs.setString(ApiClient.userKey, freshUser.toJsonString());
      state = freshUser;
    } catch (_) {
      // 静默失败，保留缓存数据
    }
  }
}

// ─────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────

/// 当前登录用户（null = 访客态）
final authProvider = NotifierProvider<AuthNotifier, User?>(() {
  return AuthNotifier();
});

/// 是否已登录
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authProvider) != null;
});
