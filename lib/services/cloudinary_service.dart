import 'dart:async';
import 'dart:io';
import 'dart:developer';

import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Simple Cloudinary upload service used by Người 4.
///
/// NOTE: Replace [cloudName] and [uploadPreset] with your Cloudinary values.
class CloudinaryService {
  // TODO: move these to secure config / environment variables
  static const String cloudName = 'dz71nvyby';
  static const String uploadPreset = 'lifemap';

  final CloudinaryPublic _cloudinary = CloudinaryPublic(
    cloudName,
    uploadPreset,
    cache: false,
  );

  CloudinaryService();

  /// Compresses [file] and uploads to Cloudinary unsigned preset.
  /// Returns the secure URL string on success.
  Future<String> uploadImageFile(File file) async {
    log('CloudinaryService.uploadImageFile() start: ${file.path}');

    // compress into temp file
    final File compressed = await _compressFile(file);

    const int maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final CloudinaryResponse res = await _cloudinary
            .uploadFile(
              CloudinaryFile.fromFile(
                compressed.path,
                resourceType: CloudinaryResourceType.Image,
              ),
            )
            .timeout(const Duration(seconds: 35));

        log('Cloudinary upload success: ${res.secureUrl}');
        return res.secureUrl;
      } on CloudinaryException catch (e) {
        final bool shouldRetry = attempt < maxRetries;
        log('CloudinaryException (attempt $attempt/$maxRetries): ${e.message}');
        if (!shouldRetry) {
          rethrow;
        }
      } on TimeoutException {
        final bool shouldRetry = attempt < maxRetries;
        log('Cloudinary timeout (attempt $attempt/$maxRetries)');
        if (!shouldRetry) {
          rethrow;
        }
      }

      await Future<void>.delayed(Duration(seconds: attempt));
    }

    throw Exception('Upload Cloudinary thất bại sau nhiều lần thử.');
  }

  Future<File> _compressFile(File file) async {
    try {
      final Directory tmpDir = await getTemporaryDirectory();
      final String targetPath =
          '${tmpDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 80,
        minWidth: 1024,
        keepExif: true,
      );

      if (result == null) {
        // fallback to original file
        return file;
      }

      final File compressedFile = File(result.path);
      log(
        'Image compressed: original=${file.lengthSync()} compressed=${compressedFile.lengthSync()}',
      );
      return compressedFile;
    } catch (e) {
      log('Compression failed, returning original file: $e');
      return file;
    }
  }
}
