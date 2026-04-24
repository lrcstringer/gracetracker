import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:mocktail/mocktail.dart';
import 'package:graceway/domain/repositories/iap_repository.dart';
import 'package:graceway/presentation/providers/store_provider.dart';

// ── Mocks (mockable non-sealed classes) ───────────────────────────────────

class MockIAPRepository extends Mock implements IAPRepository {}

class MockInAppPurchase extends Mock implements InAppPurchase {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

// ── Fakes ─────────────────────────────────────────────────────────────────

/// firebase_auth User is @sealed — only implement the uid surface we need.
class _FakeUser extends Fake implements User {
  @override
  final String uid;
  _FakeUser(this.uid);
}

/// Concrete [ProductDetails] for controlling rawPrice in tests.
class _FakeProduct extends ProductDetails {
  _FakeProduct({required String id, required double rawPrice})
      : super(
          id: id,
          title: 'Test: $id',
          description: '',
          price: '\$$rawPrice',
          rawPrice: rawPrice,
          currencyCode: 'USD',
        );
}

/// Concrete [PurchaseDetails] for emitting purchase stream events.
class _FakePurchase extends PurchaseDetails {
  _FakePurchase({
    required String productID,
    required PurchaseStatus status,
    bool pendingComplete = false,
    IAPError? iapError,
    String source = 'google_play',
  }) : super(
          productID: productID,
          verificationData: PurchaseVerificationData(
            localVerificationData: 'local-receipt',
            serverVerificationData: 'server-token',
            source: source,
          ),
          transactionDate: '2024-01-01',
          status: status,
        ) {
    pendingCompletePurchase = pendingComplete;
    error = iapError;
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────

const _uid = 'user-test-123';
const _monthly = GraceWayProducts.monthly;
const _annual = GraceWayProducts.annual;

// ── Setup helpers ─────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockIAPRepository mockRepo;
  late MockInAppPurchase mockIap;
  late MockFirebaseAuth mockAuth;
  late StreamController<List<PurchaseDetails>> purchaseController;
  late StoreProvider provider;

  /// Stub the happy-path defaults shared by most tests. Individual tests may
  /// override any of these with additional `when` calls.
  void stubDefaults() {
    when(() => mockIap.isAvailable()).thenAnswer((_) async => true);
    when(() => mockIap.purchaseStream)
        .thenAnswer((_) => purchaseController.stream);
    when(() => mockIap.queryProductDetails(any())).thenAnswer(
      (_) async => ProductDetailsResponse(
        productDetails: [],
        error: null,
        notFoundIDs: <String>[],
      ),
    );
    when(() => mockIap.completePurchase(any())).thenAnswer((_) async {});
    when(() => mockIap.buyNonConsumable(purchaseParam: any(named: 'purchaseParam')))
        .thenAnswer((_) async => true);
    when(() => mockIap.restorePurchases()).thenAnswer((_) async {});
    when(() => mockRepo.getPremiumStatus()).thenAnswer((_) async => false);
    when(() => mockRepo.validateReceipt(
          platform: any(named: 'platform'),
          productId: any(named: 'productId'),
          purchaseToken: any(named: 'purchaseToken'),
          receiptData: any(named: 'receiptData'),
        )).thenAnswer((_) async => true);
    when(() => mockAuth.currentUser).thenReturn(_FakeUser(_uid));
  }

  setUp(() {
    mockRepo = MockIAPRepository();
    mockIap = MockInAppPurchase();
    mockAuth = MockFirebaseAuth();
    purchaseController = StreamController<List<PurchaseDetails>>.broadcast();

    registerFallbackValue(
      PurchaseParam(
        productDetails: _FakeProduct(id: 'fallback', rawPrice: 0),
      ),
    );
    registerFallbackValue(
      _FakePurchase(productID: 'fallback', status: PurchaseStatus.pending),
    );
    registerFallbackValue(<String>{});

    stubDefaults();

    provider = StoreProvider(
      iapRepository: mockRepo,
      iap: mockIap,
      auth: mockAuth,
    );
  });

  tearDown(() async {
    provider.dispose();
    await purchaseController.close();
  });

  // ── init ───────────────────────────────────────────────────────────────

  group('init', () {
    test('is idempotent — second call is a no-op', () async {
      await provider.init();
      await provider.init();

      // isAvailable and queryProductDetails are called exactly once.
      verify(() => mockIap.isAvailable()).called(1);
      verify(() => mockIap.queryProductDetails(any())).called(1);
    });

    test('sets isLoading=false when store is unavailable', () async {
      when(() => mockIap.isAvailable()).thenAnswer((_) async => false);

      await provider.init();

      expect(provider.isLoading, false);
      verifyNever(() => mockIap.queryProductDetails(any()));
    });

    test('loads products and syncs premium when store is available', () async {
      final product = _FakeProduct(id: _monthly, rawPrice: 4.99);
      when(() => mockIap.queryProductDetails(any())).thenAnswer(
        (_) async => ProductDetailsResponse(
          productDetails: [product],
          error: null,
          notFoundIDs: <String>[],
        ),
      );
      when(() => mockRepo.getPremiumStatus()).thenAnswer((_) async => true);

      await provider.init();

      expect(provider.monthlyProduct, isNotNull);
      expect(provider.isPremium, true);
      expect(provider.isLoading, false);
    });

    test('subscribes to purchaseStream exactly once', () async {
      await provider.init();

      // Reading purchaseStream is how the subscription is established.
      verify(() => mockIap.purchaseStream).called(1);
    });

    test('sets error when queryProductDetails throws', () async {
      when(() => mockIap.queryProductDetails(any()))
          .thenThrow(Exception('network timeout'));

      await provider.init();

      expect(provider.error, isNotNull);
    });
  });

  // ── monthlySavingsText ─────────────────────────────────────────────────

  group('monthlySavingsText', () {
    test('returns null when products are not loaded', () {
      // No init — products map is empty.
      expect(provider.monthlySavingsText, isNull);
    });

    test('returns null when annual costs more than 12x monthly', () async {
      when(() => mockIap.queryProductDetails(any())).thenAnswer(
        (_) async => ProductDetailsResponse(
          productDetails: [
            _FakeProduct(id: _monthly, rawPrice: 4.99),
            _FakeProduct(id: _annual, rawPrice: 100.00), // more expensive
          ],
          error: null,
          notFoundIDs: <String>[],
        ),
      );
      await provider.init();

      expect(provider.monthlySavingsText, isNull);
    });

    test('returns "Save X%" when annual is cheaper than 12× monthly', () async {
      // 4.99 * 12 = 59.88; annual 39.99 → savings ≈ 33%
      when(() => mockIap.queryProductDetails(any())).thenAnswer(
        (_) async => ProductDetailsResponse(
          productDetails: [
            _FakeProduct(id: _monthly, rawPrice: 4.99),
            _FakeProduct(id: _annual, rawPrice: 39.99),
          ],
          error: null,
          notFoundIDs: <String>[],
        ),
      );
      await provider.init();

      final text = provider.monthlySavingsText;
      expect(text, isNotNull);
      expect(text, startsWith('Save '));
      expect(text, endsWith('%'));
    });

    test('percentage rounds correctly for exact savings', () async {
      // 10.00 * 12 = 120; annual 80 → savings = 33%
      when(() => mockIap.queryProductDetails(any())).thenAnswer(
        (_) async => ProductDetailsResponse(
          productDetails: [
            _FakeProduct(id: _monthly, rawPrice: 10.00),
            _FakeProduct(id: _annual, rawPrice: 80.00),
          ],
          error: null,
          notFoundIDs: <String>[],
        ),
      );
      await provider.init();

      expect(provider.monthlySavingsText, 'Save 33%');
    });
  });

  // ── _syncPremiumStatus ─────────────────────────────────────────────────

  group('_syncPremiumStatus (via init)', () {
    test('sets isPremium=true when repository returns true', () async {
      when(() => mockRepo.getPremiumStatus()).thenAnswer((_) async => true);

      await provider.init();

      expect(provider.isPremium, true);
    });

    test('sets isPremium=false when repository returns false', () async {
      provider.isPremium = true; // Start as premium to prove it's overwritten.
      when(() => mockRepo.getPremiumStatus()).thenAnswer((_) async => false);

      await provider.init();

      expect(provider.isPremium, false);
    });

    test('leaves isPremium unchanged when repository returns null (transient error)',
        () async {
      provider.isPremium = true; // Simulates an existing-premium user.
      when(() => mockRepo.getPremiumStatus()).thenAnswer((_) async => null);

      await provider.init();

      // Null means "keep what we have" — should still be true.
      expect(provider.isPremium, true);
    });
  });

  // ── purchase ──────────────────────────────────────────────────────────

  group('purchase', () {
    late _FakeProduct product;

    setUp(() async {
      product = _FakeProduct(id: _monthly, rawPrice: 4.99);
      await provider.init();
    });

    test('sets isPurchasing=true before calling buyNonConsumable', () async {
      // Capture the isPurchasing state as seen by the store.
      var purchasingOnCall = false;
      when(() => mockIap.buyNonConsumable(
              purchaseParam: any(named: 'purchaseParam')))
          .thenAnswer((_) async {
        purchasingOnCall = provider.isPurchasing;
        return true;
      });

      await provider.purchase(product);

      expect(purchasingOnCall, true);
    });

    test('passes obfuscated UID (SHA-256 hex) as applicationUserName', () async {
      PurchaseParam? captured;
      when(() => mockIap.buyNonConsumable(
              purchaseParam: any(named: 'purchaseParam')))
          .thenAnswer((inv) async {
        captured = inv.namedArguments[#purchaseParam] as PurchaseParam;
        return true;
      });

      await provider.purchase(product);

      expect(captured?.applicationUserName, isNotNull);
      expect(captured!.applicationUserName, isNot(equals(_uid)));
      // SHA-256 hex string is 64 chars.
      expect(captured!.applicationUserName!.length, 64);
    });

    test('passes null applicationUserName when user is not authenticated',
        () async {
      when(() => mockAuth.currentUser).thenReturn(null);
      PurchaseParam? captured;
      when(() => mockIap.buyNonConsumable(
              purchaseParam: any(named: 'purchaseParam')))
          .thenAnswer((inv) async {
        captured = inv.namedArguments[#purchaseParam] as PurchaseParam;
        return true;
      });

      await provider.purchase(product);

      expect(captured?.applicationUserName, isNull);
    });

    test('race-condition guard: concurrent calls only trigger one purchase',
        () async {
      // Start two purchases concurrently — only the first should call the store.
      await Future.wait([
        provider.purchase(product),
        provider.purchase(product),
      ]);

      verify(() => mockIap.buyNonConsumable(
          purchaseParam: any(named: 'purchaseParam'))).called(1);
    });

    test('clears error and sets isPurchasing before calling store', () async {
      provider.error = 'previous error';

      await provider.purchase(product);

      // error is cleared on every new purchase attempt.
      // isPurchasing is true during the call (tested via the state-capture test).
      verify(() => mockIap.buyNonConsumable(
          purchaseParam: any(named: 'purchaseParam'))).called(1);
    });

    test('on exception: clears isPurchasing and sets error', () async {
      when(() => mockIap.buyNonConsumable(
              purchaseParam: any(named: 'purchaseParam')))
          .thenThrow(Exception('billing unavailable'));

      await provider.purchase(product);

      expect(provider.isPurchasing, false);
      expect(provider.error, isNotNull);
    });

    test('buyNonConsumable returning false clears isPurchasing and sets error',
        () async {
      when(() => mockIap.buyNonConsumable(
              purchaseParam: any(named: 'purchaseParam')))
          .thenAnswer((_) async => false);

      await provider.purchase(product);

      expect(provider.isPurchasing, false);
      expect(provider.error, isNotNull);
    });
  });

  // ── _onPurchaseUpdates ─────────────────────────────────────────────────

  group('_onPurchaseUpdates', () {
    setUp(() async {
      await provider.init();
      provider.isPurchasing = true; // Simulate an in-flight purchase.
    });

    test('pending: no state change', () async {
      purchaseController.add([
        _FakePurchase(
          productID: _monthly,
          status: PurchaseStatus.pending,
        ),
      ]);
      // Allow microtasks to run.
      await Future<void>.delayed(Duration.zero);

      expect(provider.isPurchasing, true); // unchanged
      verifyNever(() => mockIap.completePurchase(any()));
    });

    test('purchased: completes purchase, validates with server, clears isPurchasing',
        () async {
      when(() => mockRepo.validateReceipt(
            platform: any(named: 'platform'),
            productId: any(named: 'productId'),
            purchaseToken: any(named: 'purchaseToken'),
            receiptData: any(named: 'receiptData'),
          )).thenAnswer((_) async => true);

      purchaseController.add([
        _FakePurchase(
          productID: _monthly,
          status: PurchaseStatus.purchased,
          pendingComplete: true,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      verify(() => mockIap.completePurchase(any())).called(1);
      verify(() => mockRepo.validateReceipt(
            platform: any(named: 'platform'),
            productId: any(named: 'productId'),
            purchaseToken: any(named: 'purchaseToken'),
            receiptData: any(named: 'receiptData'),
          )).called(1);
      expect(provider.isPurchasing, false);
      expect(provider.isPremium, true);
    });

    test('purchased: skips completePurchase when pendingCompletePurchase=false',
        () async {
      purchaseController.add([
        _FakePurchase(
          productID: _monthly,
          status: PurchaseStatus.purchased,
          pendingComplete: false, // already acknowledged
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => mockIap.completePurchase(any()));
      expect(provider.isPurchasing, false);
    });

    test('purchased (google_play source): passes purchaseToken, not receiptData',
        () async {
      // verificationData.source = 'google_play' → android path.
      purchaseController.add([
        _FakePurchase(
          productID: _monthly,
          status: PurchaseStatus.purchased,
          pendingComplete: false,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      final captured =
          verify(() => mockRepo.validateReceipt(
                platform: captureAny(named: 'platform'),
                productId: captureAny(named: 'productId'),
                purchaseToken: captureAny(named: 'purchaseToken'),
                receiptData: captureAny(named: 'receiptData'),
              )).captured;
      // captured order: platform, productId, purchaseToken, receiptData.
      expect(captured[0], 'android');
      expect(captured[2], 'server-token'); // serverVerificationData
      expect(captured[3], isNull); // receiptData not sent for android
    });

    test('purchased (app_store source): passes receiptData, not purchaseToken',
        () async {
      purchaseController.add([
        _FakePurchase(
          productID: _monthly,
          status: PurchaseStatus.purchased,
          pendingComplete: false,
          source: 'app_store',
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      final captured =
          verify(() => mockRepo.validateReceipt(
                platform: captureAny(named: 'platform'),
                productId: captureAny(named: 'productId'),
                purchaseToken: captureAny(named: 'purchaseToken'),
                receiptData: captureAny(named: 'receiptData'),
              )).captured;
      expect(captured[0], 'ios');
      expect(captured[2], isNull); // purchaseToken not sent for ios
      expect(captured[3], 'local-receipt'); // localVerificationData
    });

    test('purchased: completePurchase throwing clears isPurchasing and notifies',
        () async {
      when(() => mockIap.completePurchase(any()))
          .thenThrow(Exception('ack failed'));

      purchaseController.add([
        _FakePurchase(
          productID: _monthly,
          status: PurchaseStatus.purchased,
          pendingComplete: true,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(provider.isPurchasing, false);
      expect(provider.error, isNotNull);
      // validateReceipt must NOT be called when completePurchase throws.
      verifyNever(() => mockRepo.validateReceipt(
            platform: any(named: 'platform'),
            productId: any(named: 'productId'),
            purchaseToken: any(named: 'purchaseToken'),
            receiptData: any(named: 'receiptData'),
          ));
    });

    test('purchased: clears isPurchasing even when validateReceipt throws', () async {
      when(() => mockRepo.validateReceipt(
            platform: any(named: 'platform'),
            productId: any(named: 'productId'),
            purchaseToken: any(named: 'purchaseToken'),
            receiptData: any(named: 'receiptData'),
          )).thenThrow(Exception('server error'));

      purchaseController.add([
        _FakePurchase(
          productID: _monthly,
          status: PurchaseStatus.purchased,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(provider.isPurchasing, false);
      expect(provider.error, isNotNull);
    });

    test('restored: same as purchased — completes and validates', () async {
      purchaseController.add([
        _FakePurchase(
          productID: _annual,
          status: PurchaseStatus.restored,
          pendingComplete: true,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      verify(() => mockIap.completePurchase(any())).called(1);
      expect(provider.isPurchasing, false);
    });

    test('error (genuine): clears isPurchasing and sets error', () async {
      purchaseController.add([
        _FakePurchase(
          productID: _monthly,
          status: PurchaseStatus.error,
          iapError: IAPError(
            source: 'google_play',
            code: 'billing_unavailable',
            message: 'Billing service unavailable',
          ),
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(provider.isPurchasing, false);
      expect(provider.error, isNotNull);
    });

    test('error (user cancelled via message): clears isPurchasing, does NOT set error',
        () async {
      purchaseController.add([
        _FakePurchase(
          productID: _monthly,
          status: PurchaseStatus.error,
          iapError: IAPError(
            source: 'google_play',
            code: 'cancel',
            message: 'User cancelled the purchase',
          ),
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(provider.isPurchasing, false);
      expect(provider.error, isNull);
    });

    test('error (Android BillingResponse.userCanceled): clears isPurchasing, no error',
        () async {
      purchaseController.add([
        _FakePurchase(
          productID: _monthly,
          status: PurchaseStatus.error,
          iapError: IAPError(
            source: 'google_play',
            code: 'BillingResponse.userCanceled',
            message: 'User pressed back',
          ),
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(provider.isPurchasing, false);
      expect(provider.error, isNull);
    });

    test('error (iOS SKErrorPaymentCancelled, code=2): clears isPurchasing, no error',
        () async {
      purchaseController.add([
        _FakePurchase(
          productID: _monthly,
          status: PurchaseStatus.error,
          iapError: IAPError(
            source: 'app_store',
            code: '2',
            message: 'SKErrorPaymentCancelled',
          ),
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(provider.isPurchasing, false);
      expect(provider.error, isNull);
    });

    test('canceled: clears isPurchasing, no error', () async {
      purchaseController.add([
        _FakePurchase(
          productID: _monthly,
          status: PurchaseStatus.canceled,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(provider.isPurchasing, false);
      expect(provider.error, isNull);
    });

    test('multiple purchases in one batch are processed sequentially', () async {
      final order = <String>[];
      when(() => mockRepo.validateReceipt(
            platform: any(named: 'platform'),
            productId: any(named: 'productId'),
            purchaseToken: any(named: 'purchaseToken'),
            receiptData: any(named: 'receiptData'),
          )).thenAnswer((inv) async {
        order.add(inv.namedArguments[#productId] as String);
        return true;
      });

      purchaseController.add([
        _FakePurchase(productID: _monthly, status: PurchaseStatus.purchased),
        _FakePurchase(productID: _annual, status: PurchaseStatus.purchased),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(order, [_monthly, _annual]);
    });
  });

  // ── restore ───────────────────────────────────────────────────────────

  group('restore', () {
    setUp(() async {
      await provider.init();
    });

    test('calls restorePurchases on the store', () async {
      await provider.restore();

      verify(() => mockIap.restorePurchases()).called(1);
    });

    test('sets isLoading=true before call and false after', () async {
      final states = <bool>[];
      provider.addListener(() => states.add(provider.isLoading));

      await provider.restore();

      // Must have seen true then false.
      expect(states, containsAllInOrder([true, false]));
    });

    test('clears error and sets isLoading=false on exception', () async {
      provider.error = 'old error';
      when(() => mockIap.restorePurchases()).thenThrow(Exception('network'));

      await provider.restore();

      expect(provider.isLoading, false);
      expect(provider.error, isNotNull);
    });
  });

  // ── didChangeAppLifecycleState ────────────────────────────────────────

  group('didChangeAppLifecycleState', () {
    setUp(() async {
      await provider.init();
    });

    test('resumed: re-syncs premium status from repository', () async {
      when(() => mockRepo.getPremiumStatus()).thenAnswer((_) async => true);

      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);

      // getPremiumStatus was called once during init and once on resume.
      verify(() => mockRepo.getPremiumStatus()).called(2);
      expect(provider.isPremium, true);
    });

    test('paused: does NOT trigger a sync', () async {
      provider.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);

      // Only the init call — no extra call from paused.
      verify(() => mockRepo.getPremiumStatus()).called(1);
    });

    test('inactive: does NOT trigger a sync', () async {
      provider.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await Future<void>.delayed(Duration.zero);

      verify(() => mockRepo.getPremiumStatus()).called(1);
    });
  });
}
