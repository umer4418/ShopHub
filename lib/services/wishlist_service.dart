import 'package:shared_preferences/shared_preferences.dart';

/// Wishlist Service
/// Handles persistence of wishlist product IDs.
class WishlistService {
  static const _kWishlist = 'shophub.wishlist';

  SharedPreferences? _prefs;

  Future<void> init([SharedPreferences? prefs]) async {
    _prefs = prefs ?? await SharedPreferences.getInstance();
  }

  List<String> loadWishlist() {
    final prefs = _prefs;
    if (prefs == null) return [];
    return prefs.getStringList(_kWishlist) ?? [];
  }

  Future<void> saveWishlist(List<String> wishlistIds) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setStringList(_kWishlist, wishlistIds);
  }
}
