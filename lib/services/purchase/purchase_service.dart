// lib/services/purchase/purchase_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../core/constants.dart';
import '../../services/storage/hive_service.dart';

enum PurchaseTier { free, pro, voice, ar, enterprise }

class PurchaseStatus {
  final PurchaseTier tier;
  final bool isProPeers;
  final bool isVoice;
  final bool isAR;
  final bool isEnterprise;

  const PurchaseStatus({
    this.tier = PurchaseTier.free,
    this.isProPeers = false,
    this.isVoice = false,
    this.isAR = false,
    this.isEnterprise = false,
  });

  int get maxPeers => isEnterprise ? 500 : isProPeers ? 999 : AppConstants.freePeerLimit;

  bool get canUseVoice => isVoice || isEnterprise;
  bool get canUseAR => isAR || isEnterprise;
  bool get canUseNFC => isEnterprise;

  static const PurchaseStatus free = PurchaseStatus();
  static const PurchaseStatus fullAccess = PurchaseStatus(
    tier: PurchaseTier.enterprise,
    isProPeers: true,
    isVoice: true,
    isAR: true,
    isEnterprise: true,
  );
}

class PurchaseService {
  static PurchaseStatus _status = const PurchaseStatus();
  static bool _initialized = false;

  static PurchaseStatus get status => _status;

  static Future<void> initialize() async {
    if (_initialized) return;

    // During development / when no RevenueCat key → grant full access
    final key = AppConstants.revenueCatKey;
    if (key == 'YOUR_REVENUECAT_KEY') {
      debugPrint('[IAP] Dev mode — full access granted');
      _status = PurchaseStatus.fullAccess;
      _initialized = true;
      return;
    }

    try {
      await Purchases.setLogLevel(LogLevel.error);
      final config = PurchasesConfiguration(key);
      await Purchases.configure(config);

      final customerInfo = await Purchases.getCustomerInfo();
      _status = _buildStatus(customerInfo);
      _initialized = true;

      debugPrint('[IAP] Initialized. Tier: ${_status.tier}');
    } catch (e) {
      debugPrint('[IAP] Init failed (offline?): $e');
      // Restore from local cache
      _status = _loadCachedStatus();
      _initialized = true;
    }
  }

  static PurchaseStatus _buildStatus(CustomerInfo info) {
    final entitlements = info.entitlements.active;
    return PurchaseStatus(
      isProPeers: entitlements.containsKey(AppConstants.iapProPeers) || entitlements.containsKey(AppConstants.iapEnterprise),
      isVoice: entitlements.containsKey(AppConstants.iapVoice) || entitlements.containsKey(AppConstants.iapEnterprise),
      isAR: entitlements.containsKey(AppConstants.iapAR) || entitlements.containsKey(AppConstants.iapEnterprise),
      isEnterprise: entitlements.containsKey(AppConstants.iapEnterprise),
      tier: _determineTier(entitlements),
    );
  }

  static PurchaseTier _determineTier(Map<String, EntitlementInfo> e) {
    if (e.containsKey(AppConstants.iapEnterprise)) return PurchaseTier.enterprise;
    if (e.containsKey(AppConstants.iapAR)) return PurchaseTier.ar;
    if (e.containsKey(AppConstants.iapVoice)) return PurchaseTier.voice;
    if (e.containsKey(AppConstants.iapProPeers)) return PurchaseTier.pro;
    return PurchaseTier.free;
  }

  static PurchaseStatus _loadCachedStatus() {
    final tier = HiveService.getSetting<String>('iap_tier') ?? 'free';
    switch (tier) {
      case 'enterprise': return PurchaseStatus.fullAccess;
      case 'ar': return const PurchaseStatus(isProPeers: true, isVoice: true, isAR: true, tier: PurchaseTier.ar);
      case 'voice': return const PurchaseStatus(isProPeers: true, isVoice: true, tier: PurchaseTier.voice);
      case 'pro': return const PurchaseStatus(isProPeers: true, tier: PurchaseTier.pro);
      default: return const PurchaseStatus();
    }
  }

  static Future<List<StoreProduct>> getProducts() async {
    if (AppConstants.revenueCatKey == 'YOUR_REVENUECAT_KEY') return [];
    try {
      return await Purchases.getProducts([
        AppConstants.iapProPeers,
        AppConstants.iapVoice,
        AppConstants.iapAR,
        AppConstants.iapEnterprise,
      ]);
    } catch (e) {
      debugPrint('[IAP] getProducts failed: $e');
      return [];
    }
  }

  static Future<bool> purchase(String productId) async {
    if (AppConstants.revenueCatKey == 'YOUR_REVENUECAT_KEY') {
      // Dev: simulate purchase
      _status = PurchaseStatus.fullAccess;
      return true;
    }

    try {
      final products = await Purchases.getProducts([productId]);
      if (products.isEmpty) return false;

      final customerInfo = await Purchases.purchaseStoreProduct(products.first);
      _status = _buildStatus(customerInfo);
      await HiveService.setSetting('iap_tier', _status.tier.name);
      return true;
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) return false;
      debugPrint('[IAP] Purchase error: $e');
      return false;
    } catch (e) {
      debugPrint('[IAP] Purchase failed: $e');
      return false;
    }
  }

  static Future<bool> restorePurchases() async {
    if (AppConstants.revenueCatKey == 'YOUR_REVENUECAT_KEY') {
      _status = PurchaseStatus.fullAccess;
      return true;
    }
    try {
      final customerInfo = await Purchases.restorePurchases();
      _status = _buildStatus(customerInfo);
      return true;
    } catch (e) {
      debugPrint('[IAP] Restore failed: $e');
      return false;
    }
  }
}
