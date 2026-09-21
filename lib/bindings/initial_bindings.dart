import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/auth_controller.dart';
import '../controllers/cart_controller.dart';
import '../controllers/order_controller.dart';
import '../controllers/product_controller.dart';
import '../controllers/wishlist_controller.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/order_service.dart';
import '../services/product_service.dart';
import '../services/wishlist_service.dart';
import '../state/shop_store.dart';

/// Initial Bindings
/// Configures and initializes all services and controllers for dependency injection.
class InitialBindings {
  final AuthService authService;
  final ProductService productService;
  final CartService cartService;
  final WishlistService wishlistService;
  final OrderService orderService;

  final AuthController authController;
  final ProductController productController;
  final CartController cartController;
  final WishlistController wishlistController;
  final OrderController orderController;

  InitialBindings._({
    required this.authService,
    required this.productService,
    required this.cartService,
    required this.wishlistService,
    required this.orderService,
    required this.authController,
    required this.productController,
    required this.cartController,
    required this.wishlistController,
    required this.orderController,
  });

  /// Factory that initializes SharedPreferences and loads initial data into controllers.
  static Future<InitialBindings> init([SharedPreferences? sharedPreferences]) async {
    final prefs = sharedPreferences ?? await SharedPreferences.getInstance();

    final authService = AuthService();
    await authService.init(prefs);

    final productService = ProductService();
    await productService.init(prefs);

    final cartService = CartService();
    await cartService.init(prefs);

    final wishlistService = WishlistService();
    await wishlistService.init(prefs);

    final orderService = OrderService();
    await orderService.init(prefs);

    final authController = AuthController(authService: authService)..init();
    final productController = ProductController(productService: productService)..init();
    final cartController = CartController(cartService: cartService)..init();
    final wishlistController = WishlistController(wishlistService: wishlistService)..init();
    final orderController = OrderController(orderService: orderService)..init();

    return InitialBindings._(
      authService: authService,
      productService: productService,
      cartService: cartService,
      wishlistService: wishlistService,
      orderService: orderService,
      authController: authController,
      productController: productController,
      cartController: cartController,
      wishlistController: wishlistController,
      orderController: orderController,
    );
  }

  /// Create a synchronous instance (e.g. for testing with in-memory defaults)
  factory InitialBindings.sync({
    AuthController? authController,
    ProductController? productController,
    CartController? cartController,
    WishlistController? wishlistController,
    OrderController? orderController,
  }) {
    final aService = AuthService();
    final pService = ProductService();
    final cService = CartService();
    final wService = WishlistService();
    final oService = OrderService();

    final aCtrl = authController ?? AuthController(authService: aService);
    final pCtrl = productController ?? ProductController(productService: pService);
    final cCtrl = cartController ?? CartController(cartService: cService);
    final wCtrl = wishlistController ?? WishlistController(wishlistService: wService);
    final oCtrl = orderController ?? OrderController(orderService: oService);

    return InitialBindings._(
      authService: aService,
      productService: pService,
      cartService: cService,
      wishlistService: wService,
      orderService: oService,
      authController: aCtrl,
      productController: pCtrl,
      cartController: cCtrl,
      wishlistController: wCtrl,
      orderController: oCtrl,
    );
  }

  /// Returns the list of providers to inject at the root of the widget tree.
  List<SingleChildWidget> createProviders({ShopStore? store}) {
    // Keep ShopStore for backwards compatibility with any existing components/tests
    final shopStore = store ??
        ShopStore(
          authController: authController,
          productController: productController,
          cartController: cartController,
          wishlistController: wishlistController,
          orderController: orderController,
        );

    return [
      // Services
      Provider<AuthService>.value(value: authService),
      Provider<ProductService>.value(value: productService),
      Provider<CartService>.value(value: cartService),
      Provider<WishlistService>.value(value: wishlistService),
      Provider<OrderService>.value(value: orderService),

      // Controllers
      ChangeNotifierProvider<AuthController>.value(value: authController),
      ChangeNotifierProvider<ProductController>.value(value: productController),
      ChangeNotifierProvider<CartController>.value(value: cartController),
      ChangeNotifierProvider<WishlistController>.value(value: wishlistController),
      ChangeNotifierProvider<OrderController>.value(value: orderController),

      // Backwards compatibility store
      ChangeNotifierProvider<ShopStore>.value(value: shopStore),
    ];
  }
}
