import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'premium_service.dart';

class IAPService extends ChangeNotifier {
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  final PremiumService _premiumService = PremiumService();

  // Product IDs - must match Google Play Console
  static const String kMonthlySubscriptionId = 'premium_monthly';
  static const String kYearlySubscriptionId = 'premium_yearly'; // Optional

  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  bool _isLoading = false;
  String? _purchaseError;

  bool get isAvailable => _isAvailable;
  List<ProductDetails> get products => _products;
  bool get isLoading => _isLoading;
  String? get purchaseError => _purchaseError;

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  Future<void> initialize() async {
    try {
      _isAvailable = await _iap.isAvailable();
    } catch (e) {
      debugPrint("IAP Service: Store connection failed: $e");
      _isAvailable = false;
    }

    if (!_isAvailable) {
      debugPrint("IAP Service: Store not available");
      return;
    }

    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (error) {
        debugPrint("IAP Service: Error in stream: $error");
      },
    );

    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final Set<String> _kIds = {kMonthlySubscriptionId};
      
      final ProductDetailsResponse response = await _iap.queryProductDetails(_kIds);
      
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint("IAP Service: Products not found: ${response.notFoundIDs}");
        // We still continue to show what we found
      }
      
      _products = response.productDetails;
      debugPrint("IAP Service: Loaded ${_products.length} products");
    } catch (e) {
      debugPrint("IAP Service: Error loading products: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> buyProduct(ProductDetails product) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    
    // For subs, we might need specific logic, but general flow is same
    // autoConsume is false by default for subs, true for consumables. 
    // We are doing subs, so false is correct (InAppPurchase handles this).
    
    try {
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      _purchaseError = "Failed to start purchase: $e";
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      _purchaseError = "Failed to restore: $e";
      notifyListeners();
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show pending UI if needed
        debugPrint("IAP Service: Purchase pending...");
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          _purchaseError = purchaseDetails.error?.message ?? "Unknown error";
          debugPrint("IAP Service: Purchase error: $_purchaseError");
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          
          debugPrint("IAP Service: Purchase successful/restored!");
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
    // In a real app, verify receipt with backend here.
    // For this implementation, we trust the local success (simulated backend verification).
    
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
