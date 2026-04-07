import 'package:cloud_firestore/cloud_firestore.dart';

class ReactionService {
  ReactionService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> setReaction(
    String memoryId,
    Map<String, dynamic> reactionMap,
  ) async {
    if (memoryId.trim().isEmpty) return;
    final DocumentReference<Map<String, dynamic>> docRef = _firestore
        .collection('memories')
        .doc(memoryId);
    await _firestore.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await tx.get(
        docRef,
      );
      final List<dynamic> existing =
          (snapshot.data()?['reactions'] as List<dynamic>?) ?? <dynamic>[];
      final String userId = (reactionMap['userId'] as String? ?? '').trim();
      final List<dynamic> filtered = existing.where((dynamic item) {
        if (item is Map<String, dynamic>) {
          final String uid = (item['userId'] as String? ?? '').trim();
          return uid != userId;
        }
        return true;
      }).toList();
      filtered.add(reactionMap);
      tx.update(docRef, <String, dynamic>{
        'reactions': filtered,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> removeReaction(
    String memoryId,
    Map<String, dynamic> reactionMap,
  ) async {
    if (memoryId.trim().isEmpty) return;
    await _firestore.collection('memories').doc(memoryId).update(
      <String, dynamic>{
        'reactions': FieldValue.arrayRemove(<dynamic>[reactionMap]),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }
}
