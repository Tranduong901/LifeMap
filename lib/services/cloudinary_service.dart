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

  final CloudinaryPublic _cloudinary =
      CloudinaryPublic(cloudName, uploadPreset, cache: false);

  CloudinaryService();

  /// Compresses [file] and uploads to Cloudinary unsigned preset.
  /// Returns the secure URL string on success.
  Future<String> uploadImageFile(File file) async {
    log('CloudinaryService.uploadImageFile() start: ${file.path}');

    // compress into temp file
    final File compressed = await _compressFile(file);

    try {
      final CloudinaryResponse res = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(compressed.path, resourceType: CloudinaryResourceType.Image),
      );

      log('Cloudinary upload success: ${res.secureUrl}');
      return res.secureUrl;
    } on CloudinaryException catch (e) {
      log('CloudinaryException: ${e.message}');
      rethrow;
    }
  }

  Future<File> _compressFile(File file) async {
    try {
      final Directory tmpDir = await getTemporaryDirectory();
      final String targetPath = '${tmpDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      final File? result = await FlutterImageCompress.compressAndGetFile(
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

      log('Image compressed: original=${file.lengthSync()} compressed=${result.lengthSync()}');
      return result;
    } catch (e) {
      log('Compression failed, returning original file: $e');
      return file;
    }
  }
}
