import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shophub/admin/admin_login_screen.dart';
import 'package:shophub/admin/admin_portal_screen.dart';
import 'package:shophub/app/routes/app_routes.dart';
import 'package:shophub/controllers/auth_controller.dart';
import 'package:shophub/controllers/cart_controller.dart';
import 'package:shophub/controllers/coupon_controller.dart';
import 'package:shophub/controllers/order_controller.dart';
import 'package:shophub/controllers/product_controller.dart';
import 'package:shophub/controllers/wishlist_controller.dart';
import 'package:shophub/data/mock_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AuthController authCtrl;
  late ProductController productCtrl;
  late OrderController orderCtrl;
  late CouponController couponCtrl;
  late CartController cartCtrl;
  late WishlistController wishlistCtrl;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    authCtrl = AuthController()..init();
    productCtrl = ProductController()..init();
    orderCtrl = OrderController()..init();
    couponCtrl = CouponController()..init();
    cartCtrl = CartController()..init();
    wishlistCtrl = WishlistController()..init();

    Get.put(authCtrl);
    Get.put(productCtrl);
    Get.put(orderCtrl);
    Get.put(couponCtrl);
    Get.put(cartCtrl);
    Get.put(wishlistCtrl);
  });

  test('CouponController manages coupons and validates discounts accurately', () {
    expect(couponCtrl.coupons.isNotEmpty, isTrue);

    // Verify preset CUPON15 has 30% discount as requested
    final cupon15 = couponCtrl.findCoupon('CUPON15');
    expect(cupon15, isNotNull);
    expect(cupon15!.discountPercent, 30);
    expect(couponCtrl.calculateDiscount('CUPON15', 1000), 300.0);

    // Initial preset coupons test
    final coupon = couponCtrl.coupons.firstWhere((c) => c.code == 'SHOPHUB20');
    expect(coupon.discountPercent, 20);

    // Validate discount
    final discount = couponCtrl.calculateDiscount('SHOPHUB20', 2000);
    expect(discount, 400.0); // 20% of 2000

    // Below minimum order amount returns null
    final lowDiscount = couponCtrl.calculateDiscount('SHOPHUB20', 1000);
    expect(lowDiscount, isNull);

    // Add new coupon with custom date & time validity
    final customExpiry = DateTime(2027, 5, 20, 23, 59);
    couponCtrl.addCoupon(
      code: 'TEST50',
      discountPercent: 50,
      minOrderAmount: 1000,
      expiryDate: customExpiry,
    );
    expect(couponCtrl.coupons.any((c) => c.code == 'TEST50'), isTrue);
    final added = couponCtrl.findCoupon('TEST50')!;
    expect(added.expiryDate, customExpiry);

    // Toggle status
    final newC = couponCtrl.coupons.firstWhere((c) => c.code == 'TEST50');
    expect(newC.isActive, isTrue);
    couponCtrl.toggleCouponStatus(newC.id);
    expect(couponCtrl.coupons.firstWhere((c) => c.code == 'TEST50').isActive, isFalse);

    // Inactive coupon should not yield discount
    expect(couponCtrl.calculateDiscount('TEST50', 2000), isNull);

    // Delete coupon
    couponCtrl.deleteCoupon(newC.id);
    expect(couponCtrl.coupons.any((c) => c.code == 'TEST50'), isFalse);
  });

  test('CartController applies CUPON15 and calculates 30% discount correctly', () {
    cartCtrl.addToCart(MockCatalog.products[0], qty: 2); // 3499 * 2 = 6998
    expect(cartCtrl.cartTotal, 6998.0);

    // Apply CUPON15
    final err = cartCtrl.applyCoupon('CUPON15', couponCtrl);
    expect(err, isNull);
    expect(cartCtrl.appliedCoupon?.code, 'CUPON15');

    // 30% of 6998 = 2099.4
    expect(cartCtrl.discountAmount, closeTo(2099.4, 0.01));
    expect(cartCtrl.finalTotal, closeTo(6998.0 - 2099.4, 0.01));

    // Place order with coupon
    final order = orderCtrl.placeOrder(
      name: 'Test Customer',
      phone: '03001234567',
      address: 'Test Address',
      items: cartCtrl.cart,
      total: cartCtrl.finalTotal,
      couponCode: cartCtrl.appliedCoupon?.code,
      discountAmount: cartCtrl.discountAmount,
    );

    expect(order.couponCode, 'CUPON15');
    expect(order.discountAmount, closeTo(2099.4, 0.01));
    expect(order.total, closeTo(4898.6, 0.01));

    // Usage count increment
    final prevUsage = couponCtrl.findCoupon('CUPON15')?.usageCount ?? 0;
    couponCtrl.incrementUsageCount('CUPON15');
    expect(couponCtrl.findCoupon('CUPON15')?.usageCount, prevUsage + 1);

    // Remove coupon
    cartCtrl.removeCoupon();
    expect(cartCtrl.appliedCoupon, isNull);
    expect(cartCtrl.discountAmount, 0.0);
    expect(cartCtrl.finalTotal, 6998.0);
  });

  testWidgets('AdminLoginScreen denies access to non-admin and authenticates Super Admin',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.adminLogin,
        routes: {
          AppRoutes.adminLogin: (_) => const AdminLoginScreen(),
          AppRoutes.adminDashboard: (_) => const AdminPortalScreen(),
        },
      ),
    );
    await tester.pumpAndSettle();

    // Verify title and branding
    expect(find.text('Super Admin Login'), findsOneWidget);

    // Verify fields are blank on initial load - NO AUTOFILL!
    final emailField = find.widgetWithText(TextField, 'admin@shophub.com');
    final passField = find.widgetWithText(TextField, '••••••••');
    expect(tester.widget<TextField>(emailField).controller?.text, '');
    expect(tester.widget<TextField>(passField).controller?.text, '');

    // Enter customer credentials
    await tester.enterText(emailField, MockCatalog.demoCustomer.email);
    await tester.enterText(passField, MockCatalog.demoCustomer.password);

    // Tap Authenticate
    await tester.tap(find.text('Authenticate as Super Admin'));
    await tester.pumpAndSettle();

    // Access should be strictly denied for customer!
    expect(
      find.text('Access Denied: This portal is restricted to Super Administrators only.'),
      findsOneWidget,
    );

    // Now test quick-fill Super Admin
    await tester.tap(find.text('Quick-fill Super Admin (admin@shophub.com)'));
    await tester.pumpAndSettle();

    // Tap Authenticate again with super admin credentials
    await tester.tap(find.text('Authenticate as Super Admin'));
    await tester.pumpAndSettle();

    // Successfully transitioned to Admin Portal
    expect(find.text('Super Admin Portal'), findsWidgets);
    expect(find.text('Executive Store Overview'), findsOneWidget);
  });

  testWidgets('AdminPortalScreen displays live dashboard KPIs, orders, and payment split',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Set logged-in user as Super Admin
    authCtrl.setCurrentUser(MockCatalog.admin);

    await tester.pumpWidget(
      const GetMaterialApp(
        home: AdminPortalScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify executive KPI cards
    expect(find.text('Total Earnings'), findsOneWidget);
    expect(find.text('Total Orders'), findsOneWidget);
    expect(find.text('Average Order Value'), findsOneWidget);
    expect(find.text('Catalog Inventory'), findsOneWidget);

    // Verify Weekly vs Monthly Comparison
    expect(find.text('Weekly & Monthly Earnings Summary'), findsOneWidget);
    expect(find.text('Payment Methods Breakdown'), findsOneWidget);

    // Verify Payment methods
    expect(find.text('Online Stripe Card Payments'), findsOneWidget);
    expect(find.text('Cash on Delivery (COD)'), findsOneWidget);

    // Verify Recent Orders Summary
    expect(find.text('Recent Orders Summary'), findsOneWidget);
    expect(find.text('SH-8821'), findsOneWidget);

    // Test Navigation to Orders tab
    await tester.tap(find.text('Orders & Details').first);
    await tester.pumpAndSettle();
    expect(find.text('Search Order ID or Customer...'), findsOneWidget);

    // Test Navigation to Coupons tab
    await tester.tap(find.text('Coupons & Promos').first);
    await tester.pumpAndSettle();
    expect(find.text('Create New Coupon'), findsOneWidget);
    expect(find.text('SHOPHUB20'), findsOneWidget);

    // Test Navigation to Customers & Users tab
    await tester.tap(find.text('Customers & Users').first);
    await tester.pumpAndSettle();
    expect(find.text('Registered Customers & Administrators'), findsOneWidget);
    expect(find.text('ShopHub Admin'), findsOneWidget);
    expect(find.text('Ayesha Khan'), findsOneWidget);
  });
}
