import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SocialService {
  SocialService({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore})
    : _auth = firebaseAuth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');
  CollectionReference<Map<String, dynamic>> get _relationshipsRef =>
      _firestore.collection('social_relationships');

  String get _currentUid {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception('Người dùng chưa đăng nhập.');
    }
    return uid;
  }

  String _docIdFor(String followerId, String followingId) {
    return '${followerId}_$followingId';
  }

  Future<Map<String, String>> _relationshipStatusByFollowingUid(
    String currentUid,
  ) async {
    final QuerySnapshot<Map<String, dynamic>> relationSnapshot =
        await _relationshipsRef
            .where('followerId', isEqualTo: currentUid)
            .get();
    return <String, String>{
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in relationSnapshot.docs)
        (doc.data()['followingId'] as String? ?? '').trim():
            (doc.data()['status'] as String? ?? 'pending').trim(),
    };
  }

  Map<String, dynamic> _mapUserSearchResult({
    required String uid,
    required Map<String, dynamic> data,
    required Map<String, String> relationStatusByUser,
  }) {
    final String email = (data['email'] as String? ?? '').trim();
    final String displayName = (data['displayName'] as String? ?? '').trim();
    final String photoUrl = (data['photoUrl'] as String? ?? '').trim();
    return <String, dynamic>{
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'relationshipStatus': relationStatusByUser[uid] ?? 'none',
    };
  }

  Future<void> followUser(String targetUid) async {
    final String currentUid = _currentUid;
    final String normalizedTargetUid = targetUid.trim();

    if (normalizedTargetUid.isEmpty) {
      throw Exception('ID người dùng không hợp lệ.');
    }
    if (normalizedTargetUid == currentUid) {
      throw Exception('Không thể tự theo dõi chính mình.');
    }

    final String docId = _docIdFor(currentUid, normalizedTargetUid);
    await _relationshipsRef.doc(docId).set(<String, dynamic>{
      'followerId': currentUid,
      'followingId': normalizedTargetUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> acceptFollowRequest(String followerUid) async {
    final String currentUid = _currentUid;
    final String docId = _docIdFor(followerUid, currentUid);
    await _relationshipsRef.doc(docId).set(<String, dynamic>{
      'followerId': followerUid,
      'followingId': currentUid,
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> unfollowUser(String targetUid) async {
    final String currentUid = _currentUid;
    final String docId = _docIdFor(currentUid, targetUid.trim());
    await _relationshipsRef.doc(docId).delete();
  }

  Future<List<String>> getFollowingList({String status = 'accepted'}) async {
    final String currentUid = _currentUid;
    Query<Map<String, dynamic>> query = _relationshipsRef.where(
      'followerId',
      isEqualTo: currentUid,
    );
    if (status.trim().isNotEmpty) {
      query = query.where('status', isEqualTo: status);
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
    return snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
          return (doc.data()['followingId'] as String? ?? '').trim();
        })
        .where((String uid) => uid.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<List<String>> getFollowersList({String status = 'accepted'}) async {
    final String currentUid = _currentUid;
    Query<Map<String, dynamic>> query = _relationshipsRef.where(
      'followingId',
      isEqualTo: currentUid,
    );
    if (status.trim().isNotEmpty) {
      query = query.where('status', isEqualTo: status);
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
    return snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
          return (doc.data()['followerId'] as String? ?? '').trim();
        })
        .where((String uid) => uid.isNotEmpty)
        .toSet()
        .toList();
  }

  Stream<List<String>> getAcceptedFollowingIdsStream() {
    final String currentUid = _currentUid;
    return _relationshipsRef
        .where('followerId', isEqualTo: currentUid)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          final Set<String> ids = <String>{};
          for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
              in snapshot.docs) {
            final String followingId =
                (doc.data()['followingId'] as String? ?? '').trim();
            if (followingId.isNotEmpty) {
              ids.add(followingId);
            }
          }
          return ids.toList();
        });
  }

  Future<List<Map<String, dynamic>>> searchUsersByEmail(String query) async {
    final String keyword = query.trim();
    if (keyword.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final String currentUid = _currentUid;

    final QuerySnapshot<Map<String, dynamic>> userSnapshot = await _usersRef
        .where('email', isGreaterThanOrEqualTo: keyword)
        .where('email', isLessThanOrEqualTo: '$keyword\uf8ff')
        .limit(20)
        .get();

    final Map<String, String> relationStatusByUser =
        await _relationshipStatusByFollowingUid(currentUid);

    final List<Map<String, dynamic>> results = <Map<String, dynamic>>[];
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in userSnapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      final String uid = (data['uid'] as String? ?? doc.id).trim();
      if (uid.isEmpty || uid == currentUid) {
        continue;
      }

      results.add(
        _mapUserSearchResult(
          uid: uid,
          data: data,
          relationStatusByUser: relationStatusByUser,
        ),
      );
    }

    return results;
  }

  Future<List<Map<String, dynamic>>> searchUsersHybrid(String query) async {
    final String keyword = query.trim();
    if (keyword.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final String currentUid = _currentUid;
    final Map<String, String> relationStatusByUser =
        await _relationshipStatusByFollowingUid(currentUid);
    final List<Map<String, dynamic>> results = <Map<String, dynamic>>[];
    final Set<String> seen = <String>{};

    if (keyword.contains('@')) {
      final QuerySnapshot<Map<String, dynamic>> userSnapshot = await _usersRef
          .where('email', isEqualTo: keyword)
          .limit(20)
          .get();

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in userSnapshot.docs) {
        final Map<String, dynamic> data = doc.data();
        final String uid = (data['uid'] as String? ?? doc.id).trim();
        if (uid.isEmpty || uid == currentUid || !seen.add(uid)) {
          continue;
        }
        results.add(
          _mapUserSearchResult(
            uid: uid,
            data: data,
            relationStatusByUser: relationStatusByUser,
          ),
        );
      }
      return results;
    }

    // Nickname fuzzy search: lightweight client-side contains match
    // to avoid requiring additional indexed fields.
    final QuerySnapshot<Map<String, dynamic>> userSnapshot = await _usersRef
        .limit(80)
        .get();
    final String keywordLower = keyword.toLowerCase();

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in userSnapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      final String uid = (data['uid'] as String? ?? doc.id).trim();
      if (uid.isEmpty || uid == currentUid || !seen.add(uid)) {
        continue;
      }

      final String displayName = (data['displayName'] as String? ?? '').trim();
      final String nickname = (data['nickname'] as String? ?? '').trim();
      final String name = (data['name'] as String? ?? '').trim();
      final bool matched =
          displayName.toLowerCase().contains(keywordLower) ||
          nickname.toLowerCase().contains(keywordLower) ||
          name.toLowerCase().contains(keywordLower);
      if (!matched) {
        continue;
      }

      results.add(
        _mapUserSearchResult(
          uid: uid,
          data: data,
          relationStatusByUser: relationStatusByUser,
        ),
      );

      if (results.length >= 20) {
        break;
      }
    }

    return results;
  }

  Future<List<Map<String, dynamic>>> getSuggestedUsers({int limit = 12}) async {
    final String currentUid = _currentUid;
    final DocumentSnapshot<Map<String, dynamic>> meDoc = await _usersRef
        .doc(currentUid)
        .get();
    final Map<String, dynamic> me = meDoc.data() ?? <String, dynamic>{};

    final String myCity = (me['city'] as String? ?? '').trim().toLowerCase();
    final Set<String> myTopics = <String>{
      ((me['favoriteTopic'] as String?) ?? '').trim().toLowerCase(),
      ((me['topic'] as String?) ?? '').trim().toLowerCase(),
      ...((me['favoriteTopics'] is List)
          ? (me['favoriteTopics'] as List).whereType<String>().map(
              (String t) => t.trim().toLowerCase(),
            )
          : <String>[]),
    }..removeWhere((String value) => value.isEmpty);

    final Map<String, String> relationStatusByUser =
        await _relationshipStatusByFollowingUid(currentUid);
    final QuerySnapshot<Map<String, dynamic>> usersSnapshot = await _usersRef
        .limit(80)
        .get();

    final List<Map<String, dynamic>> strongMatches = <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> weakMatches = <Map<String, dynamic>>[];

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in usersSnapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      final String uid = (data['uid'] as String? ?? doc.id).trim();
      if (uid.isEmpty || uid == currentUid) {
        continue;
      }

      final String city = (data['city'] as String? ?? '').trim().toLowerCase();
      final Set<String> topics = <String>{
        ((data['favoriteTopic'] as String?) ?? '').trim().toLowerCase(),
        ((data['topic'] as String?) ?? '').trim().toLowerCase(),
        ...((data['favoriteTopics'] is List)
            ? (data['favoriteTopics'] as List).whereType<String>().map(
                (String t) => t.trim().toLowerCase(),
              )
            : <String>[]),
      }..removeWhere((String value) => value.isEmpty);

      final bool sameCity = myCity.isNotEmpty && city == myCity;
      final bool sameTopic = myTopics.intersection(topics).isNotEmpty;

      final Map<String, dynamic> mapped = _mapUserSearchResult(
        uid: uid,
        data: data,
        relationStatusByUser: relationStatusByUser,
      );
      mapped['city'] = (data['city'] as String? ?? '').trim();

      if (sameCity || sameTopic) {
        strongMatches.add(mapped);
      } else {
        weakMatches.add(mapped);
      }
    }

    final List<Map<String, dynamic>> merged = <Map<String, dynamic>>[
      ...strongMatches,
      ...weakMatches,
    ];
    return merged.take(limit).toList();
  }

  Stream<List<Map<String, dynamic>>> getFollowingProfilesStream({
    String status = 'accepted',
  }) {
    final String currentUid = _currentUid;
    Query<Map<String, dynamic>> query = _relationshipsRef.where(
      'followerId',
      isEqualTo: currentUid,
    );
    if (status.trim().isNotEmpty) {
      query = query.where('status', isEqualTo: status);
    }

    return query.snapshots().asyncMap((
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) async {
      final List<Map<String, dynamic>> profiles = <Map<String, dynamic>>[];
      for (final QueryDocumentSnapshot<Map<String, dynamic>> relationDoc
          in snapshot.docs) {
        final Map<String, dynamic> relationData = relationDoc.data();
        final String followingId =
            (relationData['followingId'] as String? ?? '').trim();
        final String relationStatus =
            (relationData['status'] as String? ?? 'pending').trim();
        if (followingId.isEmpty) {
          continue;
        }
        final DocumentSnapshot<Map<String, dynamic>> userDoc = await _usersRef
            .doc(followingId)
            .get();
        final Map<String, dynamic> userData =
            userDoc.data() ??
            <String, dynamic>{
              'uid': followingId,
              'email': '',
              'displayName': '',
              'photoUrl': '',
            };
        profiles.add(<String, dynamic>{
          'uid': followingId,
          'email': (userData['email'] as String? ?? '').trim(),
          'displayName': (userData['displayName'] as String? ?? '').trim(),
          'photoUrl': (userData['photoUrl'] as String? ?? '').trim(),
          'status': relationStatus,
        });
      }
      return profiles;
    });
  }

  Stream<List<Map<String, dynamic>>> getFollowersProfilesStream({
    String? status,
  }) {
    final String currentUid = _currentUid;
    Query<Map<String, dynamic>> query = _relationshipsRef.where(
      'followingId',
      isEqualTo: currentUid,
    );
    if (status != null && status.trim().isNotEmpty) {
      query = query.where('status', isEqualTo: status.trim());
    }

    return query.snapshots().asyncMap((
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) async {
      final List<Map<String, dynamic>> profiles = <Map<String, dynamic>>[];
      for (final QueryDocumentSnapshot<Map<String, dynamic>> relationDoc
          in snapshot.docs) {
        final Map<String, dynamic> relationData = relationDoc.data();
        final String followerId = (relationData['followerId'] as String? ?? '')
            .trim();
        final String relationStatus =
            (relationData['status'] as String? ?? 'pending').trim();
        if (followerId.isEmpty) {
          continue;
        }
        final DocumentSnapshot<Map<String, dynamic>> userDoc = await _usersRef
            .doc(followerId)
            .get();
        final Map<String, dynamic> userData =
            userDoc.data() ??
            <String, dynamic>{
              'uid': followerId,
              'email': '',
              'displayName': '',
              'photoUrl': '',
            };
        profiles.add(<String, dynamic>{
          'uid': followerId,
          'email': (userData['email'] as String? ?? '').trim(),
          'displayName': (userData['displayName'] as String? ?? '').trim(),
          'photoUrl': (userData['photoUrl'] as String? ?? '').trim(),
          'status': relationStatus,
        });
      }
      return profiles;
    });
  }
}
