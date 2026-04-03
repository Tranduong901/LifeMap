import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

const FirebaseOptions _webFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyBygRDAY1m9goXqkbyW1QUsHxnk7EC8VUM',
  appId: '1:841983025732:web:df3a4ae37b284cb4db1211',
  messagingSenderId: '841983025732',
  projectId: 'lifemap-82da6',
  authDomain: 'lifemap-82da6.firebaseapp.com',
  storageBucket: 'lifemap-82da6.firebasestorage.app',
  measurementId: 'G-GE39814X17',
);

class FirebaseService {
  const FirebaseService();

  /// Khoi tao Firebase truoc khi app chay.
  Future<void> initialize() async {
    try {
      if (kIsWeb) {
        await Firebase.initializeApp(options: _webFirebaseOptions);
      } else {
        await Firebase.initializeApp();
      }
    } on FirebaseException catch (_) {
      throw Exception(
        'Khong the khoi tao Firebase. Vui long kiem tra cau hinh.',
      );
    } catch (_) {
      throw Exception('Loi ket noi dich vu Firebase. Vui long thu lai.');
    }
  }
}
