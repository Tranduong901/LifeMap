import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/memory_model.dart';

class MemoryService {
  static const String _queuePrefsKey = 'lifemap_pending_memory_ops_v1';
  static bool _queueLoaded = false;
  static bool _isFlushing = false;
  static List<Map<String, dynamic>> _pendingOps = <Map<String, dynamic>>[];
  static StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  MemoryService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    bool enableConnectivityListener = true,
  }) : _auth = firebaseAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _enableConnectivityListener = enableConnectivityListener {
    _bootstrapQueue();
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final bool _enableConnectivityListener;

  static const Set<String> _invalidImageValues = <String>{
    'gggggg',
    'null',
    'undefined',
  };

  String _sanitizeImageValue(String? value) {
    final String normalized = (value ?? '').trim();
    if (normalized.isEmpty ||
        _invalidImageValues.contains(normalized.toLowerCase())) {
      return '';
    }
    return normalized;
  }

  List<String> _sanitizeImageList(List<String> values) {
    return values
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .where(
          (String item) => !_invalidImageValues.contains(item.toLowerCase()),
        )
        .toList();
  }

  CollectionReference<Map<String, dynamic>> get _memoriesRef =>
      _firestore.collection('memories');

  Future<void> _bootstrapQueue() async {
    if (!_queueLoaded) {
      await _loadQueueFromPrefs();
      _queueLoaded = true;
    }

    if (!_enableConnectivityListener) {
      return;
    }

    _connectivitySub ??= Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> result,
    ) {
      final bool connected = result.any((ConnectivityResult item) {
        return item == ConnectivityResult.mobile ||
            item == ConnectivityResult.wifi ||
            item == ConnectivityResult.ethernet ||
            item == ConnectivityResult.vpn;
      });

      if (connected) {
        unawaited(flushPendingOps());
      }
    });
  }

  Future<void> _loadQueueFromPrefs() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_queuePrefsKey);
      if (raw == null || raw.trim().isEmpty) {
        _pendingOps = <Map<String, dynamic>>[];
        return;
      }

      final dynamic decoded = jsonDecode(raw);
      if (decoded is List<dynamic>) {
        _pendingOps = decoded
            .whereType<Map<String, dynamic>>()
            .map((Map<String, dynamic> item) => Map<String, dynamic>.from(item))
            .toList();
      }
    } catch (e) {
      debugPrint('load pending queue error: $e');
      _pendingOps = <Map<String, dynamic>>[];
    }
  }

  Future<void> _saveQueueToPrefs() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_queuePrefsKey, jsonEncode(_pendingOps));
    } catch (e) {
      debugPrint('save pending queue error: $e');
    }
  }

  bool _isNetworkError(FirebaseException e) {
    return e.code == 'unavailable' ||
        e.code == 'network-request-failed' ||
        e.code == 'deadline-exceeded';
  }

  Future<void> _enqueueMemoryOperation({
    required String type,
    required String userId,
    String? docId,
    MemoryModel? memory,
  }) async {
    final Map<String, dynamic> op = <String, dynamic>{
      'type': type,
      'userId': userId,
      'docId': docId ?? memory?.id ?? '',
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      if (memory != null) 'memory': memory.toQueueMap(),
    };

    _pendingOps.add(op);
    await _saveQueueToPrefs();
  }

  Map<String, dynamic> _buildCreateData(MemoryModel memory) {
    final List<String> sanitizedImageUrls = _sanitizeImageList(
      memory.imageUrls,
    );
    final String sanitizedPrimaryImage = _sanitizeImageValue(memory.imageUrl);
    return <String, dynamic>{
      'title': memory.title,
      'userId': memory.userId,
      'description': memory.description,
      'imageUrl': sanitizedImageUrls.isNotEmpty
          ? sanitizedImageUrls.first
          : sanitizedPrimaryImage,
      'imageUrls': sanitizedImageUrls,
      'topic': memory.topic,
      'lat': memory.lat,
      'lng': memory.lng,
      'location': GeoPoint(memory.lat, memory.lng),
      'date': Timestamp.fromDate(memory.date),
      'address': memory.address,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> _buildUpdateData(MemoryModel memory) {
    final List<String> sanitizedImageUrls = _sanitizeImageList(
      memory.imageUrls,
    );
    final String sanitizedPrimaryImage = _sanitizeImageValue(memory.imageUrl);
    return <String, dynamic>{
      'title': memory.title,
      'userId': memory.userId,
      'description': memory.description,
      'imageUrl': sanitizedImageUrls.isNotEmpty
          ? sanitizedImageUrls.first
          : sanitizedPrimaryImage,
      'imageUrls': sanitizedImageUrls,
      'topic': memory.topic,
      'lat': memory.lat,
      'lng': memory.lng,
      'location': GeoPoint(memory.lat, memory.lng),
      'date': Timestamp.fromDate(memory.date),
      'address': memory.address,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  List<MemoryModel> _applyPendingPreview(
    List<MemoryModel> items,
    String userId,
  ) {
    final List<MemoryModel> result = List<MemoryModel>.from(items);
    for (final Map<String, dynamic> op in _pendingOps) {
      if ((op['userId'] as String? ?? '') != userId) {
        continue;
      }

      final String type = op['type'] as String? ?? '';
      final String docId = op['docId'] as String? ?? '';

      if (type == 'delete') {
        result.removeWhere((MemoryModel memory) => memory.id == docId);
        continue;
      }

      final Map<String, dynamic>? rawMemory =
          op['memory'] as Map<String, dynamic>?;
      if (rawMemory == null) {
        continue;
      }
      final MemoryModel pending = MemoryModel.fromQueueMap(rawMemory);

      final int existingIndex = result.indexWhere(
        (MemoryModel memory) => memory.id == pending.id,
      );
      if (existingIndex >= 0) {
        result[existingIndex] = pending;
      } else {
        result.add(pending);
      }
    }

    result.sort((MemoryModel a, MemoryModel b) => b.date.compareTo(a.date));
    return result;
  }

  Future<void> flushPendingOps() async {
    if (_isFlushing || _pendingOps.isEmpty) {
      return;
    }
    _isFlushing = true;

    try {
      final List<Map<String, dynamic>> queue = List<Map<String, dynamic>>.from(
        _pendingOps,
      );
      final List<Map<String, dynamic>> remaining = <Map<String, dynamic>>[];

      for (final Map<String, dynamic> op in queue) {
        final String type = op['type'] as String? ?? '';
        final String docId = op['docId'] as String? ?? '';
        final Map<String, dynamic>? rawMemory =
            op['memory'] as Map<String, dynamic>?;

        try {
          if (type == 'delete') {
            await _memoriesRef.doc(docId).delete();
          } else if (rawMemory != null) {
            final MemoryModel memory = MemoryModel.fromQueueMap(rawMemory);
            if (type == 'create') {
              await _memoriesRef
                  .doc(memory.id)
                  .set(_buildCreateData(memory), SetOptions(merge: true));
            } else if (type == 'update') {
              await _memoriesRef
                  .doc(memory.id)
                  .update(_buildUpdateData(memory));
            }
          }
        } on FirebaseException catch (e) {
          if (_isNetworkError(e)) {
            remaining.add(op);
          } else {
            debugPrint('drop invalid queued op ($type/$docId): ${e.code}');
          }
        }
      }

      _pendingOps = remaining;
      await _saveQueueToPrefs();
    } finally {
      _isFlushing = false;
    }
  }

  Stream<List<MemoryModel>> getMemoriesStream() {
    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        return Stream<List<MemoryModel>>.value(<MemoryModel>[]);
      }

      unawaited(flushPendingOps());

      return _memoriesRef.where('userId', isEqualTo: user.uid).snapshots().map((
        QuerySnapshot<Map<String, dynamic>> snapshot,
      ) {
        final List<MemoryModel> serverItems = snapshot.docs
            .map(
              (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                  MemoryModel.fromMap(doc.data(), doc.id),
            )
            .toList();
        return _applyPendingPreview(serverItems, user.uid);
      });
    } on FirebaseException catch (e) {
      debugPrint('Firestore getMemoriesStream error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('getMemoriesStream error: $e');
      rethrow;
    }
  }

  Stream<List<MemoryModel>> getMemoriesForUserIdsStream(List<String> userIds) {
    final List<String> normalized = userIds
        .map((String id) => id.trim())
        .where((String id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (normalized.isEmpty) {
      return Stream<List<MemoryModel>>.value(<MemoryModel>[]);
    }

    final List<List<String>> chunks = <List<String>>[];
    for (int i = 0; i < normalized.length; i += 10) {
      final int end = (i + 10) > normalized.length ? normalized.length : i + 10;
      chunks.add(normalized.sublist(i, end));
    }

    final List<Stream<List<MemoryModel>>> streams = chunks.map((
      List<String> chunk,
    ) {
      return _memoriesRef.where('userId', whereIn: chunk).snapshots().map((
        QuerySnapshot<Map<String, dynamic>> snapshot,
      ) {
        return snapshot.docs
            .map(
              (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                  MemoryModel.fromMap(doc.data(), doc.id),
            )
            .toList();
      });
    }).toList();

    if (streams.length == 1) {
      return streams.first.map(_sortMemoriesByDateDesc);
    }

    return Stream<List<MemoryModel>>.multi((
      MultiStreamController<List<MemoryModel>> controller,
    ) {
      final List<List<MemoryModel>?> latest = List<List<MemoryModel>?>.filled(
        streams.length,
        null,
      );
      final List<StreamSubscription<List<MemoryModel>>> subscriptions =
          <StreamSubscription<List<MemoryModel>>>[];

      void emitIfReady() {
        if (latest.any((List<MemoryModel>? item) => item == null)) {
          return;
        }
        final List<MemoryModel> merged = latest
            .expand((List<MemoryModel>? item) => item ?? <MemoryModel>[])
            .toList();
        controller.add(_sortMemoriesByDateDesc(merged));
      }

      for (int i = 0; i < streams.length; i++) {
        final int index = i;
        subscriptions.add(
          streams[index].listen((List<MemoryModel> value) {
            latest[index] = value;
            emitIfReady();
          }, onError: controller.addError),
        );
      }

      controller.onCancel = () async {
        for (final StreamSubscription<List<MemoryModel>> sub in subscriptions) {
          await sub.cancel();
        }
      };
    });
  }

  List<MemoryModel> _sortMemoriesByDateDesc(List<MemoryModel> items) {
    final List<MemoryModel> sorted = List<MemoryModel>.from(items);
    sorted.sort((MemoryModel a, MemoryModel b) => b.date.compareTo(a.date));
    return sorted;
  }

  /// Retrieve memories once (non-real-time) to avoid platform-channel
  /// threading issues on some desktop platforms.
  Future<List<MemoryModel>> getMemoriesOnce() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        return <MemoryModel>[];
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot = await _memoriesRef
          .where('userId', isEqualTo: user.uid)
          .get();

      final List<MemoryModel> serverItems = snapshot.docs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                MemoryModel.fromMap(doc.data(), doc.id),
          )
          .toList();

      return _applyPendingPreview(serverItems, user.uid);
    } catch (e) {
      debugPrint('getMemoriesOnce error: $e');
      rethrow;
    }
  }

  Future<void> saveMemory(MemoryModel memory) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('Người dùng chưa đăng nhập.');
    }

    try {
      final String docId = memory.id.isEmpty
          ? _memoriesRef.doc().id
          : memory.id.trim();
      final MemoryModel resolved = memory.copyWith(id: docId, userId: user.uid);

      await _memoriesRef
          .doc(docId)
          .set(_buildCreateData(resolved), SetOptions(merge: true));
    } on FirebaseException catch (e) {
      debugPrint('Firestore saveMemory error: ${e.code} - ${e.message}');
      if (_isNetworkError(e)) {
        final String docId = memory.id.isEmpty
            ? _memoriesRef.doc().id
            : memory.id.trim();
        final MemoryModel resolved = memory.copyWith(
          id: docId,
          userId: user.uid,
        );
        await _enqueueMemoryOperation(
          type: 'create',
          userId: user.uid,
          memory: resolved,
        );
        return;
      }
      throw Exception(_mapFirestoreError(e));
    } catch (e) {
      debugPrint('saveMemory error: $e');
      throw Exception('Không thể lưu kỷ niệm. Vui lòng thử lại.');
    }
  }

  Future<void> updateMemory(MemoryModel memory) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('Người dùng chưa đăng nhập.');
    }

    try {
      final MemoryModel resolved = memory.copyWith(userId: user.uid);
      await _memoriesRef.doc(memory.id).update(_buildUpdateData(resolved));
    } on FirebaseException catch (e) {
      debugPrint('Firestore updateMemory error: ${e.code} - ${e.message}');
      if (_isNetworkError(e)) {
        await _enqueueMemoryOperation(
          type: 'update',
          userId: user.uid,
          memory: memory.copyWith(userId: user.uid),
        );
        return;
      }
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
      if (_isNetworkError(e)) {
        await _enqueueMemoryOperation(
          type: 'delete',
          userId: user.uid,
          docId: docId,
        );
        return;
      }
      throw Exception(_mapFirestoreError(e));
    } catch (e) {
      debugPrint('deleteMemory error: $e');
      throw Exception('Không thể xóa kỷ niệm. Vui lòng thử lại.');
    }
  }

  Future<void> addMemory(MemoryModel memory) {
    return saveMemory(memory);
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
