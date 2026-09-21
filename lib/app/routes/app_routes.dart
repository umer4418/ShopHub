/// ShopHub Route Definitions
/// Contains static constants for all route names used across the application.
abstract class AppRoutes {
  static const String initial = home;

  // Customer Routes
  static const String home = '/';
  static const String products = '/products';
  static const String productDetail = '/product';
  static const String cart = '/cart';
  static const String wishlist = '/wishlist';
  static const String checkout = '/checkout';
  static const String orderConfirmation = '/order';
  static const String login = '/login';
  static const String register = '/register';

  // Admin Routes
  static const String adminDashboard = '/admin';
  static const String adminProductForm = '/admin/product';
  static const String adminCategories = '/admin/categories';
  static const String adminOrders = '/admin/orders';
}
