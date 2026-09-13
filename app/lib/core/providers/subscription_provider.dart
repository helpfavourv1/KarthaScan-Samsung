import 'dart:async' show unawaited;
import 'package:flutter/foundation.dart' show ValueNotifier;
import '../../platform/iap_service.dart';
import 'settings_provider.dart';

enum PurchaseFlowState { idle, inProgress, success, error, cancelled }

class SubscriptionProvider {
  SubscriptionProvider(this._iapService, this._settingsProvider) {
    adsRemoved = ValueNotifier<bool>(_settingsProvider.settings.value.adsRemoved);
    unawaited(_initialize());
  }

  final IapService _iapService;
  final SettingsProvider _settingsProvider;
  late final ValueNotifier<bool> adsRemoved;
  final ValueNotifier<List<SamsungProduct>> products = ValueNotifier<List<SamsungProduct>>(const <SamsungProduct>[]);
  final ValueNotifier<PurchaseFlowState> purchaseFlowState = ValueNotifier<PurchaseFlowState>(PurchaseFlowState.idle);
  final ValueNotifier<String?> lastError = ValueNotifier<String?>(null);

  Future<void> _initialize() async {
    final bool available = await _iapService.initialize(onPurchaseUpdate: _handlePurchaseUpdate);
    if (!available) { lastError.value = 'Samsung IAP unavailable'; return; }
    products.value = await _iapService.queryProducts();
  }

  void _handlePurchaseUpdate(SamsungPurchase purchase) {
    switch (purchase.status) {
      case SamsungPurchaseStatus.purchased:
      case SamsungPurchaseStatus.restored:
        purchaseFlowState.value = PurchaseFlowState.success;
        unawaited(_setEntitled(true));
        break;
      case SamsungPurchaseStatus.error:
        purchaseFlowState.value = PurchaseFlowState.error;
        lastError.value = purchase.errorMessage ?? 'Purchase failed';
        break;
      case SamsungPurchaseStatus.canceled:
        purchaseFlowState.value = PurchaseFlowState.cancelled;
        break;
      case SamsungPurchaseStatus.pending:
        purchaseFlowState.value = PurchaseFlowState.inProgress;
        break;
    }
  }

  Future<void> _setEntitled(bool entitled) async {
    adsRemoved.value = entitled;
    await _settingsProvider.setAdsRemoved(entitled);
  }

  SamsungProduct? get removeAdsProduct => products.value.isNotEmpty ? products.value.first : null;

  Future<void> purchase(SamsungProduct product) async {
    purchaseFlowState.value = PurchaseFlowState.inProgress;
    lastError.value = null;
    try {
      await _iapService.purchase(product);
    } on IapUnavailableException catch (error) {
      purchaseFlowState.value = PurchaseFlowState.error;
      lastError.value = error.message;
    }
  }

  Future<void> restore() async {
    purchaseFlowState.value = PurchaseFlowState.inProgress;
    lastError.value = null;
    final bool success = await _iapService.restorePurchases();
    if (!success) {
      purchaseFlowState.value = PurchaseFlowState.error;
      lastError.value = 'Restore failed';
    }
  }

  void dispose() {
    unawaited(_iapService.dispose());
    adsRemoved.dispose(); products.dispose(); purchaseFlowState.dispose(); lastError.dispose();
  }
}
