import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/api_constants.dart';
import '../models/providers/services/api_client.dart';

/// 上传结果
class UploadResult {
  final String objectRef;
  final String downloadUrl;

  const UploadResult({required this.objectRef, required this.downloadUrl});

  factory UploadResult.fromJson(Map<String, dynamic> json) {
    return UploadResult(
      objectRef: json['object_ref'] as String,
      downloadUrl: json['download_url'] as String,
    );
  }
}

/// 图片上传服务 — 将图片上传到后端 MinIO，返回可跨设备访问的 URL。
class UploadService {
  UploadService._();
  static final UploadService instance = UploadService._();

  Dio get _dio => ApiClient().dio;

  /// 将 [File] 上传到后端对象存储。
  Future<UploadResult> uploadImageFile(
    File file, {
    required String purpose,
  }) async {
    final filename = file.path.split(Platform.pathSeparator).last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: filename),
      'purpose': purpose,
    });
    final response = await _dio.post('/api/v1/uploads/image', data: formData);
    return UploadResult.fromJson(response.data as Map<String, dynamic>);
  }

  /// 将 [XFile]（来自 image_picker）上传。
  Future<UploadResult> uploadXFile(
    XFile xfile, {
    required String purpose,
  }) {
    return uploadImageFile(File(xfile.path), purpose: purpose);
  }

  /// 将内存中的 [Uint8List] 上传。
  Future<UploadResult> uploadBytes(
    Uint8List bytes, {
    required String purpose,
    String filename = 'upload.png',
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
      'purpose': purpose,
    });
    final response = await _dio.post('/api/v1/uploads/image', data: formData);
    return UploadResult.fromJson(response.data as Map<String, dynamic>);
  }

  /// 将 download_url 处理成绝对 URL（对 proxy 相对路径补全 baseUrl）。
  static String resolveDownloadUrl(String downloadUrl) {
    if (downloadUrl.startsWith('http://') ||
        downloadUrl.startsWith('https://')) {
      return ApiConstants.rewriteLoopbackUrl(downloadUrl);
    }
    // 相对路径，如 /api/v1/storage/object?ref=...
    return '${ApiConstants.baseUrl}$downloadUrl';
  }
}
