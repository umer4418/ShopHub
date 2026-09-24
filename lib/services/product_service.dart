import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/mock_catalog.dart';
import '../models/category.dart';
import '../models/product.dart';

/// Product Service
/// Handles persistence and retrieval of products and categories via Supabase Postgres
/// with local SharedPreferences caching and offline fallback.
class ProductService {
  static const _kProducts = 'shophub.products';
  static const _kCategories = 'shophub.categories';

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
  }

  /// Synchronous local load for instant UI rendering without waiting for network.
  List<Product> loadProducts() {
    final prefs = _prefs;
    if (prefs == null) return List.of(MockCatalog.products);

    final pJson = prefs.getString(_kProducts);
    if (pJson != null) {
      try {
        final decoded = jsonDecode(pJson) as List;
        final list = decoded
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList();

        // If local storage has fewer products than MockCatalog, merge with MockCatalog
        if (list.length < MockCatalog.products.length) {
          final existingIds = list.map((p) => p.id).toSet();
          return [
            ...list,
            ...MockCatalog.products.where((p) => !existingIds.contains(p.id)),
          ];
        }
        return list;
      } catch (_) {
        return List.of(MockCatalog.products);
      }
    }
    return List.of(MockCatalog.products);
  }

  /// Synchronous local load for instant UI rendering.
  List<ShopCategory> loadCategories() {
    final prefs = _prefs;
    if (prefs == null) return List.of(MockCatalog.categories);

    final cJson = prefs.getString(_kCategories);
    if (cJson != null) {
      try {
        final decoded = jsonDecode(cJson) as List;
        return decoded
            .map((e) => ShopCategory.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return List.of(MockCatalog.categories);
      }
    }
    return List.of(MockCatalog.categories);
  }

  /// Fetches latest products from Supabase Postgres and updates local cache.
  Future<List<Product>> fetchProductsFromSupabase() async {
    if (!hasSupabase) return loadProducts();
    try {
      final res = await _supabase
          .from('products')
          .select()
          .order('created_at', ascending: false);

      final list = (res as List)
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();

      if (list.isNotEmpty) {
        // Merge Supabase products with MockCatalog so the catalog has the full 30 products
        final existingIds = list.map((p) => p.id).toSet();
        final combined = [
          ...list,
          ...MockCatalog.products.where((p) => !existingIds.contains(p.id)),
        ];
        await saveProducts(combined);
        return combined;
      }
    } catch (e) {
      debugPrint('Supabase products fetch error: $e');
    }
    return loadProducts();
  }

  /// Fetches latest categories from Supabase Postgres and updates local cache.
  Future<List<ShopCategory>> fetchCategoriesFromSupabase() async {
    if (!hasSupabase) return loadCategories();
    try {
      final res = await _supabase
          .from('categories')
          .select()
          .order('name', ascending: true);

      final list = (res as List)
          .map((e) => ShopCategory.fromJson(e as Map<String, dynamic>))
          .toList();

      if (list.isNotEmpty) {
        await saveCategories(list);
        return list;
      }
    } catch (e) {
      debugPrint('Supabase categories fetch error: $e');
    }
    return loadCategories();
  }

  Future<void> saveProducts(List<Product> products) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(
      _kProducts,
      jsonEncode(products.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> saveCategories(List<ShopCategory> categories) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(
      _kCategories,
      jsonEncode(categories.map((e) => e.toJson()).toList()),
    );
  }

  /// Syncs an added product to Supabase Postgres
  Future<void> syncAddProduct(Product product) async {
    if (!hasSupabase) return;
    try {
      await _supabase.from('products').upsert(product.toSupabaseMap());
    } catch (e) {
      debugPrint('Supabase add product error: $e');
    }
  }

  /// Syncs an updated product to Supabase Postgres
  Future<void> syncUpdateProduct(Product product) async {
    if (!hasSupabase) return;
    try {
      await _supabase
          .from('products')
          .update(product.toSupabaseMap())
          .eq('id', product.id);
    } catch (e) {
      debugPrint('Supabase update product error: $e');
    }
  }

  /// Syncs a deleted product to Supabase Postgres
  Future<void> syncDeleteProduct(String id) async {
    if (!hasSupabase) return;
    try {
      await _supabase.from('products').delete().eq('id', id);
    } catch (e) {
      debugPrint('Supabase delete product error: $e');
    }
  }

  /// Syncs an added category to Supabase Postgres
  Future<void> syncAddCategory(ShopCategory category) async {
    if (!hasSupabase) return;
    try {
      await _supabase.from('categories').upsert(category.toSupabaseMap());
    } catch (e) {
      debugPrint('Supabase add category error: $e');
    }
  }

  /// Syncs an updated category to Supabase Postgres
  Future<void> syncUpdateCategory(ShopCategory category) async {
    if (!hasSupabase) return;
    try {
      await _supabase
          .from('categories')
          .update(category.toSupabaseMap())
          .eq('id', category.id);
    } catch (e) {
      debugPrint('Supabase update category error: $e');
    }
  }

  /// Syncs a deleted category to Supabase Postgres
  Future<void> syncDeleteCategory(String id) async {
    if (!hasSupabase) return;
    try {
      await _supabase.from('categories').delete().eq('id', id);
    } catch (e) {
      debugPrint('Supabase delete category error: $e');
    }
  }
}
