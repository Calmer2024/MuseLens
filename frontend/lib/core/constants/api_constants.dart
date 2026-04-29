import 'package:flutter/foundation.dart';

class ApiConstants {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'PUBLIC_API_BASE_URL',
  );

  static String get baseUrl {
    final configured = _configuredBaseUrl.trim();
    if (configured.isNotEmpty) {
      return _stripTrailingSlash(configured);
    }
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  static Uri webSocketUri(String path) {
    final baseUri = Uri.parse(baseUrl);
    final scheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    return baseUri.replace(
      scheme: scheme,
      path: path,
      query: null,
      fragment: null,
    );
  }

  static String rewriteLoopbackUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return raw;
    final host = uri.host.trim();
    if (host != '127.0.0.1' && host != 'localhost') {
      return raw;
    }

    final baseUri = Uri.parse(baseUrl);
    final updated = uri.replace(
      scheme: baseUri.scheme,
      host: baseUri.host,
      port: baseUri.hasPort ? baseUri.port : null,
    );
    return updated.toString();
  }

  static String _stripTrailingSlash(String value) {
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }
}
