import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/auth_controller.dart';
import '../controllers/cart_controller.dart';
import '../controllers/order_controller.dart';
import '../controllers/product_controller.dart';
import '../controllers/wishlist_controller.dart';
import '../data/mock_catalog.dart';
import '../models/cart_item.dart';
import '../models/category.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/user.dart';

/// ShopStore
/// Acts as a unified facade bridging the MVC Controllers with legacy components
/// while preserving full backwards compatibility across the application.
class ShopStore extends ChangeNotifier {
  final AuthController? _authCtrl;
  final ProductController? _productCtrl;
  final CartController? _cartCtrl;
  final WishlistController? _wishlistCtrl;
  final OrderController? _orderCtrl;

  ShopStore({
    AuthController? authController,
    ProductController? productController,
    CartController? cartController,
    WishlistController? wishlistController,
    OrderController? orderController,
  })  : _authCtrl = authController,
        _productCtrl = productController,
        _cartCtrl = cartController,
        _wishlistCtrl = wishlistController,
        _orderCtrl = orderController {
    _authCtrl?.addListener(notifyListeners);
    _productCtrl?.addListener(notifyListeners);
    _cartCtrl?.addListener(notifyListeners);
    _wishlistCtrl?.addListener(notifyListeners);
    _orderCtrl?.addListener(notifyListeners);
  }

  static const _kProducts = 'shophub.products';
  static const _kCategories = 'shophub.categories';
  static const _kCart = 'shophub.cart';
  static const _kWishlist = 'shophub.wishlist';
  static const _kOrders = 'shophub.orders';
  static const _kUsers = 'shophub.users';
  static const _kSession = 'shophub.session';

  SharedPreferences? _prefs;
  bool ready = false;

  List<Product> _standaloneProducts = List.of(MockCatalog.products);
  List<ShopCategory> _standaloneCategories = List.of(MockCatalog.categories);
  List<CartItem> _standaloneCart = [];
  List<String> _standaloneWishlistIds = [];
  List<ShopOrder> _standaloneOrders = [];
  List<ShopUser> _standaloneUsers = [MockCatalog.admin, MockCatalog.demoCustomer];
  ShopUser? _standaloneCurrentUser;

  String _standaloneSearch = '';
  String? _standaloneCat;
  double _standaloneMin = 0;
  double _standaloneMax = 200000;
  double _standaloneRating = 0;
  String _standaloneSort = 'popular';

  List<Product> get products => _productCtrl?.products ?? _standaloneProducts;
  set products(List<Product> val) {
    _standaloneProducts = val;
    notifyListeners();
  }

  List<ShopCategory> get categories =>
      _productCtrl?.categories ?? _standaloneCategories;
  set categories(List<ShopCategory> val) {
    _standaloneCategories = val;
    notifyListeners();
  }

  List<CartItem> get cart => _cartCtrl?.cart ?? _standaloneCart;
  set cart(List<CartItem> val) {
    _standaloneCart = val;
    notifyListeners();
  }

  List<String> get wishlistIds =>
      _wishlistCtrl?.wishlistIds ?? _standaloneWishlistIds;
  set wishlistIds(List<String> val) {
    _standaloneWishlistIds = val;
    notifyListeners();
  }

  List<ShopOrder> get orders => _orderCtrl?.orders ?? _standaloneOrders;
  set orders(List<ShopOrder> val) {
    _standaloneOrders = val;
    notifyListeners();
  }

  List<ShopUser> get users => _authCtrl?.users ?? _standaloneUsers;
  set users(List<ShopUser> val) {
    _standaloneUsers = val;
    notifyListeners();
  }

  ShopUser? get currentUser => _authCtrl?.currentUser ?? _standaloneCurrentUser;
  set currentUser(ShopUser? val) {
    if (_authCtrl != null) {
      _authCtrl.setCurrentUser(val);
    } else {
      _standaloneCurrentUser = val;
      notifyListeners();
    }
  }

