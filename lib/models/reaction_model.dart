class ReactionModel {
  ReactionModel({
    required this.userId,
    required this.displayName,
    required this.photoUrl,
    required this.type,
    required this.createdAtMillis,
  });

  final String userId;
  final String displayName;
  final String photoUrl;
  final String type; // e.g. '❤️', '👍', '😮'
  final int createdAtMillis;

  factory ReactionModel.fromMap(Map<String, dynamic> data) {
    return ReactionModel(
      userId: (data['userId'] as String? ?? '').trim(),
      displayName: (data['displayName'] as String? ?? '').trim(),
      photoUrl: (data['photoUrl'] as String? ?? '').trim(),
      type: (data['type'] as String? ?? '').trim(),
      createdAtMillis: (data['createdAtMillis'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'userId': userId,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'type': type,
      'createdAtMillis': createdAtMillis,
    };
  }
}
