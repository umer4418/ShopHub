import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/auth_controller.dart';

/// Wishlist Service
/// Handles persistence of user-specific wishlist items in Supabase Postgres (isolated by user UUID)
/// and local storage caching partitioned strictly per user.
class WishlistService {
  static const _kLegacySharedWishlist = 'shophub.wishlist';

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
    // Clear legacy un-partitioned shared wishlist to eliminate cross-user data leakage
    try {
      await _prefs?.remove(_kLegacySharedWishlist);
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

  String _userWishlistKey(String userId) => 'shophub.wishlist.$userId';

  /// Loads wishlist product IDs cached locally for a specific [userId].
  List<String> loadUserWishlistLocally(String userId) {
    final prefs = _prefs;
    if (prefs == null || userId.isEmpty) return [];
    return prefs.getStringList(_userWishlistKey(userId)) ?? [];
  }

  /// Persists wishlist product IDs locally for a specific [userId].
  Future<void> saveUserWishlistLocally(
      String userId, List<String> wishlistIds) async {
    final prefs = _prefs;
    if (prefs == null || userId.isEmpty) return;
    await prefs.setStringList(_userWishlistKey(userId), wishlistIds);
  }

  /// Clears local wishlist cache for a specific [userId].
  Future<void> clearUserWishlistLocally(String userId) async {
    final prefs = _prefs;
    if (prefs == null || userId.isEmpty) return;
    await prefs.remove(_userWishlistKey(userId));
  }

  /// Backward-compatible loadWishlist: loads for specified [userId] or current auth user.
  List<String> loadWishlist([String? userId]) {
    final uid = userId ?? currentAuthUserId;
    if (uid == null) return [];
    return loadUserWishlistLocally(uid);
  }

  /// Backward-compatible saveWishlist: saves for specified [userId] or current auth user.
  Future<void> saveWishlist(List<String> wishlistIds, [String? userId]) async {
    final uid = userId ?? currentAuthUserId;
    if (uid == null) return;
    await saveUserWishlistLocally(uid, wishlistIds);
  }

  /// Fetches wishlist product IDs from Supabase Postgres for [userId]
  /// and updates local cache.
  Future<List<String>> fetchWishlistFromSupabase(String userId) async {
    if (!hasSupabase || userId.isEmpty) {
      return loadUserWishlistLocally(userId);
    }

    try {
      final res = await _supabase
          .from('wishlist')
          .select('product_id')
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      final ids = (res as List)
          .map((row) => (row as Map<String, dynamic>)['product_id']?.toString())
          .whereType<String>()
          .toList();

      await saveUserWishlistLocally(userId, ids);
      return ids;
    } catch (e) {
      debugPrint('Supabase wishlist fetch error: $e');
      return loadUserWishlistLocally(userId);
    }
  }

  /// Syncs an added product to Supabase Postgres.
  Future<void> syncAddToWishlist(String userId, String productId) async {
    if (!hasSupabase || userId.isEmpty || productId.isEmpty) return;

    try {
      await _supabase.from('wishlist').upsert(
        {
          'user_id': userId,
          'product_id': productId,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,product_id',
      );
    } catch (e) {
      debugPrint('Supabase syncAddToWishlist error: $e');
    }
  }

  /// Syncs removal of a product from wishlist in Supabase Postgres.
  Future<void> syncRemoveFromWishlist(String userId, String productId) async {
    if (!hasSupabase || userId.isEmpty || productId.isEmpty) return;

    try {
      await _supabase
          .from('wishlist')
          .delete()
          .eq('user_id', userId)
          .eq('product_id', productId);
    } catch (e) {
      debugPrint('Supabase syncRemoveFromWishlist error: $e');
    }
  }

  /// Syncs clearing all wishlist items for a user in Supabase Postgres.
  Future<void> syncClearWishlist(String userId) async {
    if (!hasSupabase || userId.isEmpty) return;

    try {
      await _supabase.from('wishlist').delete().eq('user_id', userId);
    } catch (e) {
      debugPrint('Supabase syncClearWishlist error: $e');
    }
  }
}