  String get searchQuery => _productCtrl?.searchQuery ?? _standaloneSearch;
  String? get filterCategoryId =>
      _productCtrl?.filterCategoryId ?? _standaloneCat;
  double get minPrice => _productCtrl?.minPrice ?? _standaloneMin;
  double get maxPrice => _productCtrl?.maxPrice ?? _standaloneMax;
  double get minRating => _productCtrl?.minRating ?? _standaloneRating;
  String get sortBy => _productCtrl?.sortBy ?? _standaloneSort;

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _load();
    } catch (_) {
      // Tests or first launch without a platform channel still work in-memory.
    }
    ready = true;
    notifyListeners();
  }

  void _load() {
    final prefs = _prefs;
    if (prefs == null) return;

    final pJson = prefs.getString(_kProducts);
    if (pJson != null) {
      _standaloneProducts = (jsonDecode(pJson) as List)
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    final cJson = prefs.getString(_kCategories);
    if (cJson != null) {
      _standaloneCategories = (jsonDecode(cJson) as List)
          .map((e) => ShopCategory.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    final cartJson = prefs.getString(_kCart);
    if (cartJson != null) {
      _standaloneCart = (jsonDecode(cartJson) as List)
          .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    _standaloneWishlistIds = prefs.getStringList(_kWishlist) ?? [];
    final oJson = prefs.getString(_kOrders);
    if (oJson != null) {
      _standaloneOrders = (jsonDecode(oJson) as List)
          .map((e) => ShopOrder.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    final uJson = prefs.getString(_kUsers);
    if (uJson != null) {
      _standaloneUsers = (jsonDecode(uJson) as List)
          .map((e) => ShopUser.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    final session = prefs.getString(_kSession);
    if (session != null) {
      try {
        _standaloneCurrentUser =
            _standaloneUsers.firstWhere((u) => u.email == session);
      } catch (_) {
        _standaloneCurrentUser = null;
      }
    }
  }

  Future<void> _persist() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(_kProducts,
        jsonEncode(_standaloneProducts.map((e) => e.toJson()).toList()));
    await prefs.setString(_kCategories,
        jsonEncode(_standaloneCategories.map((e) => e.toJson()).toList()));
    await prefs.setString(
        _kCart, jsonEncode(_standaloneCart.map((e) => e.toJson()).toList()));
    await prefs.setStringList(_kWishlist, _standaloneWishlistIds);
    await prefs.setString(_kOrders,
        jsonEncode(_standaloneOrders.map((e) => e.toJson()).toList()));
    await prefs.setString(_kUsers,
        jsonEncode(_standaloneUsers.map((e) => e.toJson()).toList()));
    if (_standaloneCurrentUser == null) {
      await prefs.remove(_kSession);
    } else {
      await prefs.setString(_kSession, _standaloneCurrentUser!.email);
    }
  }

  int get cartCount => _cartCtrl?.cartCount ?? cart.fold(0, (s, i) => s + i.quantity);
  double get cartTotal => _cartCtrl?.cartTotal ?? cart.fold(0, (s, i) => s + i.lineTotal);

  List<Product> get featured =>
      _productCtrl?.featured ?? products.where((p) => p.featured).toList();
  List<Product> get popular =>
      _productCtrl?.popular ?? products.where((p) => p.popular).toList();

  List<Product> get wishlistProducts =>
      products.where((p) => wishlistIds.contains(p.id)).toList();

  bool inWishlist(String id) =>
      _wishlistCtrl?.inWishlist(id) ?? wishlistIds.contains(id);

  ShopCategory? categoryById(String id) {
    if (_productCtrl != null) return _productCtrl.categoryById(id);
    try {
      return categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Product> get filteredProducts {
    if (_productCtrl != null) return _productCtrl.filteredProducts;
    var list = products.where((p) {
      final q = searchQuery.trim().toLowerCase();
      final matchesQuery = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.shortDescription.toLowerCase().contains(q);
      final matchesCat =
          filterCategoryId == null || p.categoryId == filterCategoryId;
      final matchesPrice = p.price >= minPrice && p.price <= maxPrice;
      final matchesRating = p.rating >= minRating;
      return matchesQuery && matchesCat && matchesPrice && matchesRating;
    }).toList();

    switch (sortBy) {
      case 'price_low':
        list.sort((a, b) => a.price.compareTo(b.price));
      case 'price_high':
        list.sort((a, b) => b.price.compareTo(a.price));
      case 'rating':
        list.sort((a, b) => b.rating.compareTo(a.rating));
      case 'discount':
        list.sort((a, b) => b.discountPercent.compareTo(a.discountPercent));
      default:
        list.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
    }
    return list;
  }

  void setSearch(String q) {
    if (_productCtrl != null) {
      _productCtrl.setSearch(q);
    } else {
      _standaloneSearch = q;
      notifyListeners();
    }
  }

  void setFilters({
    String? categoryId,
    bool clearCategory = false,
    double? min,
    double? max,
    double? rating,
    String? sort,
  }) {
    if (_productCtrl != null) {
      _productCtrl.setFilters(
        categoryId: categoryId,
        clearCategory: clearCategory,
        min: min,
        max: max,
        rating: rating,
        sort: sort,
      );
    } else {
      if (clearCategory) _standaloneCat = null;
      if (categoryId != null) _standaloneCat = categoryId;
      if (min != null) _standaloneMin = min;
      if (max != null) _standaloneMax = max;
      if (rating != null) _standaloneRating = rating;
      if (sort != null) _standaloneSort = sort;
      notifyListeners();
    }
  }

  void resetFilters() {
    if (_productCtrl != null) {
      _productCtrl.resetFilters();
    } else {
      _standaloneSearch = '';
      _standaloneCat = null;
      _standaloneMin = 0;
      _standaloneMax = 200000;
      _standaloneRating = 0;
      _standaloneSort = 'popular';
      notifyListeners();
    }
  }

  void addToCart(Product product, {int qty = 1}) {
    if (_cartCtrl != null) {
      _cartCtrl.addToCart(product, qty: qty);
    } else {
      final i = _standaloneCart.indexWhere((c) => c.product.id == product.id);
      if (i >= 0) {
        _standaloneCart[i] =
            _standaloneCart[i].copyWith(quantity: _standaloneCart[i].quantity + qty);
      } else {
        _standaloneCart.add(CartItem(product: product, quantity: qty));
      }
      _persist();
      notifyListeners();
    }
  }

  void setCartQty(String productId, int qty) {
    if (_cartCtrl != null) {
      _cartCtrl.setCartQty(productId, qty);
    } else {
      if (qty <= 0) {
        _standaloneCart.removeWhere((c) => c.product.id == productId);
      } else {
        final i = _standaloneCart.indexWhere((c) => c.product.id == productId);
        if (i >= 0) {
          _standaloneCart[i] = _standaloneCart[i].copyWith(quantity: qty);
        }
      }
      _persist();
      notifyListeners();
    }
  }

  void removeFromCart(String productId) {
    if (_cartCtrl != null) {
      _cartCtrl.removeFromCart(productId);
    } else {
      _standaloneCart.removeWhere((c) => c.product.id == productId);
      _persist();
      notifyListeners();
    }
  }

  void clearCart() {
    if (_cartCtrl != null) {
      _cartCtrl.clearCart();
    } else {
      _standaloneCart.clear();
      _persist();
      notifyListeners();
    }
  }

  void toggleWishlist(String productId) {
    if (_wishlistCtrl != null) {
      _wishlistCtrl.toggleWishlist(productId);
    } else {
      if (_standaloneWishlistIds.contains(productId)) {
        _standaloneWishlistIds.remove(productId);
      } else {
        _standaloneWishlistIds.add(productId);
      }
      _persist();
      notifyListeners();
    }
  }

  ShopOrder placeOrder({
    required String name,
    required String phone,
    required String address,
    String paymentMethod = 'Cash on Delivery',
  }) {
    if (_orderCtrl != null && _cartCtrl != null) {
      final order = _orderCtrl.placeOrder(
        name: name,
        phone: phone,
        address: address,
        paymentMethod: paymentMethod,
        items: _cartCtrl.cart,
        total: _cartCtrl.cartTotal,
      );
      _cartCtrl.clearCart();
      return order;
    }

    final id =
        'SH${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final order = ShopOrder(
      id: id,
      customerName: name,
      phone: phone,
      address: address,
      paymentMethod: paymentMethod,
      items: List.of(_standaloneCart),
      total: cartTotal,
      createdAt: DateTime.now(),
      status: OrderStatus.placed,
    );
    _standaloneOrders.insert(0, order);
    _standaloneCart.clear();
    _persist();
    notifyListeners();
    return order;
  }

  void updateOrderStatus(String id, OrderStatus status) {
    if (_orderCtrl != null) {
      _orderCtrl.updateOrderStatus(id, status);
    } else {
      final i = _standaloneOrders.indexWhere((o) => o.id == id);
      if (i >= 0) {
        _standaloneOrders[i] = _standaloneOrders[i].copyWith(status: status);
        _persist();
        notifyListeners();
      }
    }
  }

  String? login(String email, String password) {
    if (_authCtrl != null) {
      return _authCtrl.login(email, password);
    }
    try {
      final user = _standaloneUsers.firstWhere(
        (u) =>
            u.email.toLowerCase() == email.trim().toLowerCase() &&
            u.password == password,
      );
      _standaloneCurrentUser = user;
      _persist();
      notifyListeners();
      return null;
    } catch (_) {
      return 'Invalid email or password';
    }
  }

  String? register({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) {
    if (_authCtrl != null) {
      return _authCtrl.register(
        name: name,
        email: email,
        password: password,
        phone: phone,
      );
    }
    final exists = _standaloneUsers
        .any((u) => u.email.toLowerCase() == email.trim().toLowerCase());
    if (exists) return 'An account with this email already exists';
    final user = ShopUser(
        name: name, email: email.trim(), password: password, phone: phone);
    _standaloneUsers.add(user);
    _standaloneCurrentUser = user;
    _persist();
    notifyListeners();
    return null;
  }

  void logout() {
    if (_authCtrl != null) {
      _authCtrl.logout();
    } else {
      _standaloneCurrentUser = null;
      _persist();
      notifyListeners();
    }
  }

  void addProduct(Product product) {
    if (_productCtrl != null) {
      _productCtrl.addProduct(product);
    } else {
      _standaloneProducts.insert(0, product);
      _persist();
      notifyListeners();
    }
  }

  void updateProduct(Product product) {
    if (_productCtrl != null) {
      _productCtrl.updateProduct(product);
    } else {
      final i = _standaloneProducts.indexWhere((p) => p.id == product.id);
      if (i >= 0) {
        _standaloneProducts[i] = product;
        _persist();
        notifyListeners();
      }
    }
  }

  void deleteProduct(String id) {
    if (_productCtrl != null) {
      _productCtrl.deleteProduct(id);
      _cartCtrl?.removeFromCart(id);
      _wishlistCtrl?.removeProduct(id);
    } else {
      _standaloneProducts.removeWhere((p) => p.id == id);
      _standaloneCart.removeWhere((c) => c.product.id == id);
      _standaloneWishlistIds.remove(id);
      _persist();
      notifyListeners();
    }
  }

  void addCategory(ShopCategory category) {
    if (_productCtrl != null) {
      _productCtrl.addCategory(category);
    } else {
      _standaloneCategories.add(category);
      _persist();
      notifyListeners();
    }
  }

  void updateCategory(ShopCategory category) {
    if (_productCtrl != null) {
      _productCtrl.updateCategory(category);
    } else {
      final i = _standaloneCategories.indexWhere((c) => c.id == category.id);
      if (i >= 0) {
        _standaloneCategories[i] = category;
        _persist();
        notifyListeners();
      }
    }
  }

  void deleteCategory(String id) {
    if (_productCtrl != null) {
      _productCtrl.deleteCategory(id);
    } else {
      _standaloneCategories.removeWhere((c) => c.id == id);
      _persist();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authCtrl?.removeListener(notifyListeners);
    _productCtrl?.removeListener(notifyListeners);
    _cartCtrl?.removeListener(notifyListeners);
    _wishlistCtrl?.removeListener(notifyListeners);
    _orderCtrl?.removeListener(notifyListeners);
    super.dispose();
  }
}
