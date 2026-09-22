import 'package:get/get.dart';

import '../data/mock_catalog.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../services/product_service.dart';

/// Product Controller
/// Manages catalog state, filtering, search, sorting, and admin product/category CRUD.
class ProductController extends GetxController {
  final ProductService _productService;

  ProductController({ProductService? productService})
      : _productService = productService ?? ProductService();

  static ProductController get to => Get.find<ProductController>();

  final RxList<Product> _products = List.of(MockCatalog.products).obs;
  final RxList<ShopCategory> _categories = List.of(MockCatalog.categories).obs;
  final RxBool _isInitialized = false.obs;

  final RxString _searchQuery = ''.obs;
  final RxnString _filterCategoryId = RxnString();
  final RxDouble _minPrice = 0.0.obs;
  final RxDouble _maxPrice = 200000.0.obs;
  final RxDouble _minRating = 0.0.obs;
  final RxString _sortBy = 'popular'.obs;

  List<Product> get products => List.unmodifiable(_products);
  List<ShopCategory> get categories => List.unmodifiable(_categories);
  bool get isInitialized => _isInitialized.value;

  String get searchQuery => _searchQuery.value;
  String? get filterCategoryId => _filterCategoryId.value;
  double get minPrice => _minPrice.value;
  double get maxPrice => _maxPrice.value;
  double get minRating => _minRating.value;
  String get sortBy => _sortBy.value;

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
      final q = _searchQuery.value.trim().toLowerCase();
      final matchesQuery = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.shortDescription.toLowerCase().contains(q);
      final matchesCat =
          _filterCategoryId.value == null || p.categoryId == _filterCategoryId.value;
      final matchesPrice = p.price >= _minPrice.value && p.price <= _maxPrice.value;
      final matchesRating = p.rating >= _minRating.value;
      return matchesQuery && matchesCat && matchesPrice && matchesRating;
    }).toList();

    switch (_sortBy.value) {
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
    _products.assignAll(_productService.loadProducts());
    _categories.assignAll(_productService.loadCategories());
    _isInitialized.value = true;
    update();
    _refreshFromSupabase();
  }

  Future<void> _refreshFromSupabase() async {
    try {
      final pList = await _productService.fetchProductsFromSupabase();
      if (pList.isNotEmpty) {
        _products.assignAll(pList);
        update();
      }
      final cList = await _productService.fetchCategoriesFromSupabase();
      if (cList.isNotEmpty) {
        _categories.assignAll(cList);
        update();
      }
    } catch (_) {}
  }

  void setSearch(String q) {
    _searchQuery.value = q;
    update();
  }

  void setFilters({
    String? categoryId,
    bool clearCategory = false,
    double? min,
    double? max,
    double? rating,
    String? sort,
  }) {
    if (clearCategory) _filterCategoryId.value = null;
    if (categoryId != null) _filterCategoryId.value = categoryId;
    if (min != null) _minPrice.value = min;
    if (max != null) _maxPrice.value = max;
    if (rating != null) _minRating.value = rating;
    if (sort != null) _sortBy.value = sort;
    update();
  }

  void resetFilters() {
    _searchQuery.value = '';
    _filterCategoryId.value = null;
    _minPrice.value = 0;
    _maxPrice.value = 200000;
    _minRating.value = 0;
    _sortBy.value = 'popular';
    update();
  }

  void addProduct(Product product) {
    _products.insert(0, product);
    _productService.saveProducts(_products);
    _productService.syncAddProduct(product);
    update();
  }

  void updateProduct(Product product) {
    final i = _products.indexWhere((p) => p.id == product.id);
    if (i >= 0) {
      _products[i] = product;
      _productService.saveProducts(_products);
      _productService.syncUpdateProduct(product);
      update();
    }
  }

  void deleteProduct(String id) {
    _products.removeWhere((p) => p.id == id);
    _productService.saveProducts(_products);
    _productService.syncDeleteProduct(id);
    update();
  }

  void addCategory(ShopCategory category) {
    _categories.add(category);
    _productService.saveCategories(_categories);
    _productService.syncAddCategory(category);
    update();
  }

  void updateCategory(ShopCategory category) {
    final i = _categories.indexWhere((c) => c.id == category.id);
    if (i >= 0) {
      _categories[i] = category;
      _productService.saveCategories(_categories);
      _productService.syncUpdateCategory(category);
      update();
    }
  }

  void deleteCategory(String id) {
    _categories.removeWhere((c) => c.id == id);
    _productService.saveCategories(_categories);
    _productService.syncDeleteCategory(id);
    update();
  }
}
