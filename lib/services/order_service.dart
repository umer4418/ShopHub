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

  List<ShopOrder> _memoryOrders = [];

  Future<void> init([SharedPreferences? prefs]) async {
    _prefs = prefs ?? await SharedPreferences.getInstance();
  }

  /// Synchronous local load of orders for instant rendering.
  List<ShopOrder> loadOrders() {
    if (_memoryOrders.isNotEmpty) return _memoryOrders;
    final prefs = _prefs;
    if (prefs == null) return _memoryOrders;

    final oJson = prefs.getString(_kOrders);
    if (oJson != null) {
      try {
        final decoded = jsonDecode(oJson) as List;
        final loaded = decoded
            .map((e) => ShopOrder.fromJson(e as Map<String, dynamic>))
            .toList();
        _memoryOrders = loaded;
        return loaded;
      } catch (_) {
        return _memoryOrders;
      }
    }
    return _memoryOrders;
  }

  void setOrdersForTesting(List<ShopOrder> orders) {
    _memoryOrders = List.of(orders);
    final prefs = _prefs;
    if (prefs != null) {
      try {
        prefs.setString(
          _kOrders,
          jsonEncode(orders.map((e) => e.toJson()).toList()),
        );
      } catch (_) {}
    }
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

  /// Fetches orders for a specific user ID from Supabase Postgres.
  Future<List<ShopOrder>> fetchOrdersForUser(String userId) async {
    if (!hasSupabase) {
      final loaded = loadOrders();
      final source = loaded.isNotEmpty ? loaded : _memoryOrders;
      return source.where((o) => o.userId == userId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    try {
      final res = await _supabase
          .from('orders')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final list = (res as List)
          .map((e) => ShopOrder.fromJson(e as Map<String, dynamic>))
          .toList();
      return list;
    } catch (e) {
      debugPrint('Supabase user orders fetch error: $e');
      final loaded = loadOrders();
      final source = loaded.isNotEmpty ? loaded : _memoryOrders;
      return source.where((o) => o.userId == userId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
  }

  /// Fetches a specific order by ID strictly belonging to [userId].
  Future<ShopOrder?> fetchOrderByIdForUser(String orderId, String userId) async {
    final cleanId = orderId.replaceAll('#', '').trim();
    if (!hasSupabase) {
      final local = loadOrders().where((o) => o.userId == userId).toList();
      try {
        final lower = cleanId.toLowerCase();
        return local.firstWhere((o) {
          final oId = o.id.toLowerCase();
          final oNum = oId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
          final cleanNum = lower.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
          return oId == lower || oNum == cleanNum || oId.endsWith(lower);
        });
      } catch (_) {
        return null;
      }
    }
    try {
      final res = await _supabase
          .from('orders')
          .select()
          .eq('id', cleanId)
          .eq('user_id', userId)
          .maybeSingle();

      if (res != null) {
        return ShopOrder.fromJson(res);
      }

      // Try case-insensitive / partial match but strictly for user_id
      final partialRes = await _supabase
          .from('orders')
          .select()
          .ilike('id', '%$cleanId%')
          .eq('user_id', userId)
          .limit(1);

      if (partialRes.isNotEmpty) {
        return ShopOrder.fromJson(partialRes.first);
      }
    } catch (e) {
      debugPrint('Supabase fetch order error: $e');
    }
    return null;
  }

  Future<void> saveOrders(List<ShopOrder> orders) async {
    _memoryOrders = List.of(orders);
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final prefs = _prefs;
      if (prefs == null) return;
      await prefs.setString(
        _kOrders,
        jsonEncode(orders.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
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

  /// Syncs an order completion to Supabase Postgres, ensuring user_id match.
  Future<bool> syncMarkOrderCompleted(String orderId, String userId) async {
    if (!hasSupabase) return true;
    try {
      await _supabase
          .from('orders')
          .update({'status': OrderStatus.completed.name})
          .eq('id', orderId)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      debugPrint('Supabase mark order completed error: $e');
      return false;
    }
  }
}
