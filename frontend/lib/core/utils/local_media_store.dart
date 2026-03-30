import 'dart:io';

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
