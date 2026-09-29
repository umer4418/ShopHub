import 'package:get/get.dart';

import '../models/product.dart';
import '../services/wishlist_service.dart';

/// Wishlist Controller
/// Manages user's favorited / saved products, real-time UI state,
/// and per-user persistence across Supabase and local storage.
class WishlistController extends GetxController {
  final WishlistService _wishlistService;

  WishlistController({WishlistService? wishlistService})
      : _wishlistService = wishlistService ?? WishlistService();

  static WishlistController get to => Get.find<WishlistController>();

  final RxList<String> _wishlistIds = <String>[].obs;
  final RxBool _isInitialized = false.obs;
  final RxBool _isLoading = false.obs;
  final RxnString _activeUserId = RxnString();

  List<String> get wishlistIds => List.unmodifiable(_wishlistIds);
  bool get isInitialized => _isInitialized.value;
  bool get isLoading => _isLoading.value;
  bool get isEmpty => _wishlistIds.isEmpty;
  int get count => _wishlistIds.length;
  String? get activeUserId => _activeUserId.value;

  bool inWishlist(String productId) => _wishlistIds.contains(productId);

  List<Product> getWishlistProducts(List<Product> allProducts) {
    return allProducts.where((p) => _wishlistIds.contains(p.id)).toList();
  }

  void init() {
    final uid = _wishlistService.currentAuthUserId;
    _activeUserId.value = uid;
    if (uid != null) {
      _wishlistIds.assignAll(_wishlistService.loadUserWishlistLocally(uid));
      fetchWishlistFromSupabase(uid);
    } else {
      _wishlistIds.clear();
    }
    _isInitialized.value = true;
    update();
  }

  /// Switches active user and loads their isolated wishlist.
  /// Clears in-memory wishlist if [userId] is null.
  Future<void> loadUserWishlist(String? userId) async {
    if (userId == null || userId.isEmpty) {
      clearWishlistForLogout();
      return;
    }

    _activeUserId.value = userId;

    // 1. Immediately load local cached items for this user (fast render)
    final localItems = _wishlistService.loadUserWishlistLocally(userId);
    _wishlistIds.assignAll(localItems);
    update();

    // 2. Fetch fresh wishlist from Supabase Postgres
    await fetchWishlistFromSupabase(userId);
  }

  /// Fetches wishlist items from Supabase for [userId] and updates state.
  Future<void> fetchWishlistFromSupabase(String userId) async {
    _isLoading.value = true;
    update();
    try {
      final remote = await _wishlistService.fetchWishlistFromSupabase(userId);
      // Ensure user hasn't switched during network call
      if (_activeUserId.value == userId) {
        _wishlistIds.assignAll(remote);
        update();
      }
    } catch (_) {
    } finally {
      _isLoading.value = false;
      update();
    }
  }

  /// Clears local wishlist state when user logs out.
  void clearWishlistForLogout() {
    _activeUserId.value = null;
    _wishlistIds.clear();
    update();
  }

  /// Event hook for auth changes.
  void onUserChanged(String? userId) {
    loadUserWishlist(userId);
  }

  void toggleWishlist(String productId) {
    final uid = _activeUserId.value ?? _wishlistService.currentAuthUserId;
    if (_wishlistIds.contains(productId)) {
      _wishlistIds.remove(productId);
      if (uid != null) {
        _wishlistService.saveUserWishlistLocally(uid, _wishlistIds);
        _wishlistService.syncRemoveFromWishlist(uid, productId);
      }
    } else {
      _wishlistIds.add(productId);
      if (uid != null) {
        _wishlistService.saveUserWishlistLocally(uid, _wishlistIds);
        _wishlistService.syncAddToWishlist(uid, productId);
      }
    }
    update();
  }

  void addProduct(String productId) {
    final uid = _activeUserId.value ?? _wishlistService.currentAuthUserId;
    if (!_wishlistIds.contains(productId)) {
      _wishlistIds.add(productId);
      if (uid != null) {
        _wishlistService.saveUserWishlistLocally(uid, _wishlistIds);
        _wishlistService.syncAddToWishlist(uid, productId);
      }
      update();
    }
  }

  void removeProduct(String productId) {
    final uid = _activeUserId.value ?? _wishlistService.currentAuthUserId;
    if (_wishlistIds.contains(productId)) {
      _wishlistIds.remove(productId);
      if (uid != null) {
        _wishlistService.saveUserWishlistLocally(uid, _wishlistIds);
        _wishlistService.syncRemoveFromWishlist(uid, productId);
      }
      update();
    }
  }
}
