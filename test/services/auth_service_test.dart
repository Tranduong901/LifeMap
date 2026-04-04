import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifemap/services/auth_service.dart';

void main() {
  group('AuthService', () {
    test('signUpWithEmail creates profile document in Firestore', () async {
      final MockFirebaseAuth auth = MockFirebaseAuth();
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final AuthService service = AuthService(
        firebaseAuth: auth,
        firestore: firestore,
      );

      final credential = await service.signUpWithEmail(
        email: 'tester@example.com',
        password: '123456',
        name: 'Tester',
      );

      expect(credential.user, isNotNull);
      final profile = await firestore
          .collection('users')
          .doc(credential.user!.uid)
          .get();
      expect(profile.exists, isTrue);
      expect(profile.data()?['email'], 'tester@example.com');
      expect(profile.data()?['displayName'], 'Tester');
    });
  });
}
