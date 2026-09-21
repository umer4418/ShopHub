import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/product.dart';
import '../services/cart_service.dart';

/// Cart Controller
/// Manages shopping cart state, quantity updates, calculations, and persistence.
class CartController extends ChangeNotifier {
  final CartService _cartService;

  CartController({CartService? cartService})
      : _cartService = cartService ?? CartService();

  List<CartItem> _cart = [];
  bool _isInitialized = false;

  List<CartItem> get cart => List.unmodifiable(_cart);
  bool get isInitialized => _isInitialized;
  bool get isEmpty => _cart.isEmpty;
  int get cartCount => _cart.fold(0, (s, i) => s + i.quantity);
  double get cartTotal => _cart.fold(0, (s, i) => s + i.lineTotal);

  void init() {
    _cart = _cartService.loadCart();
    _isInitialized = true;
    notifyListeners();
  }

  void addToCart(Product product, {int qty = 1}) {
    final i = _cart.indexWhere((c) => c.product.id == product.id);
    if (i >= 0) {
      _cart[i] = _cart[i].copyWith(quantity: _cart[i].quantity + qty);
    } else {
      _cart.add(CartItem(product: product, quantity: qty));
    }
    _cartService.saveCart(_cart);
    notifyListeners();
  }

  void setCartQty(String productId, int qty) {
    if (qty <= 0) {
      _cart.removeWhere((c) => c.product.id == productId);
    } else {
      final i = _cart.indexWhere((c) => c.product.id == productId);
      if (i >= 0) {
        _cart[i] = _cart[i].copyWith(quantity: qty);
      }
    }
    _cartService.saveCart(_cart);
    notifyListeners();
  }

  void removeFromCart(String productId) {
    _cart.removeWhere((c) => c.product.id == productId);
    _cartService.saveCart(_cart);
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    _cartService.saveCart(_cart);
    notifyListeners();
  }

  /// Remove item if product is deleted
  void removeProduct(String productId) {
    removeFromCart(productId);
  }
}
