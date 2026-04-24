import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/datasources/remote/auth_service.dart';
import '../../domain/repositories/iap_repository.dart';

/// Product IDs — must match Google Play Console / App Store Connect exactly.
class GraceWayProducts {
  static const monthly = 'monthlysub';
  static const annual = 'annualsub';
  static const lifetime = 'lifetimeonetime';
  static const all = {monthly, annual, lifetime};
}

/// Presentation-layer ChangeNotifier that owns the in-app purchase flow.
///
/// Clean Architecture: this class depends on [IAPRepository] (domain interface)
/// for all Firestore / server-validation calls. The [InAppPurchase] store API
/// and [FirebaseAuth] (for obfuscated account ID) are injected for testability.
///
/// Race-condition safety:
///   - [init] is idempotent: guarded by [_initialized].
///   - [purchase] is idempotent while a purchase is in flight: guarded by
///     [isPurchasing].
///   - [_onPurchaseUpdates] runs sequentially on the purchase stream — no
///     concurrent handler invocations are possible from a single stream.
///   - [_syncPremiumStatus] is a pure read and is safe to call concurrently;
///     the last writer wins, which is correct since all calls read the same
///     Firestore document.
class StoreProvider extends ChangeNotifier with WidgetsBindingObserver {
  final IAPRepository _iapRepository;
  final InAppPurchase _iap;
  final FirebaseAuth _auth;

  static const _kIsPremiumKey = 'store_is_premium';

  StoreProvider({
    required IAPRepository iapRepository,
    required SharedPreferences prefs,
    InAppPurchase? iap,
    FirebaseAuth? auth,
  })  : _iapRepository = iapRepository,
        _prefs = prefs,
        _iap = iap ?? InAppPurchase.instance,
        _auth = auth ?? FirebaseAuth.instance,
        // Seed from cache so premium users see no upsell banner on launch.
        isPremium = prefs.getBool(_kIsPremiumKey) ?? false {
    AuthService.shared.addListener(_onAuthChanged);
  }

  final SharedPreferences _prefs;
  bool _initialized = false;
  Map<String, ProductDetails> _products = {};
  bool isPremium;
  bool isLoading = false;
  bool isPurchasing = false;
  String? error;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  StreamSubscription<bool>? _premiumSub;

  // ── Getters ───────────────────────────────────────────────────────────────

  ProductDetails? get monthlyProduct => _products[GraceWayProducts.monthly];
  ProductDetails? get annualProduct => _products[GraceWayProducts.annual];
  ProductDetails? get lifetimeProduct => _products[GraceWayProducts.lifetime];

  /// Returns e.g. "Save 33%" when annual is cheaper than 12× monthly.
  /// Returns null when either product is unavailable or there is no savings.
  String? get monthlySavingsText {
    final monthly = monthlyProduct;
    final annual = annualProduct;
    if (monthly == null || annual == null) return null;
    final monthlyAnnualised = monthly.rawPrice * 12;
    if (monthlyAnnualised <= annual.rawPrice) return null;
    final savings =
        ((monthlyAnnualised - annual.rawPrice) / monthlyAnnualised * 100)
            .round();
    return 'Save $savings%';
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Initialises the store. Safe to call multiple times — only runs once.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    WidgetsBinding.instance.addObserver(this);
    isLoading = true;
    notifyListeners();

    final available = await _iap.isAvailable();
    if (!available) {
      isLoading = false;
      notifyListeners();
      return;
    }

    _purchaseSub = _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (Object e) {
        error = e.toString();
        notifyListeners();
      },
    );

    await Future.wait([
      _loadProducts(),
      _syncPremiumStatus(),
    ]);

    // Start real-time listener so any server-side document writes (e.g. the
    // grantTestPremium onCreate function) update isPremium without requiring
    // a background/foreground cycle.
    _premiumSub = _iapRepository.watchPremiumStatus().listen((status) {
      if (isPremium != status) {
        _setPremium(status);
        notifyListeners();
      }
    });

    isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    AuthService.shared.removeListener(_onAuthChanged);
    WidgetsBinding.instance.removeObserver(this);
    _purchaseSub?.cancel();
    _premiumSub?.cancel();
    super.dispose();
  }

  void _onAuthChanged() {
    if (AuthService.shared.isAuthenticated) {
      // Re-sync and restart the real-time listener with the new UID.
      _premiumSub?.cancel();
      _syncPremiumStatus().then((_) => notifyListeners());
      _premiumSub = _iapRepository.watchPremiumStatus().listen((status) {
        if (isPremium != status) {
          _setPremium(status);
          notifyListeners();
        }
      });
    } else {
      // Signed out — cancel stream but do NOT write false to cache.
      // The cache should retain the last known premium state so it's
      // still valid on the next sign-in before Firestore responds.
      _premiumSub?.cancel();
      _premiumSub = null;
      isPremium = false;
      notifyListeners();
    }
  }

  /// Re-syncs premium status from Firestore whenever the app returns to the
  /// foreground — catches subscription lapses that occurred while backgrounded.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncPremiumStatus().then((_) => notifyListeners());
    }
  }

  // ── Products ──────────────────────────────────────────────────────────────

  Future<void> _loadProducts() async {
    try {
      final response = await _iap.queryProductDetails(GraceWayProducts.all);
      _products = {for (final p in response.productDetails) p.id: p};
    } catch (e) {
      error = e.toString();
    }
  }

  // ── Premium status ────────────────────────────────────────────────────────

  /// Sets [isPremium] and persists it to SharedPreferences so the next launch
  /// can seed the value synchronously and avoid a flash of the upsell banner.
  void _setPremium(bool value) {
    isPremium = value;
    _prefs.setBool(_kIsPremiumKey, value);
  }

  /// Reads premium status from Firestore (authoritative source after server
  /// validation). A null return from the repository means a transient error —
  /// we leave [isPremium] unchanged to remain optimistic for existing users.
  Future<void> _syncPremiumStatus() async {
    final status = await _iapRepository.getPremiumStatus();
    if (status != null) {
      _setPremium(status);
    }
  }

  // ── Purchase flow ─────────────────────────────────────────────────────────

  /// Initiates a purchase. No-ops if a purchase is already in flight.
  ///
  /// Google Play recommends passing a one-way hash of the Firebase UID as
  /// [applicationUserName] to link purchases to accounts for fraud detection.
  Future<void> purchase(ProductDetails product) async {
    if (isPurchasing) return; // Race-condition guard.
    isPurchasing = true;
    error = null;
    notifyListeners();

    try {
      final uid = _auth.currentUser?.uid;
      final param = PurchaseParam(
        productDetails: product,
        applicationUserName: uid != null
            ? sha256.convert(utf8.encode(uid)).toString()
            : null,
      );
      final launched = await _iap.buyNonConsumable(purchaseParam: param);
      if (!launched) {
        // Store refused to start the purchase (e.g. another purchase is already
        // pending). Clear the flag so the user can try again.
        error = 'Could not start purchase. Please try again.';
        isPurchasing = false;
        notifyListeners();
      }
      // On success, delivery and validation happen in _onPurchaseUpdates.
    } catch (e) {
      error = e.toString();
      isPurchasing = false;
      notifyListeners();
    }
  }

  Future<void> restore() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _iap.restorePurchases();
      // Delivery/verification happens in _onPurchaseUpdates.
    } catch (e) {
      error = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  // ── Purchase stream handler ───────────────────────────────────────────────

  /// Handles purchase updates emitted by the store.
  ///
  /// The stream delivers a list; we process each update sequentially so that
  /// completePurchase + validateReceipt are always atomic per purchase event.
  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    // ignore: avoid_print
    print('[StoreProvider] purchaseStream: ${purchases.length} events: '
        '${purchases.map((p) => '${p.productID}/${p.status}').join(', ')}');
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          // No state change — UI already shows the spinner via isPurchasing.
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          try {
            // Acknowledge the transaction on the store side before validating.
            // On Android this must happen within 3 days or Google auto-refunds.
            if (purchase.pendingCompletePurchase) {
              await _iap.completePurchase(purchase);
            }
            await _validateWithServer(purchase);
          } catch (e) {
            error = e.toString();
          } finally {
            // Always clear the purchasing flag and notify, even if
            // completePurchase throws — prevents a stuck spinner.
            isPurchasing = false;
            notifyListeners();
          }

        case PurchaseStatus.error:
          // Ignore user-cancellation; only surface genuine errors.
          if (!_isCancelledError(purchase.error)) {
            error = purchase.error?.message ?? 'Purchase failed';
          }
          isPurchasing = false;
          notifyListeners();

        case PurchaseStatus.canceled:
          isPurchasing = false;
          notifyListeners();
      }
    }
  }

  bool _isCancelledError(IAPError? err) {
    if (err == null) return false;
    final msg = err.message.toLowerCase();
    // iOS cancel: SKErrorPaymentCancelled (code 2)
    // Android cancel: BillingResponse.userCanceled
    return msg.contains('cancel') ||
        err.code == 'BillingResponse.userCanceled' ||
        err.code == '2';
  }

  // ── Server validation ─────────────────────────────────────────────────────

  /// Derives the platform from the purchase's verification data source rather
  /// than dart:io's Platform — making this deterministic in tests regardless
  /// of the host OS.
  Future<void> _validateWithServer(PurchaseDetails purchase) async {
    final isIos = purchase.verificationData.source == 'app_store';
    try {
      final validated = await _iapRepository.validateReceipt(
        platform: isIos ? 'ios' : 'android',
        productId: purchase.productID,
        purchaseToken: !isIos
            ? purchase.verificationData.serverVerificationData
            : null,
        receiptData: isIos
            ? purchase.verificationData.localVerificationData
            : null,
      );
      _setPremium(validated);
    } catch (e) {
      error = 'Receipt validation failed: ${e.toString()}';
    }
  }
}
