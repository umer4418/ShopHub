import 'package:flutter/material.dart';

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
import 'app_routes.dart';

/// ShopHub AppPages
/// Maps routes defined in [AppRoutes] to their respective Widget builders.
abstract class AppPages {
  static const String initial = AppRoutes.initial;

  /// Application route table
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
