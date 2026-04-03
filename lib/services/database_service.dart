import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/memory_model.dart';

class DatabaseService {
  DatabaseService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _memoriesRef =>
      _firestore.collection('memories');

  /// Thêm một kỷ niệm mới vào Firestore.
  Future<void> addMemory(MemoryModel memory) async {
    try {
      await _memoriesRef.doc(memory.id).set(memory.toMap());
    } on FirebaseException catch (e) {
      throw Exception(_mapFirestoreError(e));
    } catch (_) {
      throw Exception('Lỗi kết nối máy chủ. Vui lòng thử lại sau.');
    }
  }

  /// Lấy danh sách kỷ niệm theo thời gian giảm dần (mới nhất lên đầu).
  Stream<List<MemoryModel>> getMemoriesStream() {
    try {
      return _memoriesRef
          .orderBy('date', descending: true)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
                .map(
                  (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                      MemoryModel.fromMap(doc.data(), doc.id),
                )
                .toList(),
          );
    } on FirebaseException catch (e) {
      throw Exception(_mapFirestoreError(e));
    } catch (_) {
      throw Exception('Không thể tải dữ liệu kỷ niệm lúc này.');
    }
  }

  /// Xóa kỷ niệm theo id.
  Future<void> deleteMemory(String id) async {
    try {
      await _memoriesRef.doc(id).delete();
    } on FirebaseException catch (e) {
      throw Exception(_mapFirestoreError(e));
    } catch (_) {
      throw Exception('Không thể xóa kỷ niệm. Vui lòng thử lại.');
    }
  }

  /// Cập nhật thông tin kỷ niệm.
  Future<void> updateMemory(MemoryModel memory) async {
    try {
      await _memoriesRef.doc(memory.id).update(memory.toMap());
    } on FirebaseException catch (e) {
      throw Exception(_mapFirestoreError(e));
    } catch (_) {
      throw Exception('Không thể cập nhật kỷ niệm. Vui lòng thử lại.');
    }
  }

  String _mapFirestoreError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Bạn không có quyền thực hiện thao tác này.';
      case 'unavailable':
        return 'Lỗi kết nối máy chủ. Vui lòng thử lại sau.';
      case 'not-found':
        return 'Không tìm thấy dữ liệu cần xử lý.';
      case 'deadline-exceeded':
        return 'Hệ thống phản hồi chậm. Vui lòng thử lại sau.';
      default:
        return 'Đã xảy ra lỗi dữ liệu. Vui lòng thử lại.';
    }
  }
}
