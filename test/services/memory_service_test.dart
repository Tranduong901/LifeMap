import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifemap/models/memory_model.dart';
import 'package:lifemap/services/memory_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MemoryService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('saveMemory writes data to Firestore when user signed in', () async {
      final MockUser user = MockUser(uid: 'u1', email: 'tester@example.com');
      final MockFirebaseAuth auth = MockFirebaseAuth(
        mockUser: user,
        signedIn: true,
      );
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();

      final MemoryService service = MemoryService(
        firebaseAuth: auth,
        firestore: firestore,
        enableConnectivityListener: false,
      );

      final MemoryModel model = MemoryModel(
        id: '',
        userId: '',
        title: 'Test memory',
        description: 'Desc',
        imageUrl: 'a.jpg',
        imageUrls: <String>['a.jpg'],
        topic: 'citywalk',
        lat: 21.0,
        lng: 105.0,
        date: DateTime(2026, 1, 1),
        address: 'Ha Noi',
      );

      await service.saveMemory(model);

      final snapshot = await firestore
          .collection('memories')
          .where('userId', isEqualTo: 'u1')
          .get();
      expect(snapshot.docs.length, 1);
      expect(snapshot.docs.first.data()['title'], 'Test memory');
    });

    test('saveMemory throws when no user signed in', () async {
      final MockFirebaseAuth auth = MockFirebaseAuth();
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final MemoryService service = MemoryService(
        firebaseAuth: auth,
        firestore: firestore,
        enableConnectivityListener: false,
      );

      final MemoryModel model = MemoryModel(
        id: '',
        userId: '',
        title: 'Test memory',
        description: 'Desc',
        imageUrl: 'a.jpg',
        imageUrls: <String>['a.jpg'],
        topic: 'citywalk',
        lat: 21.0,
        lng: 105.0,
        date: DateTime(2026, 1, 1),
        address: 'Ha Noi',
      );

      await expectLater(
        () => service.saveMemory(model),
        throwsA(isA<Exception>()),
      );
    });
  });
}
