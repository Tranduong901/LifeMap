import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class MemoryService {
  MemoryService({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore})
    : _auth = firebaseAuth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _memoriesRef =>
      _firestore.collection('memories');

  Stream<QuerySnapshot<Map<String, dynamic>>> getMemoriesStream() {
    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        return Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
      }

      return _memoriesRef
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots();
    } on FirebaseException catch (e) {
      debugPrint('Firestore getMemoriesStream error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('getMemoriesStream error: $e');
      rethrow;
    }
  }

  Future<void> saveMemory({
    required String description,
    required String imageUrl,
    required double lat,
    required double lng,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('Người dùng chưa đăng nhập.');
    }

    try {
      await _memoriesRef.add(<String, dynamic>{
        'userId': user.uid,
        'description': description.trim(),
        'imageUrl': imageUrl.trim(),
        'location': GeoPoint(lat, lng),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      debugPrint('Firestore saveMemory error: ${e.code} - ${e.message}');
      throw Exception(_mapFirestoreError(e));
    } catch (e) {
      debugPrint('saveMemory error: $e');
      throw Exception('Không thể lưu kỷ niệm. Vui lòng thử lại.');
    }
  }

  Future<void> updateMemory({
    required String docId,
    required String description,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('Người dùng chưa đăng nhập.');
    }

    try {
      await _memoriesRef.doc(docId).update(<String, dynamic>{
        'description': description.trim(),
      });
    } on FirebaseException catch (e) {
      debugPrint('Firestore updateMemory error: ${e.code} - ${e.message}');
      throw Exception(_mapFirestoreError(e));
    } catch (e) {
      debugPrint('updateMemory error: $e');
      throw Exception('Không thể cập nhật kỷ niệm. Vui lòng thử lại.');
    }
  }

  Future<void> deleteMemory({required String docId}) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('Người dùng chưa đăng nhập.');
    }

    try {
      await _memoriesRef.doc(docId).delete();
    } on FirebaseException catch (e) {
      debugPrint('Firestore deleteMemory error: ${e.code} - ${e.message}');
      throw Exception(_mapFirestoreError(e));
    } catch (e) {
      debugPrint('deleteMemory error: $e');
      throw Exception('Không thể xóa kỷ niệm. Vui lòng thử lại.');
    }
  }

  Future<void> addMemory({
    required String description,
    required String imageUrl,
    required double lat,
    required double lng,
  }) {
    return saveMemory(
      description: description,
      imageUrl: imageUrl,
      lat: lat,
      lng: lng,
    );
  }

  String _mapFirestoreError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Bạn không có quyền thực hiện thao tác này.';
      case 'unavailable':
        return 'Lỗi kết nối máy chủ. Vui lòng thử lại sau.';
      case 'not-found':
        return 'Không tìm thấy kỷ niệm cần xử lý.';
      case 'deadline-exceeded':
        return 'Hệ thống phản hồi chậm. Vui lòng thử lại sau.';
      default:
        return 'Đã xảy ra lỗi dữ liệu. Vui lòng thử lại.';
    }
  }
}
