import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shophub/app/routes/app_routes.dart';
import 'package:shophub/controllers/auth_controller.dart';
import 'package:shophub/controllers/cart_controller.dart';
import 'package:shophub/controllers/coupon_controller.dart';
import 'package:shophub/controllers/order_controller.dart';
import 'package:shophub/data/mock_catalog.dart';
import 'package:shophub/screens/checkout_screen.dart';
import 'package:shophub/widgets/shop_product_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CheckoutScreen UI and Asset Loading', () {
    late AuthController authCtrl;
    late CartController cartCtrl;
    late OrderController orderCtrl;
    late CouponController couponCtrl;

    setUp(() {
      Get.reset();
      authCtrl = AuthController()..init();
      cartCtrl = CartController();
      orderCtrl = OrderController();
      couponCtrl = CouponController()..init();

      Get.put(authCtrl);
      Get.put(cartCtrl);
      Get.put(orderCtrl);
      Get.put(couponCtrl);
    });

    tearDown(() {
      Get.reset();
    });

    testWidgets('renders items in order summary using ShopProductImage without asset load errors',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Add products with network URLs (Unsplash) to cart
      cartCtrl.addToCart(MockCatalog.products[0], qty: 1); // Pro Series Smart Watch AMOLED
      cartCtrl.addToCart(MockCatalog.products[1], qty: 1); // Mechanical RGB Gaming Keyboard

      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: AppRoutes.checkout,
          getPages: [
            GetPage(name: AppRoutes.checkout, page: () => const CheckoutScreen()),
          ],
        ),
      );
      await tester.pump();

      // Check header and form fields exist
      expect(find.text('Checkout'), findsOneWidget);
      expect(find.text('Shipping details'), findsOneWidget);
      expect(find.text('Order summary'), findsOneWidget);

      // Check products exist in order summary
      expect(find.text(MockCatalog.products[0].name), findsOneWidget);
      expect(find.text(MockCatalog.products[1].name), findsOneWidget);

      // Ensure ShopProductImage is used instead of failing Image.asset
      expect(find.byType(ShopProductImage), findsNWidgets(2));

      // Ensure no red error text containing "Unable to load asset" exists
      expect(find.textContaining('Unable to load asset'), findsNothing);
    });
  });
}
