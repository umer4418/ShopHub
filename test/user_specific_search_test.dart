import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shophub/controllers/auth_controller.dart';
import 'package:shophub/controllers/product_controller.dart';
import 'package:shophub/models/user.dart';
import 'package:shophub/services/auth_service.dart';
import 'package:shophub/services/product_service.dart';
import 'package:shophub/state/shop_store.dart';
import 'package:shophub/widgets/shop_search_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const userA = ShopUser(
    id: 'user-a-uuid-1111',
    name: 'User A',
    email: 'usera@example.com',
    password: 'password123',
    role: 'customer',
  );

  const userB = ShopUser(
    id: 'user-b-uuid-2222',
    name: 'User B',
    email: 'userb@example.com',
    password: 'password123',
    role: 'customer',
  );

  group('User-Specific Search Isolation (MVC Controllers)', () {
    late SharedPreferences prefs;
    late AuthService authService;
    late ProductService productService;
    late AuthController authCtrl;
    late ProductController productCtrl;

    setUp(() async {
      Get.reset();
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      authService = AuthService();
      await authService.init(prefs);

      productService = ProductService();
      await productService.init(prefs);

      authCtrl = AuthController(authService: authService);
      productCtrl = ProductController(productService: productService);

      Get.put(authCtrl);
      Get.put(productCtrl);

      authCtrl.init();
      productCtrl.init();
    });

    test('User A enters search query, logs out, User B logs in and sees empty search', () async {
      // 1. User A logs in
      authCtrl.setCurrentUser(userA);
      expect(productCtrl.searchQuery, isEmpty);
      expect(productCtrl.activeUserId, userA.id);

      // 2. User A searches for "iPhone"
      productCtrl.setSearch('iPhone');
      expect(productCtrl.searchQuery, 'iPhone');

      // Verify partitioned local storage
      final userASearch = prefs.getString('shophub.search.${userA.id}');
      expect(userASearch, 'iPhone');

      // 3. User A logs out
      await authCtrl.logout();
      expect(productCtrl.searchQuery, isEmpty);
      expect(productCtrl.activeUserId, isNull);

      // 4. User B logs in
      authCtrl.setCurrentUser(userB);
      expect(productCtrl.activeUserId, userB.id);

      // User B MUST see an empty search query, NOT "iPhone"
      expect(productCtrl.searchQuery, isEmpty);
      expect(prefs.getString('shophub.search.${userB.id}'), isNull);

      // 5. User B searches for "Dell Laptop"
      productCtrl.setSearch('Dell Laptop');
      expect(productCtrl.searchQuery, 'Dell Laptop');
      expect(prefs.getString('shophub.search.${userB.id}'), 'Dell Laptop');

      // 6. User B logs out
      await authCtrl.logout();
      expect(productCtrl.searchQuery, isEmpty);

      // 7. User A logs back in
      authCtrl.setCurrentUser(userA);
      // User A's search is restored
      expect(productCtrl.searchQuery, 'iPhone');
      expect(productCtrl.searchQuery, isNot(contains('Dell')));

      // 8. User A resets filters
      productCtrl.resetFilters();
      expect(productCtrl.searchQuery, isEmpty);
      expect(prefs.getString('shophub.search.${userA.id}'), anyOf(isNull, ''));
    });
  });

  group('ShopSearchBar UI Reactive Synchronization', () {
    late SharedPreferences prefs;
    late AuthService authService;
    late ProductService productService;
    late AuthController authCtrl;
    late ProductController productCtrl;

    setUp(() async {
      Get.reset();
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      authService = AuthService();
      await authService.init(prefs);

      productService = ProductService();
      await productService.init(prefs);

      authCtrl = AuthController(authService: authService);
      productCtrl = ProductController(productService: productService);

      Get.put(authCtrl);
      Get.put(productCtrl);

      authCtrl.init();
      productCtrl.init();
    });

    testWidgets('Home search bar text clears reactively on logout and does not leak to next user', (tester) async {
      // 1. User A logs in
      authCtrl.setCurrentUser(userA);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShopSearchBar(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find TextField
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);
      expect(find.text(''), findsOneWidget);

      // 2. User A types "Headphones"
      await tester.enterText(textFieldFinder, 'Headphones');
      await tester.pumpAndSettle();

      expect(productCtrl.searchQuery, 'Headphones');
      expect(find.text('Headphones'), findsOneWidget);

      // 3. User A logs out
      await authCtrl.logout();
      await tester.pumpAndSettle();

      // Search bar MUST be automatically emptied
      expect(productCtrl.searchQuery, isEmpty);
      expect(find.text('Headphones'), findsNothing);

      // 4. User B logs in
      authCtrl.setCurrentUser(userB);
      await tester.pumpAndSettle();

      // Search bar MUST remain empty for User B
      expect(productCtrl.searchQuery, isEmpty);
      expect(find.text('Headphones'), findsNothing);
    });
  });

  group('User-Specific Search Isolation (ShopStore Standalone)', () {
    late ShopStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = ShopStore();
      await store.init();
    });

    test('ShopStore resets search on logout and user changes', () {
      expect(store.currentUser, isNull);
      expect(store.searchQuery, isEmpty);

      // 1. User A logs in
      store.currentUser = userA;
      store.setSearch('Wireless Mouse');
      expect(store.searchQuery, 'Wireless Mouse');

      // 2. User A logs out
      store.logout();
      expect(store.currentUser, isNull);
      expect(store.searchQuery, isEmpty);

      // 3. User B logs in
      store.currentUser = userB;
      expect(store.searchQuery, isEmpty);

      // 4. User B searches
      store.setSearch('Smart Watch');
      expect(store.searchQuery, 'Smart Watch');

      // 5. User B logs out
      store.logout();
      expect(store.searchQuery, isEmpty);
    });
  });
}
