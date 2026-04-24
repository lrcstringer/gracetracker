/// Widget tests for [PaywallScreen] (onboarding) and [GraceWayPaywallView] (contextual).
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
import 'package:graceway/presentation/views/shared/graceway_paywall_view.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────

class MockIAPRepository extends Mock implements IAPRepository {}

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

// ── Test dependency container ──────────────────────────────────────────────

class _Deps {
  final StoreProvider store;
  final MockInAppPurchase mockIap;
  _Deps(this.store, this.mockIap);
}

// ── Helpers ────────────────────────────────────────────────────────────────

Future<_Deps> _buildTestStore(
  WidgetTester tester, {
  List<ProductDetails> products = const [],
  bool isPremium = false,
}) async {
  final repo = MockIAPRepository();
  final mockIap = MockInAppPurchase();
  final auth = MockFirebaseAuth();
  final controller = StreamController<List<PurchaseDetails>>.broadcast();

  registerFallbackValue(
    PurchaseParam(
      productDetails: _FakeProduct(id: 'fallback', rawPrice: 0),
    ),
  );

  when(() => mockIap.isAvailable()).thenAnswer((_) async => true);
  when(() => mockIap.purchaseStream).thenAnswer((_) => controller.stream);
  when(() => mockIap.queryProductDetails(any())).thenAnswer(
    (_) async => ProductDetailsResponse(
      productDetails: products,
      error: null,
      notFoundIDs: <String>[],
    ),
  );
  when(() => mockIap.buyNonConsumable(
          purchaseParam: any(named: 'purchaseParam')))
      .thenAnswer((_) async => true);
  when(() => repo.getPremiumStatus()).thenAnswer((_) async => isPremium);
  when(() => auth.currentUser).thenReturn(_FakeUser('uid-test'));

  final store = StoreProvider(iapRepository: repo, iap: mockIap, auth: auth);
  await store.init();

  addTearDown(() {
    store.dispose();
    controller.close();
  });

  return _Deps(store, mockIap);
}

List<_FakeProduct> get _allProducts => [
      _FakeProduct(id: GraceWayProducts.monthly, rawPrice: 4.99),
      _FakeProduct(id: GraceWayProducts.annual, rawPrice: 39.99),
      _FakeProduct(id: GraceWayProducts.lifetime, rawPrice: 99.99),
    ];

Widget _wrapPaywallScreen(StoreProvider store, {VoidCallback? onNext}) {
  return MaterialApp(
    home: Scaffold(
      body: ChangeNotifierProvider<StoreProvider>.value(
        value: store,
        child: PaywallScreen(onNext: onNext ?? () {}),
      ),
    ),
  );
}

Widget _wrapPaywallView(StoreProvider store, {String? contextTitle}) {
  return MaterialApp(
    home: ChangeNotifierProvider<StoreProvider>.value(
      value: store,
      child: GraceWayPaywallView(contextTitle: contextTitle),
    ),
  );
}

/// Wraps [GraceWayPaywallView] pushed on top of a simple home so that
/// [Navigator.pop()] works, and the 1200ms auto-dismiss timer can fire cleanly.
Widget _wrapPaywallViewRouted(StoreProvider store) {
  return MaterialApp(
    home: ChangeNotifierProvider<StoreProvider>.value(
      value: store,
      child: Builder(builder: (ctx) {
        return ElevatedButton(
          onPressed: () => Navigator.push<void>(
            ctx,
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider<StoreProvider>.value(
                value: store,
                child: const GraceWayPaywallView(),
              ),
            ),
          ),
          child: const Text('Open'),
        );
      }),
    ),
  );
}

