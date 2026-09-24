import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../admin/admin_categories_screen.dart';
import '../../admin/admin_dashboard_screen.dart';
import '../../admin/admin_orders_screen.dart';
import '../../admin/admin_product_form_screen.dart';
import '../../screens/cart_screen.dart';
import '../../screens/checkout_screen.dart';
import '../../screens/home_shell.dart';
import '../../screens/login_screen.dart';
import '../../screens/order_confirmation_screen.dart';
import '../../screens/product_detail_screen.dart';
import '../../screens/products_screen.dart';
import '../../screens/register_screen.dart';
import '../../screens/wishlist_screen.dart';
import '../../screens/chatbot_screen.dart';
import 'app_routes.dart';

/// ShopHub AppPages
/// Maps routes defined in [AppRoutes] to their respective Widget builders and GetPages.
abstract class AppPages {
  static const String initial = AppRoutes.initial;

  /// GetX Pages table
  static final List<GetPage> pages = [
    // Customer Pages
    GetPage(
      name: AppRoutes.home,
      page: () => const HomeShell(),
    ),
    GetPage(
      name: AppRoutes.products,
      page: () => const ProductsScreen(),
    ),
    GetPage(
      name: AppRoutes.productDetail,
      page: () => const ProductDetailScreen(),
    ),
    GetPage(
      name: AppRoutes.cart,
      page: () => const CartScreen(),
    ),
    GetPage(
      name: AppRoutes.wishlist,
      page: () => const WishlistScreen(),
    ),
    GetPage(
      name: AppRoutes.checkout,
      page: () => const CheckoutScreen(),
    ),
    GetPage(
      name: AppRoutes.orderConfirmation,
      page: () => const OrderConfirmationScreen(),
    ),
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginScreen(),
    ),
    GetPage(
      name: AppRoutes.register,
      page: () => const RegisterScreen(),
    ),
    GetPage(
      name: AppRoutes.chatbot,
      page: () => const ChatbotScreen(),
    ),

    // Admin Pages
    GetPage(
      name: AppRoutes.adminDashboard,
      page: () => const AdminDashboardScreen(),
    ),
    GetPage(
      name: AppRoutes.adminProductForm,
      page: () => const AdminProductFormScreen(),
    ),
    GetPage(
      name: AppRoutes.adminCategories,
      page: () => const AdminCategoriesScreen(),
    ),
    GetPage(
      name: AppRoutes.adminOrders,
      page: () => const AdminOrdersScreen(),
    ),
  ];

  /// Application route table for backwards compatibility
  static Map<String, WidgetBuilder> get routes => {
        // Customer Pages
        AppRoutes.home: (_) => const HomeShell(),
        AppRoutes.products: (_) => const ProductsScreen(),
        AppRoutes.productDetail: (_) => const ProductDetailScreen(),
        AppRoutes.cart: (_) => const CartScreen(),
        AppRoutes.wishlist: (_) => const WishlistScreen(),
        AppRoutes.checkout: (_) => const CheckoutScreen(),
        AppRoutes.orderConfirmation: (_) => const OrderConfirmationScreen(),
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.register: (_) => const RegisterScreen(),
        AppRoutes.chatbot: (_) => const ChatbotScreen(),

        // Admin Pages
        AppRoutes.adminDashboard: (_) => const AdminDashboardScreen(),
        AppRoutes.adminProductForm: (_) => const AdminProductFormScreen(),
        AppRoutes.adminCategories: (_) => const AdminCategoriesScreen(),
        AppRoutes.adminOrders: (_) => const AdminOrdersScreen(),
      };

  /// Optional route generator for dynamic transitions or unknown routes
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final builder = routes[settings.name];
    if (builder != null) {
      return MaterialPageRoute(
        builder: builder,
        settings: settings,
      );
    }
    // Fallback to home
    return MaterialPageRoute(
      builder: (_) => const HomeShell(),
      settings: settings,
    );
  }
}
