import 'package:cloud_firestore/cloud_firestore.dart';

class MemoryModel {
  MemoryModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.imageUrls,
    required this.topic,
    required this.lat,
    required this.lng,
    required this.date,
    required this.address,
  });

  final String id;
  final String userId;
  final String title;
  final String description;
  final String imageUrl;
  final List<String> imageUrls;
  final String topic;
  final double lat;
  final double lng;
  final DateTime date;
  final String address;

  static const Set<String> _invalidImageValues = <String>{
    'gggggg',
    'null',
    'undefined',
  };

  static String _sanitizeRemoteValue(Object? value) {
    final String normalized = (value as String? ?? '').trim();
    if (normalized.isEmpty) {
      return '';
    }
    if (_invalidImageValues.contains(normalized.toLowerCase())) {
      return '';
    }
    return normalized;
  }

  static List<String> _sanitizeRemoteList(List<dynamic>? values) {
    return (values ?? <dynamic>[])
        .whereType<String>()
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .where(
          (String item) => !_invalidImageValues.contains(item.toLowerCase()),
        )
        .toList();
  }

  factory MemoryModel.fromMap(Map<String, dynamic> data, String documentId) {
    final dynamic rawDate = data['date'];
    final GeoPoint? location = data['location'] as GeoPoint?;

    DateTime parsedDate;
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is DateTime) {
      parsedDate = rawDate;
    } else if (rawDate == null && data['createdAt'] is Timestamp) {
      parsedDate = (data['createdAt'] as Timestamp).toDate();
    } else if (rawDate == null) {
      parsedDate = DateTime.now();
    } else {
      parsedDate = DateTime.parse(rawDate.toString());
    }

    final List<String> parsedImageUrls = _sanitizeRemoteList(
      data['imageUrls'] as List<dynamic>?,
    );

    final String fallbackImageUrl = _sanitizeRemoteValue(data['imageUrl']);
    if (parsedImageUrls.isEmpty && fallbackImageUrl.trim().isNotEmpty) {
      parsedImageUrls.add(fallbackImageUrl);
    }

    final String normalizedTopic = (data['topic'] as String? ?? 'citywalk')
        .trim()
        .toLowerCase();

    return MemoryModel(
      id: documentId,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      imageUrl: parsedImageUrls.isNotEmpty ? parsedImageUrls.first : '',
      imageUrls: parsedImageUrls,
      topic: normalizedTopic,
      lat:
          location?.latitude ??
          (data['lat'] as num?)?.toDouble() ??
          (data['latitude'] as num?)?.toDouble() ??
          0,
      lng:
          location?.longitude ??
          (data['lng'] as num?)?.toDouble() ??
          (data['longitude'] as num?)?.toDouble() ??
          0,
      date: parsedDate,
      address: data['address'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    final List<String> sanitizedImageUrls = _sanitizeRemoteList(
      imageUrls.cast<dynamic>(),
    );
    final String sanitizedImageUrl = _sanitizeRemoteValue(imageUrl);
    return <String, dynamic>{
      'title': title,
      'userId': userId,
      'description': description,
      'imageUrl': sanitizedImageUrls.isNotEmpty
          ? sanitizedImageUrls.first
          : sanitizedImageUrl,
      'imageUrls': sanitizedImageUrls,
      'topic': topic,
      'lat': lat,
      'lng': lng,
      'location': GeoPoint(lat, lng),
      'date': Timestamp.fromDate(date),
      'address': address,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  MemoryModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    String? imageUrl,
    List<String>? imageUrls,
    String? topic,
    double? lat,
    double? lng,
    DateTime? date,
    String? address,
  }) {
    return MemoryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      topic: topic ?? this.topic,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      date: date ?? this.date,
      address: address ?? this.address,
    );
  }

  Map<String, dynamic> toQueueMap() {
    return <String, dynamic>{
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'topic': topic,
      'lat': lat,
      'lng': lng,
      'dateMillis': date.millisecondsSinceEpoch,
      'address': address,
    };
  }

  factory MemoryModel.fromQueueMap(Map<String, dynamic> data) {
    final List<String> urls = _sanitizeRemoteList(
      data['imageUrls'] as List<dynamic>?,
    );
    final String primary = _sanitizeRemoteValue(data['imageUrl']);
    if (urls.isEmpty && primary.isNotEmpty) {
      urls.add(primary);
    }

    final int millis =
        (data['dateMillis'] as num?)?.toInt() ??
        DateTime.now().millisecondsSinceEpoch;

    return MemoryModel(
      id: data['id'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      imageUrl: urls.isNotEmpty ? urls.first : '',
      imageUrls: urls,
      topic: (data['topic'] as String? ?? 'citywalk').toLowerCase(),
      lat: (data['lat'] as num?)?.toDouble() ?? 0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0,
      date: DateTime.fromMillisecondsSinceEpoch(millis),
      address: data['address'] as String? ?? '',
    );
  }
}
