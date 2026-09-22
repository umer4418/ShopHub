import 'package:flutter_test/flutter_test.dart';
import 'package:shophub/app/routes/app_pages.dart';
import 'package:shophub/app/routes/app_routes.dart';
import 'package:shophub/controllers/auth_controller.dart';
import 'package:shophub/controllers/cart_controller.dart';
import 'package:shophub/controllers/order_controller.dart';
import 'package:shophub/controllers/product_controller.dart';
import 'package:shophub/controllers/wishlist_controller.dart';
import 'package:shophub/models/cart_item.dart';
import 'package:shophub/models/category.dart';
import 'package:shophub/models/order.dart';
import 'package:shophub/models/product.dart';

void main() {
  group('AppRoutes & AppPages', () {
    test('routes table contains all expected routes', () {
      final routes = AppPages.routes;
      expect(routes.containsKey(AppRoutes.home), isTrue);
      expect(routes.containsKey(AppRoutes.products), isTrue);
      expect(routes.containsKey(AppRoutes.productDetail), isTrue);
      expect(routes.containsKey(AppRoutes.cart), isTrue);
      expect(routes.containsKey(AppRoutes.wishlist), isTrue);
      expect(routes.containsKey(AppRoutes.checkout), isTrue);
      expect(routes.containsKey(AppRoutes.orderConfirmation), isTrue);
      expect(routes.containsKey(AppRoutes.login), isTrue);
      expect(routes.containsKey(AppRoutes.register), isTrue);
      expect(routes.containsKey(AppRoutes.adminDashboard), isTrue);
      expect(routes.containsKey(AppRoutes.adminProductForm), isTrue);
      expect(routes.containsKey(AppRoutes.adminCategories), isTrue);
      expect(routes.containsKey(AppRoutes.adminOrders), isTrue);
    });
  });

  group('AuthController (MVC Controller)', () {
    late AuthController authCtrl;

    setUp(() {
      authCtrl = AuthController()..init();
    });

    test('initial state has default demo users', () {
      expect(authCtrl.users.isNotEmpty, isTrue);
      expect(authCtrl.currentUser, isNull);
      expect(authCtrl.isLoggedIn, isFalse);
    });

    test('login with valid credentials succeeds', () async {
      final err = await authCtrl.login('customer@shophub.com', 'user123');
      expect(err, isNull);
      expect(authCtrl.isLoggedIn, isTrue);
      expect(authCtrl.currentUser?.email, 'customer@shophub.com');
      expect(authCtrl.isAdmin, isFalse);
    });

    test('login with admin credentials sets isAdmin true', () async {
      final err = await authCtrl.login('admin@shophub.com', 'admin123');
      expect(err, isNull);
      expect(authCtrl.isLoggedIn, isTrue);
      expect(authCtrl.isAdmin, isTrue);
    });

    test('login with invalid credentials fails', () async {
      final err = await authCtrl.login('wrong@shophub.com', 'badpass');
      expect(err, isNotNull);
      expect(authCtrl.isLoggedIn, isFalse);
    });

    test('register and logout', () async {
      final err = await authCtrl.register(
        name: 'Jane Doe',
        email: 'jane@example.com',
        password: 'pass123',
        phone: '03001234567',
      );
      expect(err, isNull);
      expect(authCtrl.isLoggedIn, isTrue);
      expect(authCtrl.currentUser?.name, 'Jane Doe');
      expect(authCtrl.isAdmin, isFalse);

      await authCtrl.logout();
      expect(authCtrl.isLoggedIn, isFalse);
      expect(authCtrl.currentUser, isNull);
    });

    test('register as admin sets isAdmin true', () async {
      final err = await authCtrl.register(
        name: 'Admin Joe',
        email: 'adminjoe@example.com',
        password: 'pass123',
        phone: '03001234567',
        isAdmin: true,
      );
      expect(err, isNull);
      expect(authCtrl.isLoggedIn, isTrue);
      expect(authCtrl.isAdmin, isTrue);
    });
  });

  group('ProductController (MVC Controller)', () {
    late ProductController productCtrl;

    setUp(() {
      productCtrl = ProductController()..init();
    });

    test('loads products and categories', () {
      expect(productCtrl.products.isNotEmpty, isTrue);
      expect(productCtrl.categories.isNotEmpty, isTrue);
      expect(productCtrl.featured.isNotEmpty, isTrue);
      expect(productCtrl.popular.isNotEmpty, isTrue);
    });

    test('search filters product list', () {
      productCtrl.setSearch('iPhone');
      final results = productCtrl.filteredProducts;
      for (final p in results) {
        final matches = p.name.toLowerCase().contains('iphone') ||
            p.shortDescription.toLowerCase().contains('iphone');
        expect(matches, isTrue);
      }
    });

    test('filter by category, price, and sort', () {
      productCtrl.setFilters(
        min: 1000,
        max: 50000,
        sort: 'price_low',
      );
      final list = productCtrl.filteredProducts;
      expect(list.isNotEmpty, isTrue);
      for (var i = 0; i < list.length - 1; i++) {
        expect(list[i].price <= list[i + 1].price, isTrue);
      }
    });

    test('admin product CRUD operations', () {
      const newProduct = Product(
        id: 'test-product-1',
        name: 'Unit Test Gadget',
        categoryId: 'electronics',
        imageUrl: 'https://example.com/test.jpg',
        price: 999.0,
        originalPrice: 1299.0,
        rating: 4.8,
        reviewCount: 10,
        shortDescription: 'Great gadget',
        description: 'Detailed gadget description',
        stock: 5,
        featured: true,
        popular: true,
      );

      productCtrl.addProduct(newProduct);
      expect(productCtrl.productById('test-product-1'), isNotNull);

      final updated = newProduct.copyWith(name: 'Updated Gadget');
      productCtrl.updateProduct(updated);
      expect(productCtrl.productById('test-product-1')?.name, 'Updated Gadget');

      productCtrl.deleteProduct('test-product-1');
      expect(productCtrl.productById('test-product-1'), isNull);
    });

    test('admin category CRUD operations', () {
      const newCat = ShopCategory(
        id: 'test-cat',
        name: 'Test Category',
        icon: 'devices',
        imageUrl: '',
      );

      productCtrl.addCategory(newCat);
      expect(productCtrl.categoryById('test-cat'), isNotNull);

      productCtrl.deleteCategory('test-cat');
      expect(productCtrl.categoryById('test-cat'), isNull);
    });
  });

  group('CartController (MVC Controller)', () {
    late CartController cartCtrl;
    const sampleProduct = Product(
      id: 'p-101',
      name: 'Smart Watch',
      categoryId: 'electronics',
      imageUrl: 'https://example.com/watch.jpg',
      price: 5000.0,
      originalPrice: 6000.0,
      rating: 4.5,
      reviewCount: 12,
      shortDescription: 'Fitness tracker',
      description: 'Smart watch with heart rate sensor',
      stock: 10,
      featured: true,
      popular: false,
    );

    setUp(() {
      cartCtrl = CartController()..init();
      cartCtrl.clearCart();
    });

    test('add item, update quantity, and remove item', () {
      expect(cartCtrl.isEmpty, isTrue);
      expect(cartCtrl.cartCount, 0);
      expect(cartCtrl.cartTotal, 0.0);

      cartCtrl.addToCart(sampleProduct, qty: 2);
      expect(cartCtrl.cartCount, 2);
      expect(cartCtrl.cartTotal, 10000.0);

      cartCtrl.setCartQty(sampleProduct.id, 5);
      expect(cartCtrl.cartCount, 5);
      expect(cartCtrl.cartTotal, 25000.0);

      cartCtrl.removeFromCart(sampleProduct.id);
      expect(cartCtrl.isEmpty, isTrue);
      expect(cartCtrl.cartCount, 0);
    });
  });

  group('WishlistController (MVC Controller)', () {
    late WishlistController wishlistCtrl;

    setUp(() {
      wishlistCtrl = WishlistController()..init();
    });

    test('toggle wishlist', () {
      const pid = 'prod-test-99';
      expect(wishlistCtrl.inWishlist(pid), isFalse);

      wishlistCtrl.toggleWishlist(pid);
      expect(wishlistCtrl.inWishlist(pid), isTrue);

      wishlistCtrl.toggleWishlist(pid);
      expect(wishlistCtrl.inWishlist(pid), isFalse);
    });
  });

  group('OrderController (MVC Controller)', () {
    late OrderController orderCtrl;
    const sampleProduct = Product(
      id: 'p-order',
      name: 'Order Item',
      categoryId: 'electronics',
      imageUrl: '',
      price: 2500.0,
      originalPrice: 2500.0,
      rating: 4.0,
      reviewCount: 1,
      shortDescription: '',
      description: '',
      stock: 5,
      featured: false,
      popular: false,
    );

    setUp(() {
      orderCtrl = OrderController()..init();
    });

    test('place order and update status', () {
      final order = orderCtrl.placeOrder(
        name: 'Ali Khan',
        phone: '03009876543',
        address: '123 Main Street, Lahore',
        items: [const CartItem(product: sampleProduct, quantity: 2)],
        total: 5000.0,
      );

      expect(order.id.startsWith('SH'), isTrue);
      expect(order.status, OrderStatus.placed);
      expect(orderCtrl.getOrderById(order.id), isNotNull);

      orderCtrl.updateOrderStatus(order.id, OrderStatus.shipped);
      expect(orderCtrl.getOrderById(order.id)?.status, OrderStatus.shipped);
    });
  });
}
