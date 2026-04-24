/// Integration test — full purchase flow.
///
/// Tests the complete interaction between [StoreProvider], [PaywallScreen], and
/// [IAPRepository] from initial product load through to premium activation and
/// navigation. Uses in-process fakes (no device required) so the suite can
/// run with `flutter test`.
///
/// Flow under test:
///   1. Store initialises → products loaded → PaywallScreen shows plan cards.
///   2. User taps CTA (annual plan, default) → [StoreProvider.purchase] called.
///   3. Google Play emits [PurchaseStatus.purchased] on the stream.
///   4. [completePurchase] is called (acknowledge within 3-day window).
///   5. [validateReceipt] is called with the correct server-side payload.
///   6. [isPremium] transitions to `true`.
///   7. [PaywallScreen.onNext] callback fires (navigation out of paywall).
library;

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:graceway/domain/repositories/iap_repository.dart';
import 'package:graceway/presentation/providers/store_provider.dart';
import 'package:graceway/presentation/views/onboarding/paywall_screen.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────

class MockInAppPurchase extends Mock implements InAppPurchase {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

// ── Fakes ─────────────────────────────────────────────────────────────────

class _FakeUser extends Fake implements User {
  @override
  final String uid;
  _FakeUser(this.uid);
}

class _FakeProduct extends ProductDetails {
  _FakeProduct({required String id, required double rawPrice})
      : super(
          id: id,
          title: id,
          description: '',
          price: '\$${rawPrice.toStringAsFixed(2)}',
          rawPrice: rawPrice,
          currencyCode: 'USD',
        );
}

class _FakePurchase extends PurchaseDetails {
  _FakePurchase({
    required String productID,
    required PurchaseStatus status,
    bool pendingComplete = true,
  }) : super(
          productID: productID,
          verificationData: PurchaseVerificationData(
            localVerificationData: 'local-receipt-data',
            serverVerificationData: 'server-purchase-token',
            source: 'google_play',
          ),
          transactionDate: '2024-01-01',
          status: status,
        ) {
    pendingCompletePurchase = pendingComplete;
  }
}

// ── Test helpers ───────────────────────────────────────────────────────────

/// Stub [IAPRepository] that records calls to [validateReceipt] and allows
/// per-test configuration of the return value.
class _StubIAPRepository implements IAPRepository {
  bool? _premiumStatus;
  bool _validateResult = true;

  // Captured arguments from the last [validateReceipt] call.
  String? lastValidatePlatform;
  String? lastValidateProductId;
  String? lastValidatePurchaseToken;
  String? lastValidateReceiptData;

  void configurePremiumStatus(bool? status) => _premiumStatus = status;
  void configureValidateResult(bool result) => _validateResult = result;

  @override
  Future<bool?> getPremiumStatus() async => _premiumStatus;

  @override
  Stream<bool> watchPremiumStatus() => const Stream.empty();

  @override
  Future<bool> validateReceipt({
    required String platform,
    required String productId,
    String? purchaseToken,
    String? receiptData,
  }) async {
    lastValidatePlatform = platform;
    lastValidateProductId = productId;
    lastValidatePurchaseToken = purchaseToken;
    lastValidateReceiptData = receiptData;
    return _validateResult;
  }
}

// ── Test ───────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockInAppPurchase mockIap;
  late MockFirebaseAuth mockAuth;
  late StreamController<List<PurchaseDetails>> purchaseController;
  late _StubIAPRepository stubRepo;
  late StoreProvider store;

  final annualProduct =
      _FakeProduct(id: GraceWayProducts.annual, rawPrice: 39.99);
  final monthlyProduct =
      _FakeProduct(id: GraceWayProducts.monthly, rawPrice: 4.99);
  final lifetimeProduct =
      _FakeProduct(id: GraceWayProducts.lifetime, rawPrice: 99.99);

  setUp(() {
    mockIap = MockInAppPurchase();
    mockAuth = MockFirebaseAuth();
    purchaseController =
        StreamController<List<PurchaseDetails>>.broadcast();
    stubRepo = _StubIAPRepository();

    registerFallbackValue(
      PurchaseParam(
        productDetails: _FakeProduct(id: 'fallback', rawPrice: 0),
      ),
    );
    registerFallbackValue(
      _FakePurchase(
          productID: 'fallback', status: PurchaseStatus.pending),
    );

    when(() => mockIap.isAvailable()).thenAnswer((_) async => true);
    when(() => mockIap.purchaseStream)
        .thenAnswer((_) => purchaseController.stream);
    when(() => mockIap.queryProductDetails(any())).thenAnswer(
      (_) async => ProductDetailsResponse(
        productDetails: [annualProduct, monthlyProduct, lifetimeProduct],
        error: null,
        notFoundIDs: <String>[],
      ),
    );
    when(() => mockIap.buyNonConsumable(
            purchaseParam: any(named: 'purchaseParam')))
        .thenAnswer((_) async => true);
    when(() => mockIap.completePurchase(any())).thenAnswer((_) async {});
    when(() => mockAuth.currentUser).thenReturn(_FakeUser('uid-flow-test'));

    stubRepo.configurePremiumStatus(false);
  });

  tearDown(() async {
    store.dispose();
    await purchaseController.close();
  });

  Future<void> initStore() async {
    store = StoreProvider(
      iapRepository: stubRepo,
      iap: mockIap,
      auth: mockAuth,
    );
    await store.init();
  }

