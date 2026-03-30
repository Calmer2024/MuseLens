import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class LocalMediaStore {
  static Future<String> persistXFile(
    XFile file, {
    required String folder,
    String prefix = 'media',
  }) {
    return persistFile(File(file.path), folder: folder, prefix: prefix);
  }

  static Future<String> persistFile(
    File source, {
    required String folder,
    String prefix = 'media',
  }) async {
    if (!await source.exists()) {
      throw FileSystemException('Source file does not exist', source.path);
    }

    final baseDirectory = await getApplicationSupportDirectory();
    final targetDirectory = Directory(
      '${baseDirectory.path}${Platform.pathSeparator}media'
      '${Platform.pathSeparator}$folder',
    );
    await targetDirectory.create(recursive: true);

    final extension = _extractExtension(source.path);
    final fileName =
        '${prefix}_${DateTime.now().microsecondsSinceEpoch}$extension';
    final targetPath =
        '${targetDirectory.path}${Platform.pathSeparator}$fileName';
    final copiedFile = await source.copy(targetPath);
    final normalizedPath = copiedFile.path.replaceAll('\\', '/');
    return 'file://$normalizedPath';
  }

  static Future<String> persistBytes(
    Uint8List bytes, {
    required String folder,
    String prefix = 'media',
    String extension = '.png',
  }) async {
    final baseDirectory = await getApplicationSupportDirectory();
    final targetDirectory = Directory(
      '${baseDirectory.path}${Platform.pathSeparator}media'
      '${Platform.pathSeparator}$folder',
    );
    await targetDirectory.create(recursive: true);

    final safeExtension = extension.startsWith('.') ? extension : '.$extension';
    final fileName =
        '${prefix}_${DateTime.now().microsecondsSinceEpoch}$safeExtension';
    final targetPath =
        '${targetDirectory.path}${Platform.pathSeparator}$fileName';
    final targetFile = File(targetPath);
    await targetFile.writeAsBytes(bytes, flush: true);
    final normalizedPath = targetFile.path.replaceAll('\\', '/');
    return 'file://$normalizedPath';
  }

  static String _extractExtension(String path) {
    final normalized = path.replaceAll('\\', '/');
    final lastDotIndex = normalized.lastIndexOf('.');
    final lastSlashIndex = normalized.lastIndexOf('/');
    if (lastDotIndex <= lastSlashIndex) {
      return '.jpg';
    }
    return normalized.substring(lastDotIndex);
  }
}
