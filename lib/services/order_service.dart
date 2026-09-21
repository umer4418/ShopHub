import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/order.dart';

/// Order Service
/// Handles persistence of orders in local storage.
class OrderService {
  static const _kOrders = 'shophub.orders';

  SharedPreferences? _prefs;

  Future<void> init([SharedPreferences? prefs]) async {
    _prefs = prefs ?? await SharedPreferences.getInstance();
  }

  List<ShopOrder> loadOrders() {
    final prefs = _prefs;
    if (prefs == null) return [];

    final oJson = prefs.getString(_kOrders);
    if (oJson != null) {
      try {
        final decoded = jsonDecode(oJson) as List;
        return decoded
            .map((e) => ShopOrder.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return [];
      }
    }
    return [];
  }

  Future<void> saveOrders(List<ShopOrder> orders) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(
      _kOrders,
      jsonEncode(orders.map((e) => e.toJson()).toList()),
    );
  }
}
