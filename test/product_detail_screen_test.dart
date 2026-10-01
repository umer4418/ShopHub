import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shophub/app/routes/app_routes.dart';
import 'package:shophub/controllers/auth_controller.dart';
import 'package:shophub/controllers/cart_controller.dart';
import 'package:shophub/controllers/order_controller.dart';
import 'package:shophub/controllers/product_controller.dart';
import 'package:shophub/controllers/wishlist_controller.dart';
import 'package:shophub/screens/product_detail_screen.dart';

void main() {
  setUp(() {
    Get.reset();
    Get.put(AuthController());
    Get.put(ProductController());
    Get.put(CartController());
    Get.put(WishlistController());
    Get.put(OrderController());
  });

  testWidgets('ProductDetailScreen renders complete product information and bottom buttons at bottom', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final productCtrl = Get.find<ProductController>();
    final product = productCtrl.products.first;

    await tester.pumpWidget(
      GetMaterialApp(
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            builder: (_) => const ProductDetailScreen(),
            settings: RouteSettings(
              name: AppRoutes.productDetail,
              arguments: product.id,
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    // Verify product details are rendered
    expect(find.text(product.name), findsOneWidget);
    expect(find.text(product.shortDescription), findsOneWidget);
    expect(find.text('In stock: ${product.stock}'), findsOneWidget);
    expect(find.text('Quantity'), findsOneWidget);
    expect(find.text('Add to Cart'), findsOneWidget);
    expect(find.text('Buy Now'), findsOneWidget);

    // Verify Add to Cart button is positioned at the bottom of the screen
    final btnRect = tester.getRect(find.text('Add to Cart'));
    expect(btnRect.top, greaterThan(750.0));
  });
}
