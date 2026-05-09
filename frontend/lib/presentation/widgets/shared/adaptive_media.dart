import 'dart:io';

import 'package:flutter/material.dart';

bool isAdaptiveLocalFilePath(String path) {
  final trimmed = path.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return false;
  }
  return trimmed.startsWith('file://') ||
      trimmed.startsWith('/') ||
      trimmed.contains(':\\') ||
      trimmed.contains(':/');
}

String normalizeAdaptiveFilePath(String path) {
  final trimmed = path.trim();
  if (trimmed.startsWith('file://')) {
    return trimmed.substring(7);
  }
  return trimmed;
}

ImageProvider? resolveAdaptiveImageProvider(String? path) {
  final trimmed = path?.trim() ?? '';
  if (trimmed.isEmpty) {
    return null;
  }
  if (trimmed.startsWith('http')) {
    return NetworkImage(trimmed);
  }
  if (isAdaptiveLocalFilePath(trimmed)) {
    return FileImage(File(normalizeAdaptiveFilePath(trimmed)));
  }
  return AssetImage(trimmed);
}

Widget buildAdaptiveImage(
  String? path, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  Widget? placeholder,
  Widget? errorWidget,
  ImageFrameBuilder? frameBuilder,
  ImageLoadingBuilder? loadingBuilder,
}) {
  final trimmed = path?.trim() ?? '';
  final fallback = errorWidget ?? placeholder ?? const SizedBox.shrink();

  if (trimmed.isEmpty) {
    return SizedBox(
      width: width,
      height: height,
      child: placeholder ?? fallback,
    );
  }

  if (trimmed.startsWith('http')) {
    return Image.network(
      trimmed,
      fit: fit,
      width: width,
      height: height,
      frameBuilder: frameBuilder,
      loadingBuilder: loadingBuilder,
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  if (isAdaptiveLocalFilePath(trimmed)) {
    return Image.file(
      File(normalizeAdaptiveFilePath(trimmed)),
      fit: fit,
      width: width,
      height: height,
      frameBuilder: frameBuilder,
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  return Image.asset(
    trimmed,
    fit: fit,
    width: width,
    height: height,
    frameBuilder: frameBuilder,
    errorBuilder: (_, __, ___) => fallback,
  );
}
