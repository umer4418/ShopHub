import 'package:flutter/foundation.dart';

import '../data/mock_catalog.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../services/product_service.dart';

/// Product Controller
/// Manages catalog state, filtering, search, sorting, and admin product/category CRUD.
class ProductController extends ChangeNotifier {
  final ProductService _productService;

  ProductController({ProductService? productService})
      : _productService = productService ?? ProductService();

  List<Product> _products = List.of(MockCatalog.products);
  List<ShopCategory> _categories = List.of(MockCatalog.categories);
  bool _isInitialized = false;

  String _searchQuery = '';
  String? _filterCategoryId;
  double _minPrice = 0;
  double _maxPrice = 200000;
  double _minRating = 0;
  String _sortBy = 'popular';

  List<Product> get products => List.unmodifiable(_products);
  List<ShopCategory> get categories => List.unmodifiable(_categories);
  bool get isInitialized => _isInitialized;

  String get searchQuery => _searchQuery;
  String? get filterCategoryId => _filterCategoryId;
  double get minPrice => _minPrice;
  double get maxPrice => _maxPrice;
  double get minRating => _minRating;
  String get sortBy => _sortBy;

  List<Product> get featured => _products.where((p) => p.featured).toList();
  List<Product> get popular => _products.where((p) => p.popular).toList();

  ShopCategory? categoryById(String id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Product? productById(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Product> get filteredProducts {
    var list = _products.where((p) {
      final q = _searchQuery.trim().toLowerCase();
      final matchesQuery = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.shortDescription.toLowerCase().contains(q);
      final matchesCat =
          _filterCategoryId == null || p.categoryId == _filterCategoryId;
      final matchesPrice = p.price >= _minPrice && p.price <= _maxPrice;
      final matchesRating = p.rating >= _minRating;
      return matchesQuery && matchesCat && matchesPrice && matchesRating;
    }).toList();

    switch (_sortBy) {
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

  void init() {
    _products = _productService.loadProducts();
    _categories = _productService.loadCategories();
    _isInitialized = true;
    notifyListeners();
  }

  void setSearch(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void setFilters({
    String? categoryId,
    bool clearCategory = false,
    double? min,
    double? max,
    double? rating,
    String? sort,
  }) {
    if (clearCategory) _filterCategoryId = null;
    if (categoryId != null) _filterCategoryId = categoryId;
    if (min != null) _minPrice = min;
    if (max != null) _maxPrice = max;
    if (rating != null) _minRating = rating;
    if (sort != null) _sortBy = sort;
    notifyListeners();
  }

  void resetFilters() {
    _searchQuery = '';
    _filterCategoryId = null;
    _minPrice = 0;
    _maxPrice = 200000;
    _minRating = 0;
    _sortBy = 'popular';
    notifyListeners();
  }

  void addProduct(Product product) {
    _products.insert(0, product);
    _productService.saveProducts(_products);
    notifyListeners();
  }

  void updateProduct(Product product) {
    final i = _products.indexWhere((p) => p.id == product.id);
    if (i >= 0) {
      _products[i] = product;
      _productService.saveProducts(_products);
      notifyListeners();
    }
  }

  void deleteProduct(String id) {
    _products.removeWhere((p) => p.id == id);
    _productService.saveProducts(_products);
    notifyListeners();
  }

  void addCategory(ShopCategory category) {
    _categories.add(category);
    _productService.saveCategories(_categories);
    notifyListeners();
  }

  void updateCategory(ShopCategory category) {
    final i = _categories.indexWhere((c) => c.id == category.id);
    if (i >= 0) {
      _categories[i] = category;
      _productService.saveCategories(_categories);
      notifyListeners();
    }
  }

  void deleteCategory(String id) {
    _categories.removeWhere((c) => c.id == id);
    _productService.saveCategories(_categories);
    notifyListeners();
  }
}
