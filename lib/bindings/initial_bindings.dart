import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/auth_controller.dart';
import '../controllers/cart_controller.dart';
import '../controllers/order_controller.dart';
import '../controllers/product_controller.dart';
import '../controllers/wishlist_controller.dart';
import '../controllers/chatbot_controller.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/order_service.dart';
import '../services/product_service.dart';
import '../services/wishlist_service.dart';
import '../services/chatbot_service.dart';

/// Initial Bindings
/// Configures and initializes all services and controllers for dependency injection via GetX.
class InitialBindings extends Bindings {
  final AuthService authService;
  final ProductService productService;
  final CartService cartService;
  final WishlistService wishlistService;
  final OrderService orderService;
  final ChatbotService chatbotService;

  final AuthController authController;
  final ProductController productController;
  final CartController cartController;
  final WishlistController wishlistController;
  final OrderController orderController;
  final ChatbotController chatbotController;

  InitialBindings._({
    required this.authService,
    required this.productService,
    required this.cartService,
    required this.wishlistService,
    required this.orderService,
    required this.chatbotService,
    required this.authController,
    required this.productController,
    required this.cartController,
    required this.wishlistController,
    required this.orderController,
    required this.chatbotController,
  });

  @override
  void dependencies() {
    _registerDependencies(this);
  }

  static void _registerDependencies(InitialBindings b) {
    _put<AuthService>(b.authService);
    _put<ProductService>(b.productService);
    _put<CartService>(b.cartService);
    _put<WishlistService>(b.wishlistService);
    _put<OrderService>(b.orderService);
    _put<ChatbotService>(b.chatbotService);

    _put<AuthController>(b.authController);
    _put<ProductController>(b.productController);
    _put<CartController>(b.cartController);
    _put<WishlistController>(b.wishlistController);
    _put<OrderController>(b.orderController);
    _put<ChatbotController>(b.chatbotController);
  }

  static void _put<T>(T instance) {
    if (Get.isRegistered<T>()) {
      Get.replace<T>(instance);
    } else {
      Get.put<T>(instance, permanent: true);
    }
  }

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

    final chatbotService = ChatbotService();
    await chatbotService.init(prefs);

    final authController = AuthController(authService: authService)..init();
    final productController = ProductController(productService: productService)..init();
    final cartController = CartController(cartService: cartService)..init();
    final wishlistController = WishlistController(wishlistService: wishlistService)..init();
    final orderController = OrderController(orderService: orderService)..init();
    final chatbotController = ChatbotController(service: chatbotService)..init();

    final bindings = InitialBindings._(
      authService: authService,
      productService: productService,
      cartService: cartService,
      wishlistService: wishlistService,
      orderService: orderService,
      chatbotService: chatbotService,
      authController: authController,
      productController: productController,
      cartController: cartController,
      wishlistController: wishlistController,
      orderController: orderController,
      chatbotController: chatbotController,
    );

    _registerDependencies(bindings);
    return bindings;
  }

  /// Create a synchronous instance (e.g. for testing with in-memory defaults)
  factory InitialBindings.sync({
    AuthController? authController,
    ProductController? productController,
    CartController? cartController,
    WishlistController? wishlistController,
    OrderController? orderController,
    ChatbotController? chatbotController,
  }) {
    final aService = AuthService();
    final pService = ProductService();
    final cService = CartService();
    final wService = WishlistService();
    final oService = OrderService();
    final cbService = ChatbotService();

    final aCtrl = authController ?? AuthController(authService: aService);
    final pCtrl = productController ?? ProductController(productService: pService);
    final cCtrl = cartController ?? CartController(cartService: cService);
    final wCtrl = wishlistController ?? WishlistController(wishlistService: wService);
    final oCtrl = orderController ?? OrderController(orderService: oService);
    final cbCtrl = chatbotController ?? ChatbotController(service: cbService);

    final bindings = InitialBindings._(
      authService: aService,
      productService: pService,
      cartService: cService,
      wishlistService: wService,
      orderService: oService,
      chatbotService: cbService,
      authController: aCtrl,
      productController: pCtrl,
      cartController: cCtrl,
      wishlistController: wCtrl,
      orderController: oCtrl,
      chatbotController: cbCtrl,
    );

    _registerDependencies(bindings);
    return bindings;
  }
}
