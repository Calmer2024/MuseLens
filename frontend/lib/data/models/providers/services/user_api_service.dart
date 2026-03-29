import 'package:dio/dio.dart';
import '../../user_model.dart';
import '../../user_summary_model.dart';
import 'api_client.dart';

class UserApiService {
  final Dio _dio = ApiClient().dio;
  static const String _basePath = '/api/v1/users';

  // ──────────────────────────────────────────────
  // 1. 注册用户
  // POST /api/v1/users/register
  // ──────────────────────────────────────────────
  Future<User> register({
    required String username,
    required String password,
    String? nickname,
    String? email,
    String? bio,
  }) async {
    final response = await _dio.post(
      '$_basePath/register',
      data: {
        'username': username,
        'password': password,
        if (nickname != null) 'nickname': nickname,
        if (email != null) 'email': email,
        if (bio != null) 'bio': bio,
      },
    );
    return User.fromJson(response.data as Map<String, dynamic>);
  }

  // ──────────────────────────────────────────────
  // 2. 用户登录
  // POST /api/v1/users/login
  // ──────────────────────────────────────────────
  Future<LoginResult> login({
    required String username,
    required String password,
  }) async {
    final response = await _dio.post(
      '$_basePath/login',
      data: {
        'username': username,
        'password': password,
      },
    );
    final data = response.data as Map<String, dynamic>;
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    // 如果后端返回 token 字段，保存它
    final token = data['token'] as String?;
    return LoginResult(user: user, token: token);
  }

  // ──────────────────────────────────────────────
  // 3. 获取用户详情
  // GET /api/v1/users/{user_id}
  // ──────────────────────────────────────────────
  Future<User> getUserById(int userId) async {
    final response = await _dio.get('$_basePath/$userId');
    return User.fromJson(response.data as Map<String, dynamic>);
  }

  // ──────────────────────────────────────────────
  // 4. 更新用户资料
  // PATCH /api/v1/users/{user_id}
  // ──────────────────────────────────────────────
  Future<User> updateUser(int userId, Map<String, dynamic> updates) async {
    final response = await _dio.patch(
      '$_basePath/$userId',
      data: updates,
    );
    return User.fromJson(response.data as Map<String, dynamic>);
  }

  // ──────────────────────────────────────────────
  // 5. 关注用户
  // POST /api/v1/users/{user_id}/follow
  // ──────────────────────────────────────────────
  Future<void> followUser(int targetUserId, int followerId) async {
    await _dio.post(
      '$_basePath/$targetUserId/follow',
      data: {'follower_id': followerId},
    );
  }

  // ──────────────────────────────────────────────
  // 6. 取消关注
  // DELETE /api/v1/users/{user_id}/follow
  // ──────────────────────────────────────────────
  Future<void> unfollowUser(int targetUserId, int followerId) async {
    await _dio.delete(
      '$_basePath/$targetUserId/follow',
      data: {'follower_id': followerId},
    );
  }

  // ──────────────────────────────────────────────
  // 7. 获取粉丝列表
  // GET /api/v1/users/{user_id}/followers
  // ──────────────────────────────────────────────
  Future<List<UserSummary>> getFollowers(int userId) async {
    final response = await _dio.get('$_basePath/$userId/followers');
    return UserSummary.fromJsonList(response.data as List<dynamic>);
  }

  // ──────────────────────────────────────────────
  // 8. 获取关注列表
  // GET /api/v1/users/{user_id}/following
  // ──────────────────────────────────────────────
  Future<List<UserSummary>> getFollowing(int userId) async {
    final response = await _dio.get('$_basePath/$userId/following');
    return UserSummary.fromJsonList(response.data as List<dynamic>);
  }
}

/// 登录结果，包含用户对象和可选的 Token
class LoginResult {
  final User user;
  final String? token;

  LoginResult({required this.user, this.token});
}
