import 'package:flutter/foundation.dart';

class ApiConstants {
  // iOS/Windows 模拟器用 localhost
  // Android 模拟器必须使用 10.0.2.2 来访问电脑
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }
}

