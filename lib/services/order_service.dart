import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order.dart';

/// Order Service
/// Handles persistence of orders in Supabase Postgres and local storage fallback.
class OrderService {
  static const _kOrders = 'shophub.orders';

  SharedPreferences? _prefs;

  SupabaseClient get _supabase => Supabase.instance.client;

  bool get hasSupabase {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> init([SharedPreferences? prefs]) async {
    _prefs = prefs ?? await SharedPreferences.getInstance();
  }

  /// Synchronous local load of orders for instant rendering.
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

  /// Fetches orders from Supabase Postgres database and caches locally.
  Future<List<ShopOrder>> fetchOrdersFromSupabase() async {
    if (!hasSupabase) return loadOrders();
    try {
      final res = await _supabase
          .from('orders')
          .select()
          .order('created_at', ascending: false);

      final list = (res as List)
          .map((e) => ShopOrder.fromJson(e as Map<String, dynamic>))
          .toList();

      if (list.isNotEmpty) {
        await saveOrders(list);
        return list;
      }
    } catch (e) {
      debugPrint('Supabase orders fetch error: $e');
    }
    return loadOrders();
  }

  Future<void> saveOrders(List<ShopOrder> orders) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(
      _kOrders,
      jsonEncode(orders.map((e) => e.toJson()).toList()),
    );
  }

  /// Syncs newly placed order to Supabase Postgres.
  Future<void> syncPlaceOrder(ShopOrder order) async {
    if (!hasSupabase) return;
    try {
      await _supabase.from('orders').upsert(order.toSupabaseMap());
    } catch (e) {
      debugPrint('Supabase place order error: $e');
    }
  }

  /// Syncs updated order status to Supabase Postgres.
  Future<void> syncUpdateOrderStatus(String id, OrderStatus status) async {
    if (!hasSupabase) return;
    try {
      await _supabase.from('orders').update({'status': status.name}).eq('id', id);
    } catch (e) {
      debugPrint('Supabase update order status error: $e');
    }
  }
}
