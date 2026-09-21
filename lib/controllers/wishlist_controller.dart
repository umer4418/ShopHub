import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../services/wishlist_service.dart';

/// Wishlist Controller
/// Manages user's favorited / saved products and wishlist persistence.
class WishlistController extends ChangeNotifier {
  final WishlistService _wishlistService;

  WishlistController({WishlistService? wishlistService})
      : _wishlistService = wishlistService ?? WishlistService();

  List<String> _wishlistIds = [];
  bool _isInitialized = false;

  List<String> get wishlistIds => List.unmodifiable(_wishlistIds);
  bool get isInitialized => _isInitialized;
  bool get isEmpty => _wishlistIds.isEmpty;
  int get count => _wishlistIds.length;

  bool inWishlist(String productId) => _wishlistIds.contains(productId);

  List<Product> getWishlistProducts(List<Product> allProducts) {
    return allProducts.where((p) => _wishlistIds.contains(p.id)).toList();
  }

  void init() {
    _wishlistIds = _wishlistService.loadWishlist();
    _isInitialized = true;
    notifyListeners();
  }

  void toggleWishlist(String productId) {
    if (_wishlistIds.contains(productId)) {
      _wishlistIds.remove(productId);
    } else {
      _wishlistIds.add(productId);
    }
    _wishlistService.saveWishlist(_wishlistIds);
    notifyListeners();
  }

  void removeProduct(String productId) {
    if (_wishlistIds.contains(productId)) {
      _wishlistIds.remove(productId);
      _wishlistService.saveWishlist(_wishlistIds);
      notifyListeners();
    }
  }
}
