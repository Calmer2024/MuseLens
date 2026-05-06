import 'package:flutter/foundation.dart';

class ApiConstants {
  static const String _defaultProductionBaseUrl =
      'https://api.ywtshuai.online';
  static const String _apiBaseUrlOverride =
      String.fromEnvironment('MUSELENS_API_BASE_URL', defaultValue: '');

  static String get baseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) {
      return _apiBaseUrlOverride;
    }
    if (kIsWeb) {
      return _defaultProductionBaseUrl;
    }
    // Android 模拟器本地联调可以用 --dart-define 覆盖为 10.0.2.2:8000。
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _defaultProductionBaseUrl;
    }
    return _defaultProductionBaseUrl;
  }

  static Uri get baseUri => Uri.parse(baseUrl);

  static Uri buildWebSocketUri(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return baseUri.replace(
      scheme: baseUri.scheme == 'https' ? 'wss' : 'ws',
      path: path,
      queryParameters: queryParameters?.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
      fragment: null,
    );
  }

  static Map<String, dynamic> normalizeLoopbackUrls(Map<String, dynamic> data) {
    return _normalizeNode(data) as Map<String, dynamic>;
  }

  static dynamic _normalizeNode(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value.map<String, dynamic>(
        (key, nested) => MapEntry<String, dynamic>(key, _normalizeNode(nested)),
      );
    }
    if (value is List<dynamic>) {
      return value.map<dynamic>(_normalizeNode).toList();
    }
    if (value is String) {
      return rewriteLoopbackUrl(value);
    }
    return value;
  }

  static String rewriteLoopbackUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return raw;

    final host = uri.host.trim();
    if (host != '127.0.0.1' && host != 'localhost') {
      return raw;
    }

    final updated = uri.replace(
      scheme: baseUri.scheme,
      host: baseUri.host,
      port: baseUri.hasPort ? baseUri.port : null,
    );
    return updated.toString();
  }
}

