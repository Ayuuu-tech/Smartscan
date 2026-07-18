import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:smartscan/core/services/auth_service.dart';

/// Google Play Billing / App Store subscriptions for SmartScan Pro.
///
/// Product ids — create these in Play Console → Monetize → Subscriptions
/// (and App Store Connect for iOS) with the prices you chose:
///   smartscan_pro_monthly  → ₹25 / month
///   smartscan_pro_yearly   → ₹139 / year
///
/// Store policy note: on Play/App Store builds, digital-feature
/// subscriptions MUST go through the store's billing — Razorpay autopay is
/// only permitted for distribution outside the stores (e.g. website APK).
class PurchaseService {
  PurchaseService._();

  static const monthlyId = 'smartscan_pro_monthly';
  static const yearlyId = 'smartscan_pro_yearly';
  static const productIds = {monthlyId, yearlyId};

  /// Accounts granted lifetime Pro for free (test / comp access).
  /// Compared case-insensitively against the signed-in email.
  static const lifetimeProEmails = {
    'ayushmaan.ggn@gmail.com',
  };
}

/// Pro entitlement + available subscription products.
class ProState {
  final bool isPro;

  /// Store not reachable / products not configured yet.
  final bool storeAvailable;
  final List<ProductDetails> products;

  const ProState({
    this.isPro = false,
    this.storeAvailable = false,
    this.products = const [],
  });

  ProState copyWith({
    bool? isPro,
    bool? storeAvailable,
    List<ProductDetails>? products,
  }) =>
      ProState(
        isPro: isPro ?? this.isPro,
        storeAvailable: storeAvailable ?? this.storeAvailable,
        products: products ?? this.products,
      );
}

class ProNotifier extends AsyncNotifier<ProState> {
  static const _entitlementKey = 'pro_entitlement_v1';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  StreamSubscription<List<PurchaseDetails>>? _sub;

  @override
  Future<ProState> build() async {
    // Rebuild on login/logout so comp-account Pro is re-evaluated.
    ref.watch(authStateProvider);

    // Cached entitlement first, so Pro works offline.
    bool isPro = false;
    try {
      isPro = await _storage.read(key: _entitlementKey) == 'true';
    } catch (_) {}

    // Comp accounts (test emails) always get Pro, regardless of billing.
    try {
      final email = FirebaseAuth.instance.currentUser?.email?.toLowerCase();
      if (email != null &&
          PurchaseService.lifetimeProEmails.contains(email)) {
        isPro = true;
      }
    } catch (_) {}

    final iap = InAppPurchase.instance;
    bool available = false;
    List<ProductDetails> products = const [];
    try {
      available = await iap.isAvailable();
      if (available) {
        _sub?.cancel();
        _sub = iap.purchaseStream.listen(_onPurchases);
        ref.onDispose(() => _sub?.cancel());

        final response =
            await iap.queryProductDetails(PurchaseService.productIds);
        products = response.productDetails
          ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
        // Store says nothing is configured yet → treat as unavailable so
        // the UI shows "coming soon" instead of empty buttons.
        if (products.isEmpty) available = false;

        // Re-check active subscriptions (auto-renewal state).
        await iap.restorePurchases();
      }
    } catch (e) {
      debugPrint('Billing init failed: $e');
      available = false;
    }

    return ProState(
        isPro: isPro, storeAvailable: available, products: products);
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    var current = state.value ?? const ProState();
    for (final p in purchases) {
      final isProProduct = PurchaseService.productIds.contains(p.productID);
      if (!isProProduct) continue;

      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          current = current.copyWith(isPro: true);
          await _storage.write(key: _entitlementKey, value: 'true');
        case PurchaseStatus.error:
          debugPrint('Purchase error: ${p.error}');
        case PurchaseStatus.canceled:
        case PurchaseStatus.pending:
          break;
      }
      if (p.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(p);
      }
    }
    state = AsyncData(current);
  }

  /// Launches the store's subscription purchase sheet.
  /// Returns an error message, or null when the flow started.
  Future<String?> buy(ProductDetails product) async {
    try {
      final ok = await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      return ok ? null : 'Could not start the purchase';
    } catch (e) {
      return 'Purchase failed: $e';
    }
  }

  /// "Already subscribed on another phone" → re-sync from the store.
  Future<void> restore() async {
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      debugPrint('Restore failed: $e');
    }
  }
}

final proProvider =
    AsyncNotifierProvider<ProNotifier, ProState>(ProNotifier.new);
