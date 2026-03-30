import 'package:cloud_firestore/cloud_firestore.dart';

class MemoryModel {
  MemoryModel({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.lat,
    required this.lng,
    required this.date,
    required this.address,
  });

  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final double lat;
  final double lng;
  final DateTime date;
  final String address;

  factory MemoryModel.fromMap(Map<String, dynamic> data, String documentId) {
    final dynamic rawDate = data['date'];

    DateTime parsedDate;
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is DateTime) {
      parsedDate = rawDate;
    } else {
      parsedDate = DateTime.parse(rawDate.toString());
    }

    return MemoryModel(
      id: documentId,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      lat: (data['lat'] as num?)?.toDouble() ?? 0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0,
      date: parsedDate,
      address: data['address'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'lat': lat,
      'lng': lng,
      'date': Timestamp.fromDate(date),
      'address': address,
    };
  }
}
