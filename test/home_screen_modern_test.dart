import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shophub/app/routes/app_routes.dart';
import 'package:shophub/controllers/auth_controller.dart';
import 'package:shophub/controllers/cart_controller.dart';
import 'package:shophub/controllers/product_controller.dart';
import 'package:shophub/controllers/wishlist_controller.dart';
import 'package:shophub/screens/home_screen.dart';
import 'package:shophub/widgets/home_promo_carousel.dart';
import 'package:shophub/widgets/shop_search_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProductController productCtrl;
  late CartController cartCtrl;
  late WishlistController wishlistCtrl;
  late AuthController authCtrl;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Get.reset();

    productCtrl = ProductController()..init();
    cartCtrl = CartController()..init();
    wishlistCtrl = WishlistController()..init();
    authCtrl = AuthController();

    Get.put(productCtrl);
    Get.put(cartCtrl);
    Get.put(wishlistCtrl);
    Get.put(authCtrl);
  });

  Widget createTestHome({VoidCallback? onSeeCategories, VoidCallback? onSeeAccount}) {
    return GetMaterialApp(
      home: Scaffold(
        body: HomeScreen(
          onSeeCategories: onSeeCategories,
          onSeeAccount: onSeeAccount,
        ),
      ),
      routes: {
        AppRoutes.products: (_) => const Scaffold(body: Text('Products Screen')),
        AppRoutes.productDetail: (_) => const Scaffold(body: Text('Product Detail Screen')),
        AppRoutes.wishlist: (_) => const Scaffold(body: Text('Wishlist Screen')),
        AppRoutes.cart: (_) => const Scaffold(body: Text('Cart Screen')),
        AppRoutes.chatbot: (_) => const Scaffold(body: Text('Chatbot Screen')),
        AppRoutes.login: (_) => const Scaffold(body: Text('Login Screen')),
      },
    );
  }

  group('Modernized HomeScreen UI & UX', () {
    testWidgets('Renders modern App Header with branding, actions, and search bar',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestHome());
      await tester.pumpAndSettle();

      // 1. Branding
      expect(find.text('ShopHub'), findsWidgets);

      // 2. Action Icons in Header
      expect(find.byTooltip('Wishlist'), findsOneWidget);
      expect(find.byTooltip('ShopBot AI Support'), findsOneWidget);
      expect(find.byTooltip('Cart'), findsOneWidget);
      expect(find.byTooltip('My Account'), findsOneWidget);

      // 3. Modern Search Bar
      expect(find.byType(ShopSearchBar), findsOneWidget);
      expect(
        find.text('Search products, brands and categories...'),
        findsOneWidget,
      );

      // Tap chatbot action navigates to chatbot screen
      await tester.tap(find.byTooltip('ShopBot AI Support'));
      await tester.pumpAndSettle();
      expect(find.text('Chatbot Screen'), findsOneWidget);
    });

    testWidgets('Promotional carousel displays campaign banners and allows swiping',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestHome());
      await tester.pumpAndSettle();

      // Carousel is present
      expect(find.byType(HomePromoCarousel), findsOneWidget);

      // First banner is MEGA SALE
      expect(find.text('🔥 MEGA SALE'), findsOneWidget);
      expect(find.text('UP TO 70% OFF'), findsOneWidget);
      expect(find.text('Shop Electronics →'), findsOneWidget);

      // Swipe carousel horizontally to next banner (Fashion Week)
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.text('✨ FASHION WEEK'), findsOneWidget);
      expect(find.text('Explore Fashion →'), findsOneWidget);

      // Tapping CTA navigates to Products
      await tester.tap(find.text('Explore Fashion →'));
      await tester.pumpAndSettle();
      expect(find.text('Products Screen'), findsOneWidget);
      expect(productCtrl.filterCategoryId, 'fashion');
    });

    testWidgets('Displays Trust Badges Strip with perks and customer guarantees',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestHome());
      await tester.pumpAndSettle();

      expect(find.text('Free Delivery'), findsOneWidget);
      expect(find.text('100% Genuine'), findsOneWidget);
      expect(find.text('Easy Returns'), findsOneWidget);
      expect(find.text('24/7 AI Support'), findsOneWidget);
    });

    testWidgets('Category Strip displays categories and allows filtering on tap',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestHome());
      await tester.pumpAndSettle();

      expect(find.text('Shop by Category'), findsOneWidget);
      expect(find.text('Electronics'), findsWidgets);
      expect(find.text('Fashion'), findsWidgets);

      // Tapping a category sets category filter and navigates
      await tester.tap(find.text('Electronics').first);
      await tester.pumpAndSettle();
      expect(find.text('Products Screen'), findsOneWidget);
      expect(productCtrl.filterCategoryId, 'electronics');
    });

    testWidgets('Flash Deals section displays discounted items with progress indicator',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestHome());
      await tester.pumpAndSettle();

      // Scroll until Flash Deals section is visible
      await tester.scrollUntilVisible(
        find.text('Flash Deals'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Flash Deals section header and countdown timer
      expect(find.text('Flash Deals'), findsOneWidget);
      expect(find.text('Ends in 08:45:20'), findsOneWidget);
      expect(find.text('Almost Sold Out'), findsWidgets);
    });

    testWidgets('Quick Add-to-Cart button in ProductCard updates CartController and shows feedback',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestHome());
      await tester.pumpAndSettle();

      expect(cartCtrl.cartCount, 0);

      // Find the add-to-cart button on the first ProductCard
      final addCartBtn = find.byIcon(Icons.add_shopping_cart_rounded).first;
      await tester.tap(addCartBtn);
      await tester.pumpAndSettle();

      expect(cartCtrl.cartCount, 1);
      expect(find.textContaining('added to cart'), findsOneWidget);
    });

    testWidgets('Responsive column count adapts between mobile (2 cols) and tablet (3+ cols)',
        (tester) async {
      // Test mobile size (width 400)
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestHome());
      await tester.pumpAndSettle();

      // SliverGrid for Featured Products should have crossAxisCount == 2 on mobile
      final gridOnMobile = tester.widget<SliverGrid>(find.byType(SliverGrid).first);
      final delegateOnMobile =
          gridOnMobile.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegateOnMobile.crossAxisCount, 2);

      // Resize to tablet (width 750)
      tester.view.physicalSize = const Size(750, 1000);
      await tester.pumpAndSettle();

      final gridOnTablet = tester.widget<SliverGrid>(find.byType(SliverGrid).first);
      final delegateOnTablet =
          gridOnTablet.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegateOnTablet.crossAxisCount, 3);
    });
  });
}
