import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

// Do not pass a web client ID into the native GoogleSignIn instance.
final GoogleSignIn _sharedGoogleSignIn = GoogleSignIn();

String _sanitizeRemoteUrl(String? value) {
  final String normalized = (value ?? '').trim();
  if (normalized.isEmpty) {
    return '';
  }
  if (normalized.toLowerCase() == 'gggggg') {
    return '';
  }
  return normalized;
}

class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  }) : _auth = firebaseAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _googleSignIn = googleSignIn ?? _sharedGoogleSignIn;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  /// Stream theo dõi trạng thái đăng nhập theo thời gian thực.
  Stream<User?> get authStateChanges {
    try {
      return _auth.authStateChanges();
    } catch (_) {
      throw Exception('Không thể theo dõi trạng thái đăng nhập lúc này.');
    }
  }

  /// Đăng ký bằng Email/Password.
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      final User? user = userCredential.user;
      if (user == null) {
        throw Exception('Không thể tạo tài khoản người dùng.');
      }

      final String normalizedDisplayName = name.trim();

      if (normalizedDisplayName.isNotEmpty) {
        await user.updateDisplayName(normalizedDisplayName);
      }

      try {
        await _usersRef.doc(user.uid).set(<String, dynamic>{
          'uid': user.uid,
          'email': email,
          'displayName': normalizedDisplayName,
          'photoUrl': '',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') {
          rethrow;
        }
        debugPrint(
          'Không có quyền ghi users/${user.uid}. Bỏ qua đồng bộ hồ sơ lúc đăng ký.',
        );
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        throw Exception('Mật khẩu quá yếu. Vui lòng đặt mật khẩu mạnh hơn.');
      }
      if (e.code == 'email-already-in-use') {
        throw Exception('Email đã tồn tại. Vui lòng dùng email khác.');
      }
      throw Exception(_mapAuthError(e));
    } on FirebaseException catch (e) {
      throw Exception(_mapFirestoreError(e));
    } catch (_) {
      throw Exception('Lỗi kết nối máy chủ. Vui lòng thử lại sau.');
    }
  }

  /// Tương thích ngược cho các nơi đang gọi API cũ.
  Future<UserCredential> signUpWithEmailPassword({
    required String email,
    required String password,
    String? displayName,
  }) {
    return signUpWithEmail(
      email: email,
      password: password,
      name: (displayName ?? '').trim(),
    );
  }

  /// Đăng nhập bằng Email/Password.
  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('Đang đăng nhập với: $email');
      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(email: email, password: password);

      try {
        await _createUserDocIfNeeded(userCredential.user);
      } catch (e) {
        // Đăng nhập Auth đã thành công, chỉ ghi log nếu đồng bộ Firestore lỗi.
        debugPrint('Không đồng bộ được hồ sơ người dùng: $e');
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapAuthError(e));
    } on FirebaseException catch (e) {
      throw Exception(_mapFirestoreError(e));
    } catch (_) {
      throw Exception('Lỗi kết nối máy chủ. Vui lòng thử lại sau.');
    }
  }

  /// Đăng nhập bằng Google Sign-In.
  Future<UserCredential> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        if (Firebase.apps.isEmpty) {
          throw Exception('Firebase chưa khởi tạo. Vui lòng chờ và thử lại.');
        }

        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.setCustomParameters(<String, String>{
          'prompt': 'consent',
        });

        final UserCredential userCredential = await _auth.signInWithPopup(
          googleProvider,
        );

        try {
          await _createUserDocIfNeeded(userCredential.user);
        } catch (e) {
          debugPrint('Không đồng bộ được hồ sơ người dùng: $e');
        }
        return userCredential;
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Bạn đã hủy đăng nhập Google.');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      try {
        await _createUserDocIfNeeded(userCredential.user);
      } catch (e) {
        debugPrint('Không đồng bộ được hồ sơ người dùng: $e');
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapAuthError(e));
    } on FirebaseException catch (e) {
      throw Exception(_mapFirestoreError(e));
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Lỗi Google Sign-In: ${e.toString()}');
    }
  }

  /// Đăng xuất khỏi tài khoản hiện tại.
  Future<void> signOut() async {
    try {
      final List<Future<void>> signOutTasks = <Future<void>>[_auth.signOut()];

      signOutTasks.add(_googleSignIn.signOut());

      await Future.wait(signOutTasks);
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapAuthError(e));
    } catch (_) {
      throw Exception('Không thể đăng xuất lúc này. Vui lòng thử lại.');
    }
  }

  /// Cập nhật tên hiển thị và đồng bộ vào document users/{uid}.
  Future<void> updateDisplayName(String displayName) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('Không tìm thấy thông tin người dùng.');
    }

    final String normalizedDisplayName = displayName.trim();
    if (normalizedDisplayName.isEmpty) {
      throw Exception('Tên hiển thị không được để trống.');
    }

    final String sanitizedPhotoUrl = _sanitizeRemoteUrl(user.photoURL);
    try {
      await _usersRef.doc(user.uid).set(<String, dynamic>{
        'uid': user.uid,
        'email': user.email ?? '',
        'displayName': normalizedDisplayName,
        'photoUrl': sanitizedPhotoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      // Name in Firebase Auth is already updated; keep UX successful
      // and let profile sync retry naturally on next sign-in/session.
      debugPrint(
        'Không thể đồng bộ displayName lên Firestore: ${e.code} - ${e.message}',
      );
    }

    try {
      await user.updateDisplayName(normalizedDisplayName);
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'Không thể cập nhật displayName trong Firebase Auth: ${e.code} - ${e.message}',
      );
    } on FirebaseException catch (e) {
      debugPrint(
        'Không thể cập nhật displayName trong Firebase Auth: ${e.code} - ${e.message}',
      );
    }

    try {
      await user.reload();
    } catch (e) {
      debugPrint('Không thể tải lại hồ sơ người dùng sau khi đổi tên: $e');
    }
  }

  /// Tạo document người dùng trong collection users nếu chưa tồn tại.
  Future<void> _createUserDocIfNeeded(User? user) async {
    if (user == null) {
      throw Exception('Không tìm thấy thông tin người dùng.');
    }

    try {
      final String sanitizedPhotoUrl = _sanitizeRemoteUrl(user.photoURL);
      await _usersRef.doc(user.uid).set(<String, dynamic>{
        'uid': user.uid,
        'email': user.email ?? '',
        'displayName': user.displayName ?? '',
        'photoUrl': sanitizedPhotoUrl,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      debugPrint('Đồng bộ hồ sơ người dùng thất bại: ${e.code} - ${e.message}');
      if (e.code == 'permission-denied') {
        return;
      }
      throw Exception(_mapFirestoreError(e));
    } catch (e) {
      debugPrint('createUserDocIfNeeded error: $e');
      throw Exception('Không thể tạo thông tin người dùng mới.');
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'operation-not-allowed':
        return 'Phương thức Email/Mật khẩu chưa được bật trong Firebase Authentication.';
      case 'email-already-in-use':
        return 'Email đã tồn tại. Vui lòng dùng email khác.';
      case 'invalid-email':
        return 'Email không hợp lệ. Vui lòng kiểm tra lại.';
      case 'weak-password':
        return 'Mật khẩu quá yếu. Vui lòng đặt mật khẩu mạnh hơn.';
      case 'user-not-found':
        return 'Không tìm thấy tài khoản. Vui lòng kiểm tra lại email.';
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Email hoặc mật khẩu không đúng.';
      case 'user-disabled':
        return 'Tài khoản đã bị vô hiệu hóa.';
      case 'too-many-requests':
        return 'Bạn thao tác quá nhanh. Vui lòng thử lại sau.';
      case 'network-request-failed':
        return 'Lỗi kết nối mạng. Vui lòng kiểm tra internet.';
      case 'account-exists-with-different-credential':
        return 'Tài khoản đã tồn tại với phương thức đăng nhập khác.';
      case 'popup-closed-by-user':
        return 'Bạn đã đóng cửa sổ đăng nhập Google.';
      default:
        return 'Đã xảy ra lỗi xác thực. Vui lòng thử lại.';
    }
  }

  String _mapFirestoreError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Bạn không có quyền truy cập dữ liệu này.';
      case 'unavailable':
        return 'Lỗi kết nối máy chủ. Vui lòng thử lại sau.';
      case 'deadline-exceeded':
        return 'Hệ thống phản hồi chậm. Vui lòng thử lại.';
      default:
        return 'Đã xảy ra lỗi dữ liệu. Vui lòng thử lại.';
    }
  }
}