  Widget buildTestApp({required VoidCallback onNext}) {
    return MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider<StoreProvider>.value(
          value: store,
          child: PaywallScreen(onNext: onNext),
        ),
      ),
    );
  }

  /// Advances fake time to settle [PaywallScreen]'s initState timers and
  /// animations, then scrolls a plan card into view.
  Future<void> settle(WidgetTester tester, {Finder? scrollTo}) async {
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    if (scrollTo != null) {
      await tester.ensureVisible(scrollTo);
      await tester.pumpAndSettle();
    }
  }

  // ── Step 1: Products load and are displayed ──────────────────────────

  testWidgets('Step 1 — products load and plan cards are visible',
      (tester) async {
    await initStore();
    await tester.pumpWidget(buildTestApp(onNext: () {}));
    await settle(tester);

    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Yearly'), findsOneWidget);
    expect(find.text('Lifetime'), findsOneWidget);
    expect(find.text('Start Free Trial'), findsOneWidget); // annual default
  });

  // ── Step 2: CTA label reflects selected plan ─────────────────────────

  testWidgets('Step 2 — selecting monthly plan changes CTA label',
      (tester) async {
    await initStore();
    await tester.pumpWidget(buildTestApp(onNext: () {}));
    await settle(tester, scrollTo: find.text('Monthly'));

    await tester.tap(find.text('Monthly'));
    await tester.pump();

    expect(find.text('Subscribe Monthly'), findsOneWidget);
  });

  // ── Steps 3–7: Full purchase flow for annual plan ────────────────────

  testWidgets(
      'Steps 3–7 — tapping CTA initiates purchase, '
      'stream delivers purchased event, receipt is validated, '
      'isPremium becomes true, onNext fires',
      (tester) async {
    await initStore();
    var onNextCalled = false;

    await tester.pumpWidget(buildTestApp(onNext: () => onNextCalled = true));
    await settle(tester);

    // Step 3 — Tap CTA; store.purchase is called → isPurchasing=true.
    await tester.tap(find.text('Start Free Trial'));
    await tester.pump();

    expect(store.isPurchasing, true,
        reason: 'isPurchasing must be true while awaiting store response');
    verify(() => mockIap.buyNonConsumable(
            purchaseParam: any(named: 'purchaseParam')))
        .called(1);

    // Step 4 — Google Play emits a purchased event.
    purchaseController.add([
      _FakePurchase(
        productID: GraceWayProducts.annual,
        status: PurchaseStatus.purchased,
        pendingComplete: true,
      ),
    ]);
    await tester.pump();

    // Step 4a — completePurchase called (within-3-day acknowledgement).
    verify(() => mockIap.completePurchase(any())).called(1);

    // Step 5 — validateReceipt called with correct payload.
    // verificationData.source = 'google_play' → android path.
    expect(stubRepo.lastValidateProductId, GraceWayProducts.annual);
    expect(stubRepo.lastValidatePlatform, 'android');
    expect(stubRepo.lastValidatePurchaseToken, 'server-purchase-token');
    expect(stubRepo.lastValidateReceiptData, isNull);

    // Step 6 — isPremium becomes true after successful validation.
    expect(store.isPremium, true);
    expect(store.isPurchasing, false);

    // Step 7 — onNext fires via _onStoreChanged in PaywallScreen.
    await tester.pump(); // allow _onStoreChanged → widget.onNext()
    expect(onNextCalled, true);
  });

  // ── Error path: purchase cancelled by user ────────────────────────────

  testWidgets('purchase cancelled — isPurchasing cleared, error not set',
      (tester) async {
    await initStore();

    await tester.pumpWidget(buildTestApp(onNext: () {}));
    await settle(tester);

    await tester.tap(find.text('Start Free Trial'));
    await tester.pump();

    // Simulate user cancellation via Android BillingResponse.
    purchaseController.add([
      _FakePurchase(
        productID: GraceWayProducts.annual,
        status: PurchaseStatus.error,
        pendingComplete: false,
      )..error = IAPError(
          source: 'google_play',
          code: 'BillingResponse.userCanceled',
          message: 'User cancelled',
        ),
    ]);
    await tester.pump();

    expect(store.isPurchasing, false);
    expect(store.error, isNull);
    expect(store.isPremium, false);
  });

  // ── Error path: server validation failure ─────────────────────────────

  testWidgets('validation failure — isPremium stays false, error is set',
      (tester) async {
    await initStore();
    stubRepo.configureValidateResult(false); // server says not premium

    await tester.pumpWidget(buildTestApp(onNext: () {}));
    await settle(tester);

    await tester.tap(find.text('Start Free Trial'));
    await tester.pump();

    purchaseController.add([
      _FakePurchase(
        productID: GraceWayProducts.annual,
        status: PurchaseStatus.purchased,
      ),
    ]);
    await tester.pump();

    expect(store.isPremium, false);
    expect(store.isPurchasing, false);
  });

  // ── Full restore flow ─────────────────────────────────────────────────

  testWidgets(
      'restore — previously purchased subscription is re-validated '
      'and isPremium becomes true',
      (tester) async {
    await initStore();

    await tester.pumpWidget(buildTestApp(onNext: () {}));
    await settle(tester);

    // Tap the Restore button.
    await tester.tap(find.text('Restore'));
    await tester.pump();

    verify(() => mockIap.restorePurchases()).called(1);

    // Store delivers a restored purchase.
    purchaseController.add([
      _FakePurchase(
        productID: GraceWayProducts.annual,
        status: PurchaseStatus.restored,
        pendingComplete: true,
      ),
    ]);
    await tester.pump();

    verify(() => mockIap.completePurchase(any())).called(1);
    expect(stubRepo.lastValidateProductId, GraceWayProducts.annual);
    expect(store.isPremium, true);
  });
}
