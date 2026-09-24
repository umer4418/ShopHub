import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shophub/app/routes/app_routes.dart';
import 'package:shophub/controllers/auth_controller.dart';
import 'package:shophub/controllers/cart_controller.dart';
import 'package:shophub/controllers/product_controller.dart';
import 'package:shophub/controllers/wishlist_controller.dart';
import 'package:shophub/screens/home_screen.dart';
import 'package:shophub/screens/product_detail_screen.dart';
import 'package:shophub/screens/products_screen.dart';
import 'package:shophub/screens/wishlist_screen.dart';
import 'package:shophub/widgets/product_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.reset();
    final productCtrl = ProductController()..init();
    final cartCtrl = CartController()..init();
    final wishlistCtrl = WishlistController()..init();
    final authCtrl = AuthController();

    Get.put(productCtrl);
    Get.put(cartCtrl);
    Get.put(wishlistCtrl);
    Get.put(authCtrl);
  });

  Widget createTestApp(Widget home) {
    return GetMaterialApp(
      home: home,
      routes: {
        AppRoutes.products: (_) => const ProductsScreen(),
        AppRoutes.wishlist: (_) => const WishlistScreen(),
        AppRoutes.cart: (_) => const Scaffold(body: Text('Cart Screen')),
      },
    );
  }

  testWidgets('Tapping heart icon on HomeScreen fills heart and updates wishlist badge',
      (tester) async {
    final wishlistCtrl = Get.find<WishlistController>();

    await tester.pumpWidget(createTestApp(const Scaffold(body: HomeScreen())));
    await tester.pumpAndSettle();

    // Initially 0 items in wishlist
    expect(wishlistCtrl.count, 0);

    // Initial heart buttons on product cards are favorite_border
    expect(find.byIcon(Icons.favorite), findsNothing);

    // Target the heart IconButton inside the first ProductCard
    final productCard = find.byType(ProductCard).first;
    final cardHeartBtn = find.descendant(
      of: productCard,
      matching: find.byType(IconButton),
    );
    expect(cardHeartBtn, findsOneWidget);

    await tester.tap(cardHeartBtn);
    await tester.pump();

    // 1. Wishlist controller updated
    expect(wishlistCtrl.count, 1);
    expect(wishlistCtrl.wishlistIds.length, 1);

    // 2. Heart icon on product card is now filled (Icons.favorite)
    expect(find.byIcon(Icons.favorite), findsOneWidget);

    // 3. AppBar badge reflects 1
    expect(find.text('1'), findsOneWidget);

    // 4. Tap the filled heart again to remove from wishlist
    final filledHeart = find.byIcon(Icons.favorite);
    await tester.tap(filledHeart);
    await tester.pump();

    // Wishlist is now empty and heart is unfilled
    expect(wishlistCtrl.count, 0);
    expect(find.byIcon(Icons.favorite), findsNothing);
  });

  testWidgets('Tapping heart on ProductsScreen fills heart and updates wishlist',
      (tester) async {
    final wishlistCtrl = Get.find<WishlistController>();

    await tester.pumpWidget(createTestApp(const ProductsScreen()));
    await tester.pumpAndSettle();

    expect(wishlistCtrl.count, 0);
    expect(find.byIcon(Icons.favorite), findsNothing);

    // Target the heart IconButton inside the first ProductCard
    final productCard = find.byType(ProductCard).first;
    final cardHeartBtn = find.descendant(
      of: productCard,
      matching: find.byType(IconButton),
    );
    expect(cardHeartBtn, findsOneWidget);

    await tester.tap(cardHeartBtn);
    await tester.pump();

    expect(wishlistCtrl.count, 1);
    expect(find.byIcon(Icons.favorite), findsOneWidget);

    // Untap
    await tester.tap(find.byIcon(Icons.favorite));
    await tester.pump();

    expect(wishlistCtrl.count, 0);
    expect(find.byIcon(Icons.favorite), findsNothing);
  });

  testWidgets('WishlistScreen displays wished items and allows removing',
      (tester) async {
    final wishlistCtrl = Get.find<WishlistController>();
    final productCtrl = Get.find<ProductController>();
    final firstProduct = productCtrl.products.first;

    wishlistCtrl.toggleWishlist(firstProduct.id);
    expect(wishlistCtrl.count, 1);

    await tester.pumpWidget(createTestApp(const WishlistScreen()));
    await tester.pumpAndSettle();

    // Should display the wished product card with filled heart
    expect(find.text(firstProduct.name), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsOneWidget);

    // Tap heart in wishlist to remove it
    await tester.tap(find.byIcon(Icons.favorite));
    await tester.pumpAndSettle();

    expect(wishlistCtrl.count, 0);
    // Should display empty wishlist placeholder
    expect(find.text('Save products you love'), findsOneWidget);
  });

  testWidgets('ProductDetailScreen heart button fills red and toggles wishlist',
      (tester) async {
    final wishlistCtrl = Get.find<WishlistController>();
    final productCtrl = Get.find<ProductController>();
    final firstProduct = productCtrl.products.first;

    await tester.pumpWidget(
      GetMaterialApp(
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            builder: (_) => const ProductDetailScreen(),
            settings: RouteSettings(
              name: AppRoutes.productDetail,
              arguments: firstProduct.id,
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(wishlistCtrl.inWishlist(firstProduct.id), isFalse);
    expect(find.byIcon(Icons.favorite), findsNothing);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);

    // Tap heart in detail screen
    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pump();

    expect(wishlistCtrl.inWishlist(firstProduct.id), isTrue);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.text('Added to wishlist'), findsOneWidget);

    // Tap again to remove
    await tester.tap(find.byIcon(Icons.favorite));
    await tester.pump();

    expect(wishlistCtrl.inWishlist(firstProduct.id), isFalse);
    expect(find.byIcon(Icons.favorite), findsNothing);
    expect(find.text('Removed from wishlist'), findsOneWidget);
  });
}
