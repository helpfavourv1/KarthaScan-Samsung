import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SamsungProduct {
  final String id;
  final String title;
  final String price;
  SamsungProduct({required this.id, required this.title, required this.price});
}

enum SamsungPurchaseStatus { pending, purchased, restored, error, canceled }

class SamsungPurchase {
  final String purchaseId;
  final String itemId;
  final SamsungPurchaseStatus status;
  final String? errorMessage;
  SamsungPurchase({required this.purchaseId, required this.itemId, required this.status, this.errorMessage});
}

class IapUnavailableException implements Exception {
  final String message;
  IapUnavailableException(this.message);
}

class IapService {
  static const String removeAdsProductId = 'com.zdmgold.katharscan.removeads';
  static const MethodChannel _channel = MethodChannel('com.zdmgold.katharscan/samsung_iap');

  Future<bool> initialize({required void Function(SamsungPurchase purchase) onPurchaseUpdate}) async {
    try {
      await _channel.invokeMethod('init', {'mode': 1});
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onPurchaseUpdate') {
          final Map<String, dynamic> data = jsonDecode(call.arguments as String);
          final status = data['status'] as String;
          if (status == 'purchased' || status == 'restored') {
            onPurchaseUpdate(SamsungPurchase(
              purchaseId: data['purchaseId'] as String,
              itemId: data['itemId'] as String,
              status: status == 'purchased' ? SamsungPurchaseStatus.purchased : SamsungPurchaseStatus.restored,
            ));
          } else {
            onPurchaseUpdate(SamsungPurchase(
              purchaseId: '', itemId: '', status: SamsungPurchaseStatus.error,
              errorMessage: data['message'] as String?,
            ));
          }
        }
      });
      return true;
    } catch (e) {
      debugPrint('[IapService] init failed: $e');
      return false;
    }
  }

  Future<List<SamsungProduct>> queryProducts() async {
    return [SamsungProduct(id: removeAdsProductId, title: 'Remove Ads', price: '\$9.99')];
  }

  Future<void> purchase(SamsungProduct product) async {
    try {
      await _channel.invokeMethod('purchase', {'itemId': product.id});
    } catch (e) {
      throw IapUnavailableException('Failed to launch Samsung IAP: $e');
    }
  }

  Future<bool> restorePurchases() async { return true; }
  Future<void> dispose() async {}
}
