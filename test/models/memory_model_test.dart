import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifemap/models/memory_model.dart';

void main() {
  group('MemoryModel', () {
    test('fromMap prefers imageUrls and keeps first as imageUrl', () {
      final MemoryModel model = MemoryModel.fromMap(<String, dynamic>{
        'userId': 'u1',
        'title': 'T1',
        'description': 'D1',
        'imageUrls': <String>['a.jpg', 'b.jpg'],
        'topic': 'food',
        'lat': 21.0,
        'lng': 105.0,
        'date': Timestamp.fromDate(DateTime(2026, 1, 1)),
        'address': 'HN',
      }, 'doc1');

      expect(model.imageUrl, 'a.jpg');
      expect(model.imageUrls.length, 2);
      expect(model.topic, 'food');
    });

    test('fromMap falls back to imageUrl when imageUrls is empty', () {
      final MemoryModel model = MemoryModel.fromMap(<String, dynamic>{
        'userId': 'u1',
        'title': 'T2',
        'description': 'D2',
        'imageUrl': 'single.jpg',
        'topic': 'citywalk',
        'lat': 21.0,
        'lng': 105.0,
        'date': Timestamp.fromDate(DateTime(2026, 1, 2)),
        'address': 'HN',
      }, 'doc2');

      expect(model.imageUrl, 'single.jpg');
      expect(model.imageUrls, <String>['single.jpg']);
    });

    test('queue map roundtrip keeps key fields', () {
      final MemoryModel source = MemoryModel(
        id: 'm1',
        userId: 'u1',
        title: 'Trip',
        description: 'Desc',
        imageUrl: 'x.jpg',
        imageUrls: <String>['x.jpg', 'y.jpg'],
        topic: 'trekking',
        lat: 10.1,
        lng: 20.2,
        date: DateTime(2026, 1, 3),
        address: 'Da Nang',
      );

      final MemoryModel restored = MemoryModel.fromQueueMap(
        source.toQueueMap(),
      );

      expect(restored.id, source.id);
      expect(restored.userId, source.userId);
      expect(restored.imageUrls, source.imageUrls);
      expect(restored.topic, source.topic);
      expect(restored.lat, source.lat);
      expect(restored.lng, source.lng);
    });
  });
}
