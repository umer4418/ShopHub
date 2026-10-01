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
import 'package:shophub/core/widgets/category_card.dart';
import 'package:shophub/screens/categories_screen.dart';
import 'package:shophub/theme/colors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CategoriesScreen Tests', () {
    late ProductController productCtrl;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      Get.reset();

      final authCtrl = AuthController()..init();
      productCtrl = ProductController()..init();
      final orderCtrl = OrderController()..init();
      final couponCtrl = CouponController()..init();
      final cartCtrl = CartController()..init();
      final wishlistCtrl = WishlistController()..init();

      Get.put(authCtrl);
      Get.put(productCtrl);
      Get.put(orderCtrl);
      Get.put(couponCtrl);
      Get.put(cartCtrl);
      Get.put(wishlistCtrl);
    });

    tearDown(() {
      Get.reset();
    });

    testWidgets('renders search bar, filter button, and category cards', (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          routes: {
            AppRoutes.products: (_) => const Scaffold(body: Text('Products Screen')),
          },
          home: const CategoriesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Check Top Bar (AppBar) is orange with white text
      final appBarFinder = find.byType(AppBar);
      expect(appBarFinder, findsOneWidget);
      final appBarWidget = tester.widget<AppBar>(appBarFinder);
      expect(appBarWidget.backgroundColor, ShopColors.primary);
      expect(appBarWidget.foregroundColor, Colors.white);

      // Check Top Search Bar & Filter Button
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      expect(find.text('Categories'), findsOneWidget);

      // Verify category cards render
      expect(find.byType(CategoryCard), findsWidgets);

      // Verify categories count text
      expect(find.text('${productCtrl.categories.length} Categories'), findsOneWidget);
    });

    testWidgets('search bar filters categories in real time and clear button resets', (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          home: const CategoriesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final firstCategoryName = productCtrl.categories.first.name;

      // Type first category name in search bar
      await tester.enterText(find.byType(TextField), firstCategoryName);
      await tester.pumpAndSettle();

      // Verify matching category card is visible
      expect(
        find.descendant(
          of: find.byType(CategoryCard),
          matching: find.text(firstCategoryName),
        ),
        findsOneWidget,
      );
      expect(find.text('1 found for "$firstCategoryName"'), findsOneWidget);

      // Verify clear search icon button is present and tap it
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // All categories restored
      expect(find.text('${productCtrl.categories.length} Categories'), findsOneWidget);
    });

    testWidgets('shows empty state when search finds no matches, reset button works', (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          home: const CategoriesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Enter non-matching query
      await tester.enterText(find.byType(TextField), 'XYZNonExistingCategory123');
      await tester.pumpAndSettle();

      expect(find.text('No categories found'), findsOneWidget);
      expect(find.text('Reset Search & Filters'), findsOneWidget);

      // Tap reset
      await tester.tap(find.text('Reset Search & Filters'));
      await tester.pumpAndSettle();

      expect(find.text('${productCtrl.categories.length} Categories'), findsOneWidget);
    });

    testWidgets('filter button opens bottom sheet with sort & availability options', (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          home: const CategoriesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap filter button
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();

      // Verify modal sheet content
      expect(find.text('Filter & Sort Categories'), findsOneWidget);
      expect(find.text('Sort Order'), findsOneWidget);
      expect(find.text('Name (A–Z)'), findsOneWidget);
      expect(find.text('Name (Z–A)'), findsOneWidget);
      expect(find.text('Most Items'), findsOneWidget);
      expect(find.text('Category Availability'), findsOneWidget);
      expect(find.text('All Categories'), findsOneWidget);
      expect(find.text('With Products Only'), findsOneWidget);
      expect(find.text('Apply Filters'), findsOneWidget);

      // Select Name (A-Z) and Apply
      await tester.tap(find.text('Name (A–Z)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      // Bottom sheet closed and active sort indicator shown
      expect(find.text('Filter & Sort Categories'), findsNothing);
      expect(find.textContaining('Name (A–Z)'), findsOneWidget);
      expect(find.text('Reset All'), findsOneWidget);
    });

    testWidgets('tapping a CategoryCard navigates to ProductsScreen with filtered category', (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          routes: {
            AppRoutes.products: (_) => const Scaffold(body: Text('Products Screen')),
          },
          home: const CategoriesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final firstCategory = productCtrl.categories.first;

      await tester.tap(find.text(firstCategory.name));
      await tester.pumpAndSettle();

      expect(find.text('Products Screen'), findsOneWidget);
      expect(productCtrl.filterCategoryId, firstCategory.id);
    });

    testWidgets('renders cleanly with zero overflow on small mobile (320px width)', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        GetMaterialApp(
          home: const CategoriesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Categories'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      expect(find.byType(CategoryCard), findsWidgets);
    });
  });
}
