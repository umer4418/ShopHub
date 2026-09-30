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

  bool _isValidUuid(String? id) {
    if (id == null || id.isEmpty) return false;
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id.trim());
  }

  /// Fetches orders from Supabase Postgres database and caches locally.
  /// Supabase is the single source of truth for authorized admin and global views.
  Future<List<ShopOrder>> fetchOrdersFromSupabase() async {
    final currentUserId = () {
      try {
        return Supabase.instance.client.auth.currentUser?.id ?? 'admin';
      } catch (_) {
        return 'admin';
      }
    }();
    debugPrint('Order fetch - Current User ID: $currentUserId (all orders)');

    if (!hasSupabase) {
      final loaded = loadOrders();
      debugPrint('Order fetch - Orders fetched: ${loaded.length} (offline)');
      return loaded;
    }
    try {
      final res = await _supabase
          .from('orders')
          .select()
          .order('created_at', ascending: false);

      final list = (res as List)
          .map((e) => ShopOrder.fromJson(e as Map<String, dynamic>))
          .toList();

      debugPrint('Order fetch - Orders fetched: ${list.length}');
      await saveOrders(list);
      return list;
    } catch (e) {
      debugPrint('Order fetch error: $e');
      final loaded = loadOrders();
      debugPrint('Order fetch - Orders fetched: ${loaded.length} (fallback)');
      return loaded;
    }
  }

  /// Fetches orders for a specific user ID and optional email from Supabase Postgres.
  Future<List<ShopOrder>> fetchOrdersForUser(String userId, [String? userEmail]) async {
    final currentUserId = userId.trim();
    debugPrint('Order fetch - Current User ID: $currentUserId');

    if (!hasSupabase) {
      final loaded = loadOrders();
      final source = loaded.isNotEmpty ? loaded : _memoryOrders;
      final filtered = source.where((o) =>
          o.userId == currentUserId ||
          (userEmail != null &&
              userEmail.isNotEmpty &&
              o.customerEmail?.toLowerCase().trim() == userEmail.toLowerCase().trim()),
      ).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      debugPrint('Order fetch - Orders fetched: ${filtered.length} (offline)');
      return filtered;
    }
    try {
      final isUuid = _isValidUuid(currentUserId);
      final email = userEmail?.trim().toLowerCase();

      List<dynamic> res;
      if (isUuid) {
        res = await _supabase
            .from('orders')
            .select()
            .eq('user_id', currentUserId)
            .order('created_at', ascending: false);
      } else {
        res = await _supabase
            .from('orders')
            .select()
            .order('created_at', ascending: false);
      }

      final list = res
          .map((e) => ShopOrder.fromJson(e as Map<String, dynamic>))
          .where((o) {
            if (isUuid) return true;
            return o.userId == currentUserId ||
                (email != null &&
                    email.isNotEmpty &&
                    o.customerEmail?.toLowerCase().trim() == email);
          })
          .toList();
      debugPrint('Order fetch - Orders fetched: ${list.length}');
      return list;
    } catch (e) {
      debugPrint('Order fetch error: $e');
      final loaded = loadOrders();
      final source = loaded.isNotEmpty ? loaded : _memoryOrders;
      final fallback = source.where((o) =>
          o.userId == currentUserId ||
          (userEmail != null &&
              userEmail.isNotEmpty &&
              o.customerEmail?.toLowerCase().trim() == userEmail.toLowerCase().trim()),
      ).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      debugPrint('Order fetch - Orders fetched: ${fallback.length} (fallback)');
      return fallback;
    }
  }

  /// Fetches a specific order by ID strictly belonging to [userId] or [userEmail].
  Future<ShopOrder?> fetchOrderByIdForUser(String orderId, String userId, [String? userEmail]) async {
    final cleanId = orderId.replaceAll('#', '').trim();
    final currentUserId = userId.trim();
    final email = userEmail?.trim().toLowerCase();
    final isUuid = _isValidUuid(currentUserId);

    if (!hasSupabase) {
      final local = loadOrders().where((o) =>
          o.userId == currentUserId ||
          (email != null && email.isNotEmpty && o.customerEmail?.toLowerCase().trim() == email),
      ).toList();
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
      var query = _supabase.from('orders').select().eq('id', cleanId);
      if (isUuid) {
        query = query.eq('user_id', currentUserId);
      }

      final res = await query.maybeSingle();
      if (res != null) {
        final order = ShopOrder.fromJson(res);
        if (isUuid && order.userId == currentUserId) return order;
        if (email != null && order.customerEmail?.toLowerCase().trim() == email) return order;
        if (!isUuid && email == null) return order;
      }

      // Try case-insensitive / partial match but strictly for user
      var partialQuery = _supabase.from('orders').select().ilike('id', '%$cleanId%');
      if (isUuid) {
        partialQuery = partialQuery.eq('user_id', currentUserId);
      }

      final partialRes = await partialQuery.limit(1);
      if (partialRes.isNotEmpty) {
        final order = ShopOrder.fromJson(partialRes.first);
        if (isUuid && order.userId == currentUserId) return order;
        if (email != null && order.customerEmail?.toLowerCase().trim() == email) return order;
        if (!isUuid && email == null) return order;
      }
    } catch (e) {
      debugPrint('Order fetch error: $e');
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

    // Resolve authentic Supabase session ID if present
    String? resolvedUserId = order.userId;
    try {
      final supaAuthUser = _supabase.auth.currentUser;
      if (supaAuthUser != null && supaAuthUser.id.isNotEmpty) {
        resolvedUserId = supaAuthUser.id;
      }
    } catch (_) {}

    final orderToSync = (resolvedUserId != null && resolvedUserId != order.userId)
        ? order.copyWith(userId: resolvedUserId)
        : order;

    final map = orderToSync.toSupabaseMap();
    debugPrint('Order sync - Current User ID: ${orderToSync.userId}');
    debugPrint('Order sync - Starting for Order ID: ${orderToSync.id}');

    try {
      await _supabase.from('orders').insert(map);
      debugPrint('Order sync - Successfully inserted Order ID: ${orderToSync.id}');
    } catch (e) {
      debugPrint('Order sync - Insert failed ($e), trying upsert fallback...');
      try {
        await _supabase.from('orders').upsert(map);
        debugPrint('Order sync - Successfully upserted Order ID: ${orderToSync.id}');
      } catch (upsertErr) {
        debugPrint('Order sync error for Order ID ${orderToSync.id}: $upsertErr');
      }
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
