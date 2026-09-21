import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/mock_catalog.dart';
import '../models/category.dart';
import '../models/product.dart';

/// Product Service
/// Handles persistence and retrieval of products and categories.
class ProductService {
  static const _kProducts = 'shophub.products';
  static const _kCategories = 'shophub.categories';

  SharedPreferences? _prefs;

  Future<void> init([SharedPreferences? prefs]) async {
    _prefs = prefs ?? await SharedPreferences.getInstance();
  }

  List<Product> loadProducts() {
    final prefs = _prefs;
    if (prefs == null) return List.of(MockCatalog.products);

    final pJson = prefs.getString(_kProducts);
    if (pJson != null) {
      try {
        final decoded = jsonDecode(pJson) as List;
        return decoded
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return List.of(MockCatalog.products);
      }
    }
    return List.of(MockCatalog.products);
  }

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
}
