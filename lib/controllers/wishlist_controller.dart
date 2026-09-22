import 'package:get/get.dart';

import '../models/product.dart';
import '../services/wishlist_service.dart';

/// Wishlist Controller
/// Manages user's favorited / saved products and wishlist persistence.
class WishlistController extends GetxController {
  final WishlistService _wishlistService;

  WishlistController({WishlistService? wishlistService})
      : _wishlistService = wishlistService ?? WishlistService();

  static WishlistController get to => Get.find<WishlistController>();

  final RxList<String> _wishlistIds = <String>[].obs;
  final RxBool _isInitialized = false.obs;

  List<String> get wishlistIds => List.unmodifiable(_wishlistIds);
  bool get isInitialized => _isInitialized.value;
  bool get isEmpty => _wishlistIds.isEmpty;
  int get count => _wishlistIds.length;

  bool inWishlist(String productId) => _wishlistIds.contains(productId);

  List<Product> getWishlistProducts(List<Product> allProducts) {
    return allProducts.where((p) => _wishlistIds.contains(p.id)).toList();
  }

  void init() {
    _wishlistIds.assignAll(_wishlistService.loadWishlist());
    _isInitialized.value = true;
    update();
  }

  void toggleWishlist(String productId) {
    if (_wishlistIds.contains(productId)) {
      _wishlistIds.remove(productId);
    } else {
      _wishlistIds.add(productId);
    }
    _wishlistService.saveWishlist(_wishlistIds);
    update();
  }

  void removeProduct(String productId) {
    if (_wishlistIds.contains(productId)) {
      _wishlistIds.remove(productId);
      _wishlistService.saveWishlist(_wishlistIds);
      update();
    }
  }
}
