import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../analytics/analytics_service.dart';

/// Real-money, non-consumable products. These ids must match the products
/// created in Play Console / App Store Connect exactly, or the store reports
/// them as "not found" and the shop shows them as unavailable.
class ProductIds {
  static const removeAds = 'remove_ads';
  static const unlockAllLevels = 'unlock_all_levels';
  static const all = {removeAds, unlockAllLevels};
}

/// Talks to Google Play Billing / StoreKit: loads products, buys, restores,
/// and keeps the owned products (entitlements) persisted on device.
///
/// Entitlements are granted on the store's client-side confirmation; there is
/// no server receipt validation.
class PurchaseService extends ChangeNotifier {
  static final PurchaseService instance = PurchaseService._();

  PurchaseService._();

  static const _ownedKey = 'iap_owned_products';

  final Set<String> _owned = {};
  final Map<String, ProductDetails> _products = {};
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _storeAvailable = false;

  bool get storeAvailable => _storeAvailable;
  bool get adsRemoved => _owned.contains(ProductIds.removeAds);
  bool get allLevelsUnlocked => _owned.contains(ProductIds.unlockAllLevels);
  bool owns(String productId) => _owned.contains(productId);
  ProductDetails? product(String productId) => _products[productId];

  /// Reads saved entitlements synchronously so "Remove ads" gates ads from the
  /// very first ad request. Needs `GetStorage.init()` to have completed.
  void loadEntitlements() {
    try {
      final saved = GetStorage().read<List<dynamic>>(_ownedKey);
      if (saved != null) _owned.addAll(saved.whereType<String>());
      debugPrint('PurchaseService: Owned products: $_owned');
    } catch (e) {
      debugPrint('PurchaseService: Failed to load entitlements: $e');
    }
  }

  /// Connects to the store. Not awaited at startup — product queries need the
  /// network and must not hold up the first frame.
  Future<void> init() async {
    if (_subscription != null) return;
    try {
      final iap = InAppPurchase.instance;
      // Listen before anything else so purchases finished while the app was
      // closed (pending payments) are delivered and completed.
      _subscription = iap.purchaseStream.listen(
        _onPurchaseUpdates,
        onError: (Object e) => debugPrint('PurchaseService: Purchase stream error: $e'),
      );
      _storeAvailable = await iap.isAvailable();
      if (!_storeAvailable) {
        debugPrint('PurchaseService: Store not available on this device.');
        notifyListeners();
        return;
      }
      await _queryProducts(ProductIds.all);
      // Re-sync owned products after a reinstall. Android restores silently;
      // on iOS a restore can prompt for the Apple ID, so there it is only done
      // from the user's "Restore purchases" tap.
      if (defaultTargetPlatform == TargetPlatform.android) {
        await iap.restorePurchases();
      }
    } catch (e) {
      debugPrint('PurchaseService: Failed to initialize: $e');
    }
  }

  Future<void> _queryProducts(Set<String> ids) async {
    final response = await InAppPurchase.instance.queryProductDetails(ids);
    for (final p in response.productDetails) {
      _products[p.id] = p;
    }
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('PurchaseService: Products not found in the store: ${response.notFoundIDs}');
    }
    if (response.error != null) {
      debugPrint('PurchaseService: Product query error: ${response.error}');
    }
    debugPrint('PurchaseService: Loaded products: ${_products.keys}');
    notifyListeners();
  }

  /// Opens the store's purchase sheet. The result arrives later on the
  /// purchase stream; returns false if the sheet could not be opened.
  Future<bool> buy(String productId) async {
    final product = _products[productId];
    if (!_storeAvailable || product == null) {
      AnalyticsService.instance.logPurchaseFailed(productId, 'unavailable');
      return false;
    }
    AnalyticsService.instance.logBeginCheckout(
      productId: productId,
      value: product.rawPrice,
      currency: product.currencyCode,
    );
    try {
      return await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (e) {
      AnalyticsService.instance.logPurchaseFailed(productId, e.toString());
      return false;
    }
  }

  /// Re-delivers every owned non-consumable as a `restored` update.
  Future<bool> restore() async {
    if (!_storeAvailable) return false;
    try {
      await InAppPurchase.instance.restorePurchases();
      return true;
    } catch (e) {
      debugPrint('PurchaseService: Restore failed: $e');
      return false;
    }
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      final id = purchase.productID;
      try {
        switch (purchase.status) {
          case PurchaseStatus.pending:
            debugPrint('PurchaseService: $id pending');
          case PurchaseStatus.purchased:
            await _grant(id);
            // A purchase can land before the startup product query returns.
            if (!_products.containsKey(id)) await _queryProducts({id});
            final product = _products[id];
            if (product != null) {
              AnalyticsService.instance.logPurchase(
                productId: id,
                productName: product.title,
                value: product.rawPrice,
                currency: product.currencyCode,
                transactionId: purchase.purchaseID,
              );
            } else {
              AnalyticsService.instance.logPurchaseFailed(id, 'purchased_without_price');
            }
          case PurchaseStatus.restored:
            final isNew = !_owned.contains(id);
            await _grant(id);
            if (isNew) AnalyticsService.instance.logPurchaseRestored(id);
          case PurchaseStatus.error:
            AnalyticsService.instance.logPurchaseFailed(id, purchase.error?.message ?? 'error');
          case PurchaseStatus.canceled:
            AnalyticsService.instance.logPurchaseFailed(id, 'canceled');
        }
      } catch (e) {
        debugPrint('PurchaseService: Failed handling $id: $e');
      }
      // Unacknowledged Play purchases are refunded after 3 days.
      if (purchase.pendingCompletePurchase) {
        try {
          await InAppPurchase.instance.completePurchase(purchase);
        } catch (e) {
          debugPrint('PurchaseService: completePurchase failed for $id: $e');
        }
      }
    }
  }

  Future<void> _grant(String productId) async {
    if (!_owned.add(productId)) return;
    debugPrint('PurchaseService: Granted $productId');
    notifyListeners();
    try {
      await GetStorage().write(_ownedKey, _owned.toList());
    } catch (e) {
      debugPrint('PurchaseService: Failed to save entitlements: $e');
    }
  }
}
