import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class ImageCompressionService {
  ImageCompressionService._();

  /// 🔹 Public API — use this everywhere
  static Future<File?> compressProfileImage({
    required File originalFile,
    int quality = 75, // caller can pass anything
  }) async {
    try {
      // ✅ HARD PRODUCTION SAFETY (60–80 ONLY)
      final int safeQuality = quality.clamp(60, 80);

      final tempDir = await getTemporaryDirectory();

      final targetPath = path.join(
        tempDir.path,
        _buildCompressedFileName(originalFile),
      );

      final compressedBytes = await FlutterImageCompress.compressWithFile(
        originalFile.absolute.path,
        quality: safeQuality, // ✅ GUARANTEED 60–80
        format: CompressFormat.webp,
        keepExif: false,
        minWidth: 800,
        minHeight: 800,
      );

      if (compressedBytes == null) {
        return originalFile; // fallback
      }

      final compressedFile = File(targetPath);
      await compressedFile.writeAsBytes(compressedBytes);

      return compressedFile;
    } catch (_) {
      return originalFile;
    }
  }

  /// 🔹 Camera / Gallery → WebP (Lossy 75–80)
  static Future<File?> toWebPLossy({
    required File inputFile,
    int quality = 75,
  }) async {
    // 🔒 LOCK QUALITY TO 75–80 (AS REQUIRED)
    final safeQuality = quality.clamp(75, 80);

    return compressProfileImage(originalFile: inputFile, quality: safeQuality);
  }

  /// 🔹 Batch compression (future ready)
  static Future<List<File>> compressMultipleImages(
    List<File> images, {
    int quality = 75,
  }) async {
    final List<File> result = [];

    for (final image in images) {
      final compressed = await compressProfileImage(
        originalFile: image,
        quality: quality,
      );
      if (compressed != null) {
        result.add(compressed);
      }
    }

    return result;
  }

  /// 🔹 Internal helpers

  static String _buildCompressedFileName(File file) {
    final name = path.basenameWithoutExtension(file.path);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${name}_compressed_$timestamp.webp';
  }
}
