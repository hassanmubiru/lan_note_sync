// lib/providers/purchase_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/purchase/purchase_service.dart';

class PurchaseNotifier extends StateNotifier<PurchaseStatus> {
  PurchaseNotifier() : super(PurchaseService.status);

  Future<bool> purchase(String productId) async {
    final success = await PurchaseService.purchase(productId);
    state = PurchaseService.status;
    return success;
  }

  Future<bool> restorePurchases() async {
    final ok = await PurchaseService.restorePurchases();
    state = PurchaseService.status;
    return ok;
  }

  void refresh() {
    state = PurchaseService.status;
  }
}

final purchaseProvider = StateNotifierProvider<PurchaseNotifier, PurchaseStatus>(
  (ref) => PurchaseNotifier(),
);
