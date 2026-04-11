import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

import 'premium_service.dart';

/// In-app purchases via Google Play (Android) and StoreKit (iOS/macOS) using
/// the same product IDs on both stores.
///
/// **App Store Connect:** Create auto-renewable subscriptions whose product IDs
/// match [kMonthlySubscriptionId] / [kYearlySubscriptionId]. Add the **In-App
/// Purchase** capability to the Runner target in Xcode. Complete Paid Apps
/// agreements, tax, and banking in App Store Connect or products stay hidden.
class IAPService extends ChangeNotifier {
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  final PremiumService _premiumService = PremiumService();

  /// Product IDs — must match Google Play Console and App Store Connect exactly.
  static const String kMonthlySubscriptionId = 'premium_monthly';
  static const String kYearlySubscriptionId = 'premium_yearly';

  static final Set<String> kAllSubscriptionIds = {
    kMonthlySubscriptionId,
    kYearlySubscriptionId,
  };

  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  bool _isLoading = false;
  String? _purchaseError;
  bool _initialized = false;
  Future<void>? _initFuture;

  bool get isAvailable => _isAvailable;
  List<ProductDetails> get products => _products;
  bool get isLoading => _isLoading;
  String? get purchaseError => _purchaseError;

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// Obfuscated app-account id for StoreKit / Play (recommended for restore consistency).
  String? get _applicationUserName =>
      FirebaseAuth.instance.currentUser?.uid;

  Future<void> initialize() async {
    if (_initialized) return;
    if (_initFuture != null) {
      await _initFuture;
      return;
    }
    _initFuture = _initializeInner();
    await _initFuture;
  }

  Future<void> _initializeInner() async {
    try {
      try {
        _isAvailable = await _iap.isAvailable();
      } catch (e) {
        debugPrint('IAP Service: Store connection failed: $e');
        _isAvailable = false;
      }

      if (!_isAvailable) {
        debugPrint('IAP Service: Store not available');
        return;
      }

      final purchaseUpdated = _iap.purchaseStream;
      _subscription ??= purchaseUpdated.listen(
        _onPurchaseUpdate,
        onDone: () => _subscription?.cancel(),
        onError: (Object error) {
          debugPrint('IAP Service: Error in stream: $error');
        },
      );

      await _loadProducts();

      if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
        await _syncStoreKitWithAppStore();
      }
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  /// StoreKit 2: sync local transaction state with the App Store (subscriptions).
  Future<void> _syncStoreKitWithAppStore() async {
    try {
      final InAppPurchaseStoreKitPlatformAddition iosAddition =
          _iap.getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      await iosAddition.sync();
    } catch (e) {
      debugPrint('IAP Service: StoreKit sync skipped: $e');
    }
  }

  Future<void> _loadProducts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final ProductDetailsResponse response =
          await _iap.queryProductDetails(kAllSubscriptionIds);

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('IAP Service: Products not found: ${response.notFoundIDs}');
      }

      _products = response.productDetails;
      debugPrint('IAP Service: Loaded ${_products.length} products');
    } catch (e) {
      debugPrint('IAP Service: Error loading products: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> buyProduct(ProductDetails product) async {
    _purchaseError = null;
    notifyListeners();

    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: product,
      applicationUserName: _applicationUserName,
    );

    try {
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      _purchaseError = 'Failed to start purchase: $e';
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    _purchaseError = null;
    notifyListeners();

    try {
      await _iap.restorePurchases(
        applicationUserName: _applicationUserName,
      );
    } catch (e) {
      _purchaseError = 'Failed to restore: $e';
      notifyListeners();
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        debugPrint('IAP Service: Purchase pending...');
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          _purchaseError =
              purchaseDetails.error?.message ?? 'Unknown error';
          debugPrint('IAP Service: Purchase error: $_purchaseError');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          debugPrint('IAP Service: Purchase successful/restored!');
          await _verifyAndDeliverProduct(purchaseDetails);
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
    notifyListeners();
  }

  Future<void> _verifyAndDeliverProduct(PurchaseDetails purchaseDetails) async {
    // Production apps should verify receipts server-side (Play Developer API / App Store Server API).
    if (purchaseDetails.productID == kMonthlySubscriptionId ||
        purchaseDetails.productID == kYearlySubscriptionId) {
      await _premiumService.setPremium(true);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