/// Advances fake time past [PaywallScreen]'s two [Future.delayed] timers
/// (200 ms + 500 ms), then lets every implicit animation run to completion.
///
/// Why two steps?
///   1. `pump(2 s)` fires both [Future.delayed] callbacks in fake-async order,
///      which call [setState] → [AnimationController.animateTo(1.0)].
///      The controller records its start time on the FIRST tick (not in
///      `start()`), so the first frame still sees opacity = 0.
///   2. `pumpAndSettle()` pumps 100 ms increments until settled, driving the
///      Ticker from elapsed = 0 → 500 ms so opacity reaches 1.0.
Future<void> _pumpPaywallScreen(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 2)); // fire timers
  await tester.pumpAndSettle(); // complete animations
}

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  // ── PaywallScreen ─────────────────────────────────────────────────────

  group('PaywallScreen', () {
    testWidgets('shows loading text when no products are loaded',
        (tester) async {
      final deps = await _buildTestStore(tester, products: []);

      await tester.pumpWidget(_wrapPaywallScreen(deps.store));
      await _pumpPaywallScreen(tester);

      expect(find.textContaining('Loading'), findsOneWidget);
      expect(find.text('Monthly'), findsNothing);
      expect(find.text('Yearly'), findsNothing);
    });

    testWidgets('shows Monthly, Yearly, Lifetime cards when all products loaded',
        (tester) async {
      final deps = await _buildTestStore(tester, products: _allProducts);

      await tester.pumpWidget(_wrapPaywallScreen(deps.store));
      await _pumpPaywallScreen(tester);

      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('Yearly'), findsOneWidget);
      expect(find.text('Lifetime'), findsOneWidget);
    });

    testWidgets('default CTA label is "Start Free Trial" (annual preselected)',
        (tester) async {
      final deps = await _buildTestStore(tester, products: _allProducts);

      await tester.pumpWidget(_wrapPaywallScreen(deps.store));
      await _pumpPaywallScreen(tester);

      expect(find.text('Start Free Trial'), findsOneWidget);
    });

    testWidgets('tapping Monthly card changes CTA to "Subscribe Monthly"',
        (tester) async {
      final deps = await _buildTestStore(tester, products: _allProducts);

      await tester.pumpWidget(_wrapPaywallScreen(deps.store));
      await _pumpPaywallScreen(tester);
      // Plan cards may be below the viewport — scroll them into view first.
      await tester.ensureVisible(find.text('Monthly'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Monthly'));
      await tester.pump();

      expect(find.text('Subscribe Monthly'), findsOneWidget);
    });

    testWidgets('tapping Lifetime card changes CTA to "Buy Lifetime Access"',
        (tester) async {
      final deps = await _buildTestStore(tester, products: _allProducts);

      await tester.pumpWidget(_wrapPaywallScreen(deps.store));
      await _pumpPaywallScreen(tester);
      await tester.ensureVisible(find.text('Lifetime'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lifetime'));
      await tester.pump();

      expect(find.text('Buy Lifetime Access'), findsOneWidget);
    });

    testWidgets('annual plan card shows "7-day free trial" text',
        (tester) async {
      final deps = await _buildTestStore(
        tester,
        products: [_FakeProduct(id: GraceWayProducts.annual, rawPrice: 39.99)],
      );

      await tester.pumpWidget(_wrapPaywallScreen(deps.store));
      await _pumpPaywallScreen(tester);

      expect(find.text('7-day free trial'), findsOneWidget);
    });

    testWidgets('CTA button is disabled and spinner shown while isPurchasing',
        (tester) async {
      final deps = await _buildTestStore(tester, products: _allProducts);
      deps.store.isPurchasing = true;

      await tester.pumpWidget(_wrapPaywallScreen(deps.store));
      // CircularProgressIndicator has an infinite animation — do NOT call
      // pumpAndSettle() here; advance just enough to fire initState timers.
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final buttons =
          tester.widgetList<ElevatedButton>(find.byType(ElevatedButton));
      expect(buttons.any((b) => b.onPressed == null), isTrue);
    });

    testWidgets('shows error text when store.error is set', (tester) async {
      final deps = await _buildTestStore(tester, products: _allProducts);
      deps.store.error = 'Something went wrong';

      await tester.pumpWidget(_wrapPaywallScreen(deps.store));
      await _pumpPaywallScreen(tester);

      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('"Continue with Free" button triggers onNext callback',
        (tester) async {
      final deps = await _buildTestStore(tester, products: _allProducts);
      var called = false;

      await tester.pumpWidget(
          _wrapPaywallScreen(deps.store, onNext: () => called = true));
      await _pumpPaywallScreen(tester);

      await tester.tap(find.text('Continue with Free'));
      await tester.pump();

      expect(called, true);
    });

    testWidgets(
        'tapping CTA calls store.purchase with annual product (default)',
        (tester) async {
      final deps = await _buildTestStore(tester, products: _allProducts);

      await tester.pumpWidget(_wrapPaywallScreen(deps.store));
      await _pumpPaywallScreen(tester);

      await tester.tap(find.text('Start Free Trial'));
      await tester.pump();

      final captured = verify(() => deps.mockIap.buyNonConsumable(
              purchaseParam: captureAny(named: 'purchaseParam')))
          .captured
          .single as PurchaseParam;
      expect(captured.productDetails.id, GraceWayProducts.annual);
    });

    testWidgets('tapping CTA when no products loaded calls onNext',
        (tester) async {
      final deps = await _buildTestStore(tester, products: []);
      var called = false;

      await tester.pumpWidget(
          _wrapPaywallScreen(deps.store, onNext: () => called = true));
      await _pumpPaywallScreen(tester);

      await tester.tap(find.text('Start Free Trial'));
      await tester.pump();

      expect(called, true);
    });
  });

  // ── GraceWayPaywallView ────────────────────────────────────────────────

  group('GraceWayPaywallView', () {
    testWidgets('shows loading text when no products are loaded',
        (tester) async {
      final deps = await _buildTestStore(tester, products: []);

      await tester.pumpWidget(_wrapPaywallView(deps.store));
      await tester.pump();

      expect(find.textContaining('Loading'), findsOneWidget);
    });

    testWidgets(
        'shows Monthly, Yearly, Lifetime cards when all products loaded',
        (tester) async {
      final deps = await _buildTestStore(tester, products: _allProducts);

      await tester.pumpWidget(_wrapPaywallView(deps.store));
      await tester.pump();

      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('Yearly'), findsOneWidget);
      expect(find.text('Lifetime'), findsOneWidget);
    });

    testWidgets('default CTA is "Continue" (annual preselected)',
        (tester) async {
      final deps = await _buildTestStore(tester, products: _allProducts);

      await tester.pumpWidget(_wrapPaywallView(deps.store));
      await tester.pump();

      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('selecting Monthly changes CTA to "Subscribe Monthly"',
        (tester) async {
      final deps = await _buildTestStore(tester, products: _allProducts);

      await tester.pumpWidget(_wrapPaywallView(deps.store));
      await tester.pump();

      await tester.tap(find.text('Monthly'));
      await tester.pump();

      expect(find.text('Subscribe Monthly'), findsOneWidget);
    });

    testWidgets('selecting Lifetime changes CTA to "Buy Lifetime Access"',
        (tester) async {
      final deps = await _buildTestStore(tester, products: _allProducts);

      await tester.pumpWidget(_wrapPaywallView(deps.store));
      await tester.pump();

      await tester.tap(find.text('Lifetime'));
      await tester.pump();

      expect(find.text('Buy Lifetime Access'), findsOneWidget);
    });

    testWidgets('shows context section when contextTitle is provided',
        (tester) async {
      final deps = await _buildTestStore(tester);

      await tester.pumpWidget(
          _wrapPaywallView(deps.store, contextTitle: 'Unlock SOS'));
      await tester.pump();

      expect(find.text('Unlock SOS'), findsOneWidget);
    });

    testWidgets('shows success state when isPremium transitions to true',
        (tester) async {
      // Use a routed wrapper so the auto-dismiss nav.pop() works cleanly.
      final deps = await _buildTestStore(tester);

      await tester.pumpWidget(_wrapPaywallViewRouted(deps.store));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome to GraceWay Pro'), findsNothing);

      deps.store.isPremium = true;
      deps.store.notifyListeners();
      await tester.pump(); // Trigger rebuild — _purchaseSuccess becomes true.

      expect(find.text('Welcome to GraceWay Pro'), findsOneWidget);

      // Drain the 1200 ms auto-dismiss timer so the test ends cleanly.
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();
    });

    testWidgets('shows error text when store.error is set', (tester) async {
      final deps = await _buildTestStore(tester, products: _allProducts);
      deps.store.error = 'Receipt validation failed';

      await tester.pumpWidget(_wrapPaywallView(deps.store));
      await tester.pump();

      expect(find.text('Receipt validation failed'), findsOneWidget);
    });

    testWidgets(
        'tapping CTA calls store.purchase with annual product (default)',
        (tester) async {
      final deps = await _buildTestStore(tester, products: _allProducts);

      await tester.pumpWidget(_wrapPaywallView(deps.store));
      await tester.pump();

      await tester.tap(find.text('Continue'));
      await tester.pump();

      final captured = verify(() => deps.mockIap.buyNonConsumable(
              purchaseParam: captureAny(named: 'purchaseParam')))
          .captured
          .single as PurchaseParam;
      expect(captured.productDetails.id, GraceWayProducts.annual);
    });

    testWidgets('"Not now" button pops the navigator', (tester) async {
      final deps = await _buildTestStore(tester);
      var popped = false;

      await tester.pumpWidget(_wrapPaywallViewRouted(deps.store));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Override the button so we can detect the pop.
      // Simply detect that after tapping "Not now" we're back at the home screen.
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      // After pop the home "Open" button is visible again.
      expect(find.text('Open'), findsOneWidget);
      popped = true;
      expect(popped, true);
    });
  });
}
