import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifemap/models/memory_topic.dart';

void main() {
  group('MemoryTopic', () {
    test('label returns Vietnamese label for known topics', () {
      expect(MemoryTopic.label(MemoryTopic.food), 'Food tour');
      expect(MemoryTopic.label(MemoryTopic.citywalk), 'City walk');
      expect(MemoryTopic.label(MemoryTopic.custom), 'Chủ đề riêng');
    });

    test('label capitalizes unknown custom value', () {
      expect(MemoryTopic.label('photography'), 'Photography');
    });

    test('color returns deterministic color for unknown topics', () {
      final Color c1 = MemoryTopic.color('photography');
      final Color c2 = MemoryTopic.color('photography');
      expect(c1.toARGB32(), c2.toARGB32());
    });
  });
}
