import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:graceway/data/repositories/firestore_iap_repository.dart';

// ── Mocks (only non-sealed classes) ──────────────────────────────────────────

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockHttpsCallableResult extends Mock
    implements HttpsCallableResult<Map<String, dynamic>> {}

// ── Helpers ───────────────────────────────────────────────────────────────────

const _uid = 'user-abc';

/// Writes a subscription status document directly into the fake Firestore.
Future<void> _writeStatus(
  FakeFirebaseFirestore db,
  Map<String, dynamic> data, {
  String uid = _uid,
}) =>
    db
        .collection('users')
        .doc(uid)
        .collection('subscription')
        .doc('status')
        .set(data);

void main() {
  late FakeFirebaseFirestore db;
  late MockFirebaseFunctions fn;
  late MockHttpsCallable callable;
  late MockHttpsCallableResult callableResult;

  setUp(() {
    db = FakeFirebaseFirestore();
    fn = MockFirebaseFunctions();
    callable = MockHttpsCallable();
    callableResult = MockHttpsCallableResult();
    when(() => fn.httpsCallable('validateReceipt')).thenReturn(callable);
    registerFallbackValue(<String, dynamic>{});
  });

  FirestoreIAPRepository _repo({String? uid = _uid}) =>
      FirestoreIAPRepository(db: db, getUid: () => uid, fn: fn);

  // ── getPremiumStatus ───────────────────────────────────────────────────────

  group('getPremiumStatus', () {
    test('returns false when user is not authenticated', () async {
      final result = await _repo(uid: null).getPremiumStatus();
      expect(result, false);
    });

    test('returns false when subscription document does not exist', () async {
      // No document written — Firestore returns a non-existent snapshot.
      final result = await _repo().getPremiumStatus();
      expect(result, false);
    });

    test('returns false when status is "expired"', () async {
      await _writeStatus(db, {'status': 'expired', 'expiresAt': null});
      final result = await _repo().getPremiumStatus();
      expect(result, false);
    });

    test('returns false when status is "cancelled"', () async {
      await _writeStatus(db, {'status': 'cancelled', 'expiresAt': null});
      final result = await _repo().getPremiumStatus();
      expect(result, false);
    });

    test('returns true for lifetime purchase — status active, expiresAt null',
        () async {
      await _writeStatus(db, {'status': 'active', 'expiresAt': null});
      final result = await _repo().getPremiumStatus();
      expect(result, true);
    });

    test('returns true when subscription is active and expiry is in future',
        () async {
      final future = Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 30)));
      await _writeStatus(db, {'status': 'active', 'expiresAt': future});
      final result = await _repo().getPremiumStatus();
      expect(result, true);
    });

    test('returns false when subscription is active but expiry has passed',
        () async {
      final past = Timestamp.fromDate(
          DateTime.now().subtract(const Duration(seconds: 1)));
      await _writeStatus(db, {'status': 'active', 'expiresAt': past});
      final result = await _repo().getPremiumStatus();
      expect(result, false);
    });

    test('returns false when expiresAt is a non-Timestamp value', () async {
      // Corrupt / unexpected Firestore data.
      await _writeStatus(db, {'status': 'active', 'expiresAt': 'bad-value'});
      final result = await _repo().getPremiumStatus();
      expect(result, false);
    });

    test('returns null on Firestore exception — signals optimistic hold', () async {
      // Inject a broken FirebaseFirestore that throws on collection access.
      final badDb = _ThrowingFirestore();
      final repo = FirestoreIAPRepository(db: badDb, getUid: () => _uid, fn: fn);
      final result = await repo.getPremiumStatus();
      expect(result, isNull);
    });
  });

  // ── validateReceipt ────────────────────────────────────────────────────────

  group('validateReceipt', () {
    test('throws StateError when user is not authenticated', () {
      expect(
        () => _repo(uid: null).validateReceipt(
          platform: 'android',
          productId: 'monthlysub',
          purchaseToken: 'token',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('calls callable with correct Android payload and returns true', () async {
      when(() => callableResult.data).thenReturn({'isPremium': true});
      when(() => callable.call<Map<String, dynamic>>(any()))
          .thenAnswer((_) async => callableResult);

      final result = await _repo().validateReceipt(
        platform: 'android',
        productId: 'monthlysub',
        purchaseToken: 'token-abc',
      );

      expect(result, true);
      final payload =
          verify(() => callable.call<Map<String, dynamic>>(captureAny()))
              .captured
              .single as Map<String, dynamic>;
      expect(payload['platform'], 'android');
      expect(payload['productId'], 'monthlysub');
      expect(payload['purchaseToken'], 'token-abc');
      expect(payload.containsKey('receiptData'), false);
    });

    test('calls callable with correct iOS payload and returns true', () async {
      when(() => callableResult.data).thenReturn({'isPremium': true});
      when(() => callable.call<Map<String, dynamic>>(any()))
          .thenAnswer((_) async => callableResult);

      final result = await _repo().validateReceipt(
        platform: 'ios',
        productId: 'annualsub',
        receiptData: 'base64data==',
      );

      expect(result, true);
      final payload =
          verify(() => callable.call<Map<String, dynamic>>(captureAny()))
              .captured
              .single as Map<String, dynamic>;
      expect(payload['platform'], 'ios');
      expect(payload['productId'], 'annualsub');
      expect(payload['receiptData'], 'base64data==');
      expect(payload.containsKey('purchaseToken'), false);
    });

    test('returns false when callable returns isPremium: false', () async {
      when(() => callableResult.data).thenReturn({'isPremium': false});
      when(() => callable.call<Map<String, dynamic>>(any()))
          .thenAnswer((_) async => callableResult);

      final result = await _repo().validateReceipt(
        platform: 'android',
        productId: 'lifetimeonetime',
        purchaseToken: 'token-life',
      );

      expect(result, false);
    });

    test('returns false when isPremium field is absent from response', () async {
      when(() => callableResult.data).thenReturn({});
      when(() => callable.call<Map<String, dynamic>>(any()))
          .thenAnswer((_) async => callableResult);

      final result = await _repo().validateReceipt(
        platform: 'android',
        productId: 'monthlysub',
        purchaseToken: 'token-abc',
      );

      expect(result, false);
    });

    test('rethrows FirebaseFunctionsException from callable', () async {
      when(() => callable.call<Map<String, dynamic>>(any()))
          .thenThrow(FirebaseFunctionsException(
              message: 'validation failed', code: 'failed-precondition'));

      expect(
        () => _repo().validateReceipt(
          platform: 'android',
          productId: 'monthlysub',
          purchaseToken: 'bad-token',
        ),
        throwsA(isA<FirebaseFunctionsException>()),
      );
    });
  });
}

// ── Test double that throws on any Firestore call ─────────────────────────────

/// Simulates a Firestore network error for the null-return path of
/// [FirestoreIAPRepository.getPremiumStatus].
class _ThrowingFirestore extends Fake implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    throw Exception('simulated network error');
  }
}
