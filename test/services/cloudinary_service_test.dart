import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifemap/services/cloudinary_service.dart';

void main() {
  group('CloudinaryService', () {
    test('retries and succeeds on later attempt', () async {
      int callCount = 0;
      final File fake = File(
        '${Directory.systemTemp.path}/lifemap-cloudinary-test.jpg',
      )..writeAsStringSync('fake-image-bytes');

      final CloudinaryService service = CloudinaryService(
        compressFn: (File file) async => file,
        uploadFn: (File file) async {
          callCount++;
          if (callCount < 3) {
            throw TimeoutException('simulated timeout');
          }
          return 'https://res.cloudinary.com/demo/image/upload/sample.jpg';
        },
        maxRetries: 3,
        uploadTimeout: const Duration(milliseconds: 200),
        retryDelayBuilder: (_) => Duration.zero,
      );

      final String url = await service.uploadImageFile(fake);

      expect(url, contains('cloudinary.com'));
      expect(callCount, 3);
    });

    test('throws after max retries', () async {
      int callCount = 0;
      final File fake = File(
        '${Directory.systemTemp.path}/lifemap-cloudinary-test-2.jpg',
      )..writeAsStringSync('fake-image-bytes');

      final CloudinaryService service = CloudinaryService(
        compressFn: (File file) async => file,
        uploadFn: (File file) async {
          callCount++;
          throw TimeoutException('always timeout');
        },
        maxRetries: 2,
        uploadTimeout: const Duration(milliseconds: 100),
        retryDelayBuilder: (_) => Duration.zero,
      );

      await expectLater(
        () => service.uploadImageFile(fake),
        throwsA(isA<TimeoutException>()),
      );
      expect(callCount, 2);
    });
  });
}
