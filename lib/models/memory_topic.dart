import 'package:flutter/material.dart';

class MemoryTopic {
  static const String custom = '__custom__';
  static const String citywalk = 'citywalk';
  static const String food = 'food';
  static const String trekking = 'trekking';
  static const String beach = 'beach';
  static const String culture = 'culture';

  static const List<String> values = <String>[
    citywalk,
    food,
    trekking,
    beach,
    culture,
    custom,
  ];

  static const List<String> presets = <String>[
    citywalk,
    food,
    trekking,
    beach,
    culture,
  ];

  static String label(String topic) {
    switch (topic) {
      case custom:
        return 'Chủ đề riêng';
      case food:
        return 'Food tour';
      case trekking:
        return 'Trekking';
      case beach:
        return 'Biển';
      case culture:
        return 'Văn hóa';
      case citywalk:
        return 'City walk';
      default:
        if (topic.trim().isEmpty) {
          return 'City walk';
        }
        return topic[0].toUpperCase() + topic.substring(1);
    }
  }

  static Color color(String topic) {
    switch (topic) {
      case food:
        return const Color(0xFFE67E22);
      case trekking:
        return const Color(0xFF16A085);
      case beach:
        return const Color(0xFF3498DB);
      case culture:
        return const Color(0xFF8E44AD);
      case citywalk:
        return const Color(0xFF2D6CDF);
      case custom:
        return const Color(0xFF6B7280);
      default:
        final int hash = topic.hashCode.abs();
        final List<Color> palette = <Color>[
          const Color(0xFF4F46E5),
          const Color(0xFF0EA5E9),
          const Color(0xFF10B981),
          const Color(0xFFF97316),
          const Color(0xFFEC4899),
        ];
        return palette[hash % palette.length];
    }
  }
}
