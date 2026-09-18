import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class StorageManager {
  static Future<Directory> getDateUserDirectory(String username) async {
    final baseDir = await getApplicationDocumentsDirectory();
    final todayStr = DateFormat("dd-MM-yyyy").format(DateTime.now());
    final subfolderName = "$todayStr & $username";

    final targetDir = Directory("${baseDir.path}/CaptureProPhotos/$subfolderName");
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    return targetDir;
  }

  static Future<int> getTagCount(String username, String tagNo) async {
    if (tagNo.trim().isEmpty) return 0;
    try {
      final dir = await getDateUserDirectory(username);
      final files = dir.listSync();
      final tagPrefix = tagNo.trim().toLowerCase();

      int count = 0;
      for (var file in files) {
        if (file is File) {
          final fileName = file.uri.pathSegments.last.toLowerCase();
          if (fileName.startsWith(tagPrefix)) {
            count++;
          }
        }
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  static Future<String?> getLastImagePath(String username, String tagNo) async {
    if (tagNo.trim().isEmpty) return null;
    try {
      final dir = await getDateUserDirectory(username);
      final files = dir.listSync();
      final tagPrefix = tagNo.trim().toLowerCase();

      File? lastFile;
      DateTime? latestTime;

      for (var file in files) {
        if (file is File) {
          final fileName = file.uri.pathSegments.last.toLowerCase();
          if (fileName.startsWith(tagPrefix)) {
            final modTime = await file.lastModified();
            if (latestTime == null || modTime.isAfter(latestTime)) {
              latestTime = modTime;
              lastFile = file;
            }
          }
        }
      }
      return lastFile?.path;
    } catch (_) {
      return null;
    }
  }

  static Future<File> savePhoto({
    required String username,
    required String tagNo,
    required String imagePath,
    String? objectSize,
  }) async {
    final dir = await getDateUserDirectory(username);
    final count = await getTagCount(username, tagNo);
    final nextIndex = count + 1;

    final timestamp = DateFormat("yyyyMMdd_HHmmss").format(DateTime.now());
    final cleanTag = tagNo.trim().replaceAll(RegExp(r'[^\w\.-]'), '_');
    final fileName = "${cleanTag}_$nextIndex\_$timestamp.jpg";

    final savedFile = File("${dir.path}/$fileName");
    await File(imagePath).copy(savedFile.path);

    return savedFile;
  }
}
