import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shophub/app/routes/app_routes.dart';
import 'package:shophub/controllers/auth_controller.dart';
import 'package:shophub/controllers/cart_controller.dart';
import 'package:shophub/controllers/coupon_controller.dart';
import 'package:shophub/controllers/order_controller.dart';
import 'package:shophub/controllers/product_controller.dart';
import 'package:shophub/controllers/wishlist_controller.dart';
import 'package:shophub/data/mock_catalog.dart';
import 'package:shophub/models/cart_item.dart';
import 'package:shophub/models/order.dart';
import 'package:shophub/screens/order_confirmation_screen.dart';
import 'package:shophub/screens/profile_screen.dart';
import 'package:shophub/screens/receipt_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Payment Receipt Generation & UI Integration Tests', () {
    late AuthController authCtrl;
    late ProductController productCtrl;
    late OrderController orderCtrl;
    late CouponController couponCtrl;
    late CartController cartCtrl;
    late WishlistController wishlistCtrl;

    late ShopOrder stripeOrder;
    late ShopOrder codOrder;

    setUp(() {
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

      stripeOrder = ShopOrder(
        id: 'SH-7701',
        userId: MockCatalog.demoCustomer.id,
        customerName: 'Ayesha Khan',
        customerEmail: 'customer@shophub.com',
        phone: '03219876543',
        address: 'House 42, Street 8, Islamabad',
        paymentMethod: 'Stripe (Card: **** 4242)',
        items: [
          CartItem(
            product: MockCatalog.products[0],
            quantity: 1,
          ),
        ],
        total: 4999,
        createdAt: DateTime(2026, 9, 30, 12, 0),
        status: OrderStatus.placed,
        stripePaymentId: 'pi_3PtestStripeIntent7701',
        paymentStatus: 'Paid',
        deliveryFee: 0,
      );

      codOrder = ShopOrder(
        id: 'SH-7702',
        userId: MockCatalog.demoCustomer.id,
        customerName: 'Bilal Ahmed',
        customerEmail: 'bilal@example.com',
        phone: '03001234567',
        address: 'House 12, Lahore',
        paymentMethod: 'Cash on Delivery',
        items: [
          CartItem(
            product: MockCatalog.products[1],
            quantity: 1,
          ),
        ],
        total: 5000,
        createdAt: DateTime(2026, 9, 30, 12, 5),
        status: OrderStatus.placed,
        paymentStatus: 'Pending',
        deliveryFee: 0,
      );

      orderCtrl.setOrdersForTesting([stripeOrder, codOrder], MockCatalog.demoCustomer.id);
    });

    tearDown(() {
      Get.reset();
    });

    testWidgets('OrderConfirmationScreen displays View Receipt & action buttons for Stripe order',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) {
            if (settings.name == AppRoutes.receipt) {
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => const Scaffold(body: Text('Receipt Screen')),
              );
            }
            return MaterialPageRoute(
              settings: RouteSettings(
                name: AppRoutes.orderConfirmation,
                arguments: stripeOrder.id,
              ),
              builder: (_) => const OrderConfirmationScreen(),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      // Verify order confirmation details
      expect(find.text('Order ID  ${stripeOrder.id}'), findsOneWidget);
      expect(find.text('Payment Receipt'), findsOneWidget);
      expect(find.text('Confirmed via Stripe • Official Black & White Receipt'), findsOneWidget);

      // Verify receipt action buttons exist
      expect(find.byKey(const ValueKey('view_receipt_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('download_receipt_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('share_receipt_button')), findsOneWidget);

      // Verify Stripe Ref ID and Paid status
      expect(find.text('Stripe Ref: ${stripeOrder.stripePaymentId}'), findsOneWidget);
      expect(find.text('Payment Status: Paid'), findsOneWidget);

      // Verify tapping View Receipt navigates to receipt route
      await tester.tap(find.byKey(const ValueKey('view_receipt_button')));
      await tester.pumpAndSettle();
      expect(find.text('Receipt Screen'), findsOneWidget);
    });

    testWidgets('OrderConfirmationScreen does NOT display receipt buttons for Cash on Delivery',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              settings: RouteSettings(
                name: AppRoutes.orderConfirmation,
                arguments: codOrder.id,
              ),
              builder: (_) => const OrderConfirmationScreen(),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Order ID  ${codOrder.id}'), findsOneWidget);
      expect(find.text('Payment Receipt'), findsNothing);
      expect(find.byKey(const ValueKey('view_receipt_button')), findsNothing);
      expect(find.byKey(const ValueKey('download_receipt_button')), findsNothing);
      expect(find.text('Payment Status: Pending'), findsOneWidget);
    });

    testWidgets('ReceiptScreen renders black-and-white paper receipt with complete details and action buttons',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              settings: RouteSettings(
                name: AppRoutes.receipt,
                arguments: stripeOrder,
              ),
              builder: (_) => const ReceiptScreen(),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Receipt #${stripeOrder.id}'), findsOneWidget);
      expect(find.text('S H O P H U B'), findsOneWidget);
      expect(find.text('PAYMENT RECEIPT'), findsOneWidget);
      expect(find.text('STATUS: PAID'), findsOneWidget);

      // Verify product items listed
      expect(find.text(MockCatalog.products[0].name), findsOneWidget);

      // Verify financial breakdown
      expect(find.text('TOTAL PAID'), findsOneWidget);
      expect(find.text('* ${stripeOrder.id} *'), findsOneWidget);

      // Verify bottom action buttons
      expect(find.byKey(const ValueKey('save_receipt_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('share_receipt_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('print_receipt_button')), findsOneWidget);

      // Verify app bar actions
      expect(find.byKey(const ValueKey('save_receipt_appbar_action')), findsOneWidget);
      expect(find.byKey(const ValueKey('share_receipt_appbar_action')), findsOneWidget);
      expect(find.byKey(const ValueKey('print_receipt_appbar_action')), findsOneWidget);
    });

    testWidgets('ProfileScreen shows Receipt button strictly on Stripe-paid orders',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      authCtrl.setCurrentUser(MockCatalog.demoCustomer);

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            AppRoutes.receipt: (_) => const Scaffold(body: Text('Receipt Screen')),
            AppRoutes.orderConfirmation: (_) => const Scaffold(body: Text('Order Confirmation')),
            AppRoutes.wishlist: (_) => const Scaffold(body: Text('Wishlist')),
            AppRoutes.supportChat: (_) => const Scaffold(body: Text('Support Chat')),
          },
          home: const ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Find Stripe order receipt button
      expect(find.byKey(ValueKey('order_receipt_button_${stripeOrder.id}')), findsOneWidget);

      // Cash on Delivery order should NOT have receipt button
      expect(find.byKey(ValueKey('order_receipt_button_${codOrder.id}')), findsNothing);

      // Tapping receipt button navigates to receipt screen
      await tester.tap(find.byKey(ValueKey('order_receipt_button_${stripeOrder.id}')));
      await tester.pumpAndSettle();
      expect(find.text('Receipt Screen'), findsOneWidget);
    });
  });
}
