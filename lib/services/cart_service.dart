import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/cart_item.dart';

/// Cart Service
/// Handles persistence of cart items in local storage.
class CartService {
  static const _kCart = 'shophub.cart';

  SharedPreferences? _prefs;

  Future<void> init([SharedPreferences? prefs]) async {
    _prefs = prefs ?? await SharedPreferences.getInstance();
  }

  List<CartItem> loadCart() {
    final prefs = _prefs;
    if (prefs == null) return [];

    final cartJson = prefs.getString(_kCart);
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

  Future<void> saveCart(List<CartItem> cart) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(
      _kCart,
      jsonEncode(cart.map((e) => e.toJson()).toList()),
    );
  }
}
