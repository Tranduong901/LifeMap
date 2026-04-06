import 'dart:async';
import 'dart:io';
import 'dart:developer';

import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Simple Cloudinary upload service used by Người 4.
///
/// NOTE: Replace [cloudName] and [uploadPreset] with your Cloudinary values.
class CloudinaryService {
  // Cloudinary config: prefer compile-time defines (`--dart-define`),
  // otherwise read runtime environment variables (desktop),
  // fallback to the existing defaults for development.
  static String get _cloudName {
    const String fromDefine = String.fromEnvironment(
      'CLOUDINARY_CLOUD_NAME',
      defaultValue: '',
    );
    if (fromDefine.isNotEmpty) return fromDefine;
    // Platform.environment is unsupported on web; avoid calling it there.
    if (kIsWeb) return 'dz71nvyby';
    return Platform.environment['CLOUDINARY_CLOUD_NAME'] ?? 'dz71nvyby';
  }

  static String get _uploadPreset {
    const String fromDefine = String.fromEnvironment(
      'CLOUDINARY_UPLOAD_PRESET',
      defaultValue: '',
    );
    if (fromDefine.isNotEmpty) return fromDefine;
    // Platform.environment is unsupported on web; avoid calling it there.
    if (kIsWeb) return 'lifemap';
    return Platform.environment['CLOUDINARY_UPLOAD_PRESET'] ?? 'lifemap';
  }

  final CloudinaryPublic _cloudinary = CloudinaryPublic(
    _cloudName,
    _uploadPreset,
    cache: false,
  );

  CloudinaryService({
    Future<String> Function(File file)? uploadFn,
    Future<File> Function(File file)? compressFn,
    int maxRetries = 3,
    Duration uploadTimeout = const Duration(seconds: 35),
    Duration Function(int attempt)? retryDelayBuilder,
  }) : _uploadFn = uploadFn,
       _compressFn = compressFn,
       _maxRetries = maxRetries,
       _uploadTimeout = uploadTimeout,
       _retryDelayBuilder = retryDelayBuilder;

  final Future<String> Function(File file)? _uploadFn;
  final Future<File> Function(File file)? _compressFn;
  final int _maxRetries;
  final Duration _uploadTimeout;
  final Duration Function(int attempt)? _retryDelayBuilder;

  /// Compresses [file] and uploads to Cloudinary unsigned preset.
  /// Returns the secure URL string on success.
  Future<String> uploadImageFile(File file) async {
    log('CloudinaryService.uploadImageFile() start: ${file.path}');

    // compress into temp file
    final File compressed =
        await (_compressFn?.call(file) ?? _compressFile(file));

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final String secureUrl;
        if (_uploadFn != null) {
          secureUrl = await _uploadFn(compressed).timeout(_uploadTimeout);
        } else {
          final CloudinaryResponse res = await _cloudinary
              .uploadFile(
                CloudinaryFile.fromFile(
                  compressed.path,
                  resourceType: CloudinaryResourceType.Image,
                ),
              )
              .timeout(_uploadTimeout);
          secureUrl = res.secureUrl;
        }

        log('Cloudinary upload success: $secureUrl');
        return secureUrl;
      } on CloudinaryException catch (e) {
        final bool shouldRetry = attempt < _maxRetries;
        log(
          'CloudinaryException (attempt $attempt/$_maxRetries): ${e.message}',
        );
        if (!shouldRetry) {
          rethrow;
        }
      } on TimeoutException {
        final bool shouldRetry = attempt < _maxRetries;
        log('Cloudinary timeout (attempt $attempt/$_maxRetries)');
        if (!shouldRetry) {
          rethrow;
        }
      }

      final Duration retryDelay =
          _retryDelayBuilder?.call(attempt) ?? Duration(seconds: attempt);
      await Future<void>.delayed(retryDelay);
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
