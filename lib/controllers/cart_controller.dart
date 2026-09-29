import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/coupon_controller.dart';
import '../models/cart_item.dart';
import '../models/coupon.dart';
import '../models/product.dart';
import '../services/cart_service.dart';
import '../utils/money.dart';

/// Cart Controller
/// Manages shopping cart state, quantity updates, calculations, discounts,
/// and per-user persistence across Supabase and local storage.
class CartController extends GetxController {
  final CartService _cartService;

  CartController({CartService? cartService})
      : _cartService = cartService ?? CartService();

  static CartController get to => Get.find<CartController>();

  final RxList<CartItem> _cart = <CartItem>[].obs;
  final RxBool _isInitialized = false.obs;
  final Rxn<Coupon> _appliedCoupon = Rxn<Coupon>();
  final RxnString _activeUserId = RxnString();

  List<CartItem> get cart => List.unmodifiable(_cart);
  bool get isInitialized => _isInitialized.value;
  bool get isEmpty => _cart.isEmpty;
  int get cartCount => _cart.fold(0, (s, i) => s + i.quantity);
  double get cartTotal => _cart.fold(0, (s, i) => s + i.lineTotal);
  String? get activeUserId => _activeUserId.value;

  Coupon? get appliedCoupon => _appliedCoupon.value;
  double get discountAmount => _appliedCoupon.value != null
      ? ((cartTotal * _appliedCoupon.value!.discountPercent) / 100.0)
      : 0.0;
  double get finalTotal =>
      (cartTotal - discountAmount).clamp(0.0, double.infinity);

  void init() {
    final uid = _cartService.currentAuthUserId;
    _activeUserId.value = uid;
    if (uid != null) {
      _cart.assignAll(_cartService.loadUserCartLocally(uid));
      fetchCartFromSupabase(uid);
    } else {
      _cart.clear();
    }
    _isInitialized.value = true;
    update();
  }

  /// Switches active user and loads their isolated cart.
  /// Clears in-memory cart if [userId] is null.
  Future<void> loadUserCart(String? userId) async {
    if (userId == null || userId.isEmpty) {
      clearCartForLogout();
      return;
    }

    _activeUserId.value = userId;
    _appliedCoupon.value = null;

    // 1. Immediately load local cached items for this user (fast render)
    final localItems = _cartService.loadUserCartLocally(userId);
    _cart.assignAll(localItems);
    update();

    // 2. Fetch fresh cart from Supabase Postgres
    await fetchCartFromSupabase(userId);
  }

  /// Fetches cart items from Supabase for [userId] and updates state.
  Future<void> fetchCartFromSupabase(String userId) async {
    try {
      final remote = await _cartService.fetchCartFromSupabase(userId);
      // Ensure the user hasn't switched during network call
      if (_activeUserId.value == userId) {
        _cart.assignAll(remote);
        _validateAppliedCoupon();
        update();
      }
    } catch (_) {}
  }

  /// Clears local cart state when user logs out.
  void clearCartForLogout() {
    _activeUserId.value = null;
    _appliedCoupon.value = null;
    _cart.clear();
    update();
  }

  void addToCart(Product product, {int qty = 1}) {
    final uid = _activeUserId.value ?? _cartService.currentAuthUserId;
    final i = _cart.indexWhere((c) => c.product.id == product.id);
    if (i >= 0) {
      _cart[i] = _cart[i].copyWith(
        quantity: _cart[i].quantity + qty,
        userId: uid,
      );
    } else {
      _cart.add(CartItem(
        product: product,
        quantity: qty,
        userId: uid,
      ));
    }

    if (uid != null) {
      _cartService.saveUserCartLocally(uid, _cart);
      _cartService.syncAddToCart(uid, product, qty);
    }
    _validateAppliedCoupon();
    update();
  }

  void setCartQty(String productId, int qty) {
    final uid = _activeUserId.value ?? _cartService.currentAuthUserId;
    if (qty <= 0) {
      _cart.removeWhere((c) => c.product.id == productId);
    } else {
      final i = _cart.indexWhere((c) => c.product.id == productId);
      if (i >= 0) {
        _cart[i] = _cart[i].copyWith(quantity: qty, userId: uid);
      }
    }

    if (uid != null) {
      _cartService.saveUserCartLocally(uid, _cart);
      _cartService.syncSetCartQty(uid, productId, qty);
    }
    _validateAppliedCoupon();
    update();
  }

  void removeFromCart(String productId) {
    final uid = _activeUserId.value ?? _cartService.currentAuthUserId;
    _cart.removeWhere((c) => c.product.id == productId);

    if (uid != null) {
      _cartService.saveUserCartLocally(uid, _cart);
      _cartService.syncRemoveFromCart(uid, productId);
    }
    _validateAppliedCoupon();
    update();
  }

  void clearCart() {
    final uid = _activeUserId.value ?? _cartService.currentAuthUserId;
    _cart.clear();
    _appliedCoupon.value = null;

    if (uid != null) {
      _cartService.clearUserCartLocally(uid);
      _cartService.syncClearCart(uid);
    }
    update();
  }

  /// Applies promotional coupon [code].
  /// Returns null on success or an error message on failure.
  String? applyCoupon(String code, CouponController couponCtrl) {
    if (_cart.isEmpty) {
      return 'Your cart is empty. Add products before applying coupons.';
    }
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) {
      return 'Please enter a coupon code.';
    }

    final coupon = couponCtrl.findCoupon(clean);
    if (coupon == null) {
      return 'Invalid coupon code: $clean';
    }
    if (!coupon.isActive) {
      return 'This coupon is currently inactive.';
    }
    if (coupon.isExpired) {
      final formatted =
          DateFormat('dd MMM yyyy, hh:mm a').format(coupon.expiryDate);
      return 'Coupon $clean expired on $formatted.';
    }
    if (cartTotal < coupon.minOrderAmount) {
      return 'Minimum spend of ${pkr.format(coupon.minOrderAmount)} required for coupon $clean.';
    }

    _appliedCoupon.value = coupon;
    update();
    return null;
  }

  void removeCoupon() {
    _appliedCoupon.value = null;
    update();
  }

  void _validateAppliedCoupon() {
    final coupon = _appliedCoupon.value;
    if (coupon != null && cartTotal < coupon.minOrderAmount) {
      _appliedCoupon.value = null;
    }
  }

  /// Remove item if product is deleted
  void removeProduct(String productId) {
    removeFromCart(productId);
  }
}
