import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shophub/app/routes/app_routes.dart';
import 'package:shophub/controllers/auth_controller.dart';
import 'package:shophub/controllers/order_controller.dart';
import 'package:shophub/models/cart_item.dart';
import 'package:shophub/models/order.dart';
import 'package:shophub/models/product.dart';
import 'package:shophub/models/user.dart';
import 'package:shophub/screens/profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testProduct = Product(
    id: 'prod-test-1',
    name: 'Wireless Bluetooth Earbuds',
    categoryId: 'electronics',
    imageUrl: '',
    price: 3500.0,
    originalPrice: 4500.0,
    rating: 4.8,
    reviewCount: 90,
    shortDescription: 'Great earbuds',
    description: 'Detailed description',
    stock: 20,
  );

  const userA = ShopUser(
    id: 'user-a-1111',
    name: 'User A',
    email: 'usera@example.com',
    password: 'password123',
    role: 'customer',
  );

  const userB = ShopUser(
    id: 'user-b-2222',
    name: 'User B',
    email: 'userb@example.com',
    password: 'password123',
    role: 'customer',
  );

  final order1 = ShopOrder(
    id: '1',
    userId: 'user-a-1111',
    customerName: 'User A',
    customerEmail: 'usera@example.com',
    phone: '03001111111',
    address: 'Address A',
    paymentMethod: 'Cash on Delivery',
    items: const [CartItem(product: testProduct, quantity: 1)],
    total: 3500.0,
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
    status: OrderStatus.placed,
  );

  final order2 = ShopOrder(
    id: '2',
    userId: 'user-a-1111',
    customerName: 'User A',
    customerEmail: 'usera@example.com',
    phone: '03001111111',
    address: 'Address A',
    paymentMethod: 'Cash on Delivery',
    items: const [CartItem(product: testProduct, quantity: 1)],
    total: 3500.0,
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    status: OrderStatus.processing,
  );

  final order3 = ShopOrder(
    id: '3',
    userId: 'user-a-1111',
    customerName: 'User A',
    customerEmail: 'usera@example.com',
    phone: '03001111111',
    address: 'Address A',
    paymentMethod: 'Cash on Delivery',
    items: const [CartItem(product: testProduct, quantity: 1)],
    total: 3500.0,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    status: OrderStatus.delivered,
  );

  final order4 = ShopOrder(
    id: '4',
    userId: 'user-b-2222',
    customerName: 'User B',
    customerEmail: 'userb@example.com',
    phone: '03002222222',
    address: 'Address B',
    paymentMethod: 'Online Payment (Stripe)',
    items: const [CartItem(product: testProduct, quantity: 2)],
    total: 7000.0,
    createdAt: DateTime.now().subtract(const Duration(hours: 12)),
    status: OrderStatus.processing,
  );

  final order5 = ShopOrder(
    id: '5',
    userId: 'user-b-2222',
    customerName: 'User B',
    customerEmail: 'userb@example.com',
    phone: '03002222222',
    address: 'Address B',
    paymentMethod: 'Online Payment (Stripe)',
    items: const [CartItem(product: testProduct, quantity: 1)],
    total: 3500.0,
    createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    status: OrderStatus.delivered,
  );

  final allMockOrders = [order1, order2, order3, order4, order5];

  Widget createProfileApp() {
    return GetMaterialApp(
      home: const Scaffold(body: ProfileScreen()),
      routes: {
        AppRoutes.orderConfirmation: (_) =>
            const Scaffold(body: Text('Order Confirmation Screen')),
      },
    );
  }

  group('Profile My Orders Categories & User-Specific Isolation', () {
    late AuthController authCtrl;
    late OrderController orderCtrl;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      Get.reset();
      authCtrl = AuthController()..init();
      orderCtrl = OrderController()..init();
      Get.put(authCtrl);
      Get.put(orderCtrl);
      orderCtrl.setOrdersForTesting(allMockOrders);
    });

    testWidgets('User A sees only #1, #2, #3 properly categorized under tabs', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      authCtrl.setCurrentUser(userA);

      await tester.pumpWidget(createProfileApp());
      await tester.pumpAndSettle();

      // Heading and Tabs exist
      expect(find.text('My Orders'), findsOneWidget);
      expect(find.byKey(const ValueKey('order_tab_all')), findsOneWidget);
      expect(find.byKey(const ValueKey('order_tab_placed')), findsOneWidget);
      expect(find.byKey(const ValueKey('order_tab_processing')), findsOneWidget);
      expect(find.byKey(const ValueKey('order_tab_delivered')), findsOneWidget);


      // Default: All Orders tab selected -> User A sees #1, #2, #3
      expect(find.text('Order #1'), findsOneWidget);
      expect(find.text('Order #2'), findsOneWidget);
      expect(find.text('Order #3'), findsOneWidget);
      // User B orders must NOT be displayed
      expect(find.text('Order #4'), findsNothing);
      expect(find.text('Order #5'), findsNothing);

      // Switch to Placed tab
      await tester.tap(find.byKey(const ValueKey('order_tab_placed')));
      await tester.pumpAndSettle();

      expect(find.text('Order #1'), findsOneWidget);
      expect(find.text('Order #2'), findsNothing);
      expect(find.text('Order #3'), findsNothing);
      expect(find.text('Order #4'), findsNothing);
      expect(find.text('Order #5'), findsNothing);

      // Switch to Processing tab
      await tester.tap(find.byKey(const ValueKey('order_tab_processing')));
      await tester.pumpAndSettle();

      expect(find.text('Order #1'), findsNothing);
      expect(find.text('Order #2'), findsOneWidget);
      expect(find.text('Order #3'), findsNothing);
      expect(find.text('Order #4'), findsNothing);
      expect(find.text('Order #5'), findsNothing);

      // Switch to Delivered tab
      await tester.tap(find.byKey(const ValueKey('order_tab_delivered')));
      await tester.pumpAndSettle();

      expect(find.text('Order #1'), findsNothing);
      expect(find.text('Order #2'), findsNothing);
      expect(find.text('Order #3'), findsOneWidget);
      expect(find.text('Order #4'), findsNothing);
      expect(find.text('Order #5'), findsNothing);
    });

    testWidgets('User B sees only #4, #5 with empty Placed state', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      authCtrl.setCurrentUser(userB);

      await tester.pumpWidget(createProfileApp());
      await tester.pumpAndSettle();

      // All Orders tab -> User B sees #4 and #5
      expect(find.text('Order #4'), findsOneWidget);
      expect(find.text('Order #5'), findsOneWidget);
      // User A orders must NEVER appear for User B
      expect(find.text('Order #1'), findsNothing);
      expect(find.text('Order #2'), findsNothing);
      expect(find.text('Order #3'), findsNothing);

      // Switch to Placed tab -> User B has no placed orders
      await tester.tap(find.byKey(const ValueKey('order_tab_placed')));
      await tester.pumpAndSettle();

      expect(find.text('No placed orders yet.'), findsOneWidget);
      expect(find.text('Order #1'), findsNothing);
      expect(find.text('Order #4'), findsNothing);

      // Switch to Processing tab -> User B sees #4
      await tester.tap(find.byKey(const ValueKey('order_tab_processing')));
      await tester.pumpAndSettle();

      expect(find.text('Order #4'), findsOneWidget);
      expect(find.text('Order #2'), findsNothing);
      expect(find.text('Order #5'), findsNothing);

      // Switch to Delivered tab -> User B sees #5
      await tester.tap(find.byKey(const ValueKey('order_tab_delivered')));
      await tester.pumpAndSettle();

      expect(find.text('Order #5'), findsOneWidget);
      expect(find.text('Order #3'), findsNothing);
      expect(find.text('Order #4'), findsNothing);
    });

    testWidgets('Newly placed order #1020 appears immediately in All Orders and Placed', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      authCtrl.setCurrentUser(userA);

      await tester.pumpWidget(createProfileApp());
      await tester.pumpAndSettle();

      // User A places a new order #1020
      orderCtrl.placeOrder(
        userId: userA.id,
        customerEmail: userA.email,
        name: userA.name,
        phone: '03001111111',
        address: 'New Address',
        items: const [CartItem(product: testProduct, quantity: 1)],
        total: 3500.0,
      );

      // We find the newly placed order ID
      final newOrder = orderCtrl.userOrders.first;
      await tester.pumpAndSettle();

      // Appears in All Orders
      expect(find.text('Order #${newOrder.id}'), findsOneWidget);

      // Switch to Placed tab -> appears in Placed
      await tester.tap(find.byKey(const ValueKey('order_tab_placed')));
      await tester.pumpAndSettle();
      expect(find.text('Order #${newOrder.id}'), findsOneWidget);

      // Switch to Processing tab -> NOT in Processing
      await tester.tap(find.byKey(const ValueKey('order_tab_processing')));
      await tester.pumpAndSettle();
      expect(find.text('Order #${newOrder.id}'), findsNothing);

      // Switch to Delivered tab -> NOT in Delivered
      await tester.tap(find.byKey(const ValueKey('order_tab_delivered')));
      await tester.pumpAndSettle();
      expect(find.text('Order #${newOrder.id}'), findsNothing);
    });

    testWidgets('Admin status change: Placed -> Processing -> Delivered updates tabs dynamically', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      authCtrl.setCurrentUser(userA);

      await tester.pumpWidget(createProfileApp());
      await tester.pumpAndSettle();

      // Order #1 starts as Placed
      await tester.tap(find.byKey(const ValueKey('order_tab_placed')));
      await tester.pumpAndSettle();
      expect(find.text('Order #1'), findsOneWidget);

      // Admin updates Order #1 status: Placed -> Processing
      orderCtrl.updateOrderStatus('1', OrderStatus.processing);
      await tester.pumpAndSettle();

      // Order #1 should no longer be in Placed
      expect(find.text('Order #1'), findsNothing);

      // Switch to Processing -> Order #1 is now here!
      await tester.tap(find.byKey(const ValueKey('order_tab_processing')));
      await tester.pumpAndSettle();
      expect(find.text('Order #1'), findsOneWidget);

      // Admin updates Order #1 status: Processing -> Delivered
      orderCtrl.updateOrderStatus('1', OrderStatus.delivered);
      await tester.pumpAndSettle();

      // Order #1 should no longer be in Processing
      expect(find.text('Order #1'), findsNothing);

      // Switch to Delivered -> Order #1 is now in Delivered!
      await tester.tap(find.byKey(const ValueKey('order_tab_delivered')));
      await tester.pumpAndSettle();
      expect(find.text('Order #1'), findsOneWidget);
    });

    testWidgets('Tapping an order card navigates to Order Confirmation screen', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      authCtrl.setCurrentUser(userA);

      await tester.pumpWidget(createProfileApp());
      await tester.pumpAndSettle();

      expect(find.text('Order #1'), findsOneWidget);

      // Tap on Order #1 card
      await tester.tap(find.byKey(const ValueKey('order_card_1')));
      await tester.pumpAndSettle();

      expect(find.text('Order Confirmation Screen'), findsOneWidget);
    });
  });
}
