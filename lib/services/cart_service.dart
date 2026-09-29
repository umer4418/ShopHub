import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/auth_controller.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import 'product_service.dart';

/// Cart Service
/// Handles persistence of cart items in Supabase Postgres (isolated by user UUID)
/// and local storage caching partitioned strictly per user.
class CartService {
  static const _kLegacySharedCart = 'shophub.cart';

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
    // Clear legacy un-partitioned shared cart to eliminate cross-user data leakage
    try {
      await _prefs?.remove(_kLegacySharedCart);
    } catch (_) {}
  }

  /// Returns the current authenticated Supabase user ID.
  /// Falls back to AuthController's current user id/email for mock/offline compatibility.
  String? get currentAuthUserId {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null && user.id.isNotEmpty) {
        return user.id;
      }
    } catch (_) {}

    try {
      if (Get.isRegistered<AuthController>()) {
        final authCtrl = Get.find<AuthController>();
        final user = authCtrl.currentUser;
        if (user != null) {
          return user.id ?? (user.email.isNotEmpty ? user.email : null);
        }
      }
    } catch (_) {}

    return null;
  }

  String _userCartKey(String userId) => 'shophub.cart.$userId';

  /// Loads cart items cached locally for a specific [userId].
  List<CartItem> loadUserCartLocally(String userId) {
    final prefs = _prefs;
    if (prefs == null || userId.isEmpty) return [];

    final cartJson = prefs.getString(_userCartKey(userId));
    if (cartJson != null) {
      try {
        final decoded = jsonDecode(cartJson) as List;
        return decoded
            .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return [];
      }
    }
    return [];
  }

  /// Persists cart items locally for a specific [userId].
  Future<void> saveUserCartLocally(String userId, List<CartItem> cart) async {
    final prefs = _prefs;
    if (prefs == null || userId.isEmpty) return;

    await prefs.setString(
      _userCartKey(userId),
      jsonEncode(cart.map((e) => e.toJson()).toList()),
    );
  }

  /// Clears local cart cache for a specific [userId].
  Future<void> clearUserCartLocally(String userId) async {
    final prefs = _prefs;
    if (prefs == null || userId.isEmpty) return;
    await prefs.remove(_userCartKey(userId));
  }

  /// Backward-compatible loadCart: loads for the specified [userId] or current auth user.
  List<CartItem> loadCart([String? userId]) {
    final uid = userId ?? currentAuthUserId;
    if (uid == null) return [];
    return loadUserCartLocally(uid);
  }

  /// Backward-compatible saveCart: saves for the specified [userId] or current auth user.
  Future<void> saveCart(List<CartItem> cart, [String? userId]) async {
    final uid = userId ?? currentAuthUserId;
    if (uid == null) return;
    await saveUserCartLocally(uid, cart);
  }

  /// Fetches cart items from Supabase Postgres for [userId]
  /// and updates local cache.
  Future<List<CartItem>> fetchCartFromSupabase(String userId) async {
    if (!hasSupabase || userId.isEmpty) {
      return loadUserCartLocally(userId);
    }

    try {
      final res = await _supabase
          .from('cart')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      final List<Product> catalog = Get.isRegistered<ProductService>()
          ? Get.find<ProductService>().loadProducts()
          : [];

      final list = (res as List).map((row) {
        final map = row as Map<String, dynamic>;
        final pid = map['product_id']?.toString();
        Product? match;
        if (pid != null && catalog.isNotEmpty) {
          match = catalog.cast<Product?>().firstWhere(
                (p) => p?.id == pid,
                orElse: () => null,
              );
        }
        return CartItem.fromSupabase(map, match);
      }).toList();

      await saveUserCartLocally(userId, list);
      return list;
    } catch (e) {
      debugPrint('Supabase cart fetch error: $e');
      return loadUserCartLocally(userId);
    }
  }

  /// Syncs an added or incremented product to Supabase Postgres.
  Future<void> syncAddToCart(String userId, Product product, int qty) async {
    if (!hasSupabase || userId.isEmpty) return;

    try {
      final existing = await _supabase
          .from('cart')
          .select('id, quantity, count')
          .eq('user_id', userId)
          .eq('product_id', product.id)
          .maybeSingle();

      if (existing != null) {
        final currentQty = (existing['quantity'] as num?)?.toInt() ??
            (existing['count'] as num?)?.toInt() ??
            0;
        final newQty = currentQty + qty;
        await _supabase.from('cart').update({
          'quantity': newQty,
          'count': newQty,
          'product_data': product.toJson(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('user_id', userId).eq('product_id', product.id);
      } else {
        await _supabase.from('cart').insert({
          'user_id': userId,
          'product_id': product.id,
          'quantity': qty,
          'count': qty,
          'product_data': product.toJson(),
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Supabase syncAddToCart error: $e');
    }
  }

  /// Syncs quantity update to Supabase Postgres.
  Future<void> syncSetCartQty(String userId, String productId, int qty) async {
    if (!hasSupabase || userId.isEmpty) return;

    try {
      if (qty <= 0) {
        await syncRemoveFromCart(userId, productId);
        return;
      }
      await _supabase.from('cart').update({
        'quantity': qty,
        'count': qty,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('user_id', userId).eq('product_id', productId);
    } catch (e) {
      debugPrint('Supabase syncSetCartQty error: $e');
    }
  }

  /// Syncs removal of a product from cart to Supabase Postgres.
  Future<void> syncRemoveFromCart(String userId, String productId) async {
    if (!hasSupabase || userId.isEmpty) return;

    try {
      await _supabase
          .from('cart')
          .delete()
          .eq('user_id', userId)
          .eq('product_id', productId);
    } catch (e) {
      debugPrint('Supabase syncRemoveFromCart error: $e');
    }
  }

  /// Syncs clearing all cart items for a user to Supabase Postgres.
  Future<void> syncClearCart(String userId) async {
    if (!hasSupabase || userId.isEmpty) return;

    try {
      await _supabase.from('cart').delete().eq('user_id', userId);
    } catch (e) {
      debugPrint('Supabase syncClearCart error: $e');
    }
  }
}
