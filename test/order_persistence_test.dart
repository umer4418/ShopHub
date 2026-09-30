import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shophub/controllers/auth_controller.dart';
import 'package:shophub/controllers/order_controller.dart';
import 'package:shophub/models/cart_item.dart';
import 'package:shophub/models/order.dart';
import 'package:shophub/models/product.dart';
import 'package:shophub/models/user.dart';
import 'package:shophub/services/auth_service.dart';
import 'package:shophub/services/order_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OrderService orderService;
  late OrderController orderController;
  late AuthService authService;
  late AuthController authController;

  const testProduct = Product(
    id: 'prod-pers-1',
    name: 'Smart Earbuds Pro',
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

  const customerA = ShopUser(
    id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    name: 'Customer A',
    email: 'customera@shophub.com',
    password: 'password123',
    role: 'customer',
  );

  const customerB = ShopUser(
    id: 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b22',
    name: 'Customer B',
    email: 'customerb@shophub.com',
    password: 'password123',
    role: 'customer',
  );

  const superAdmin = ShopUser(
    id: 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c33',
    name: 'Super Admin',
    email: 'admin@shophub.com',
    password: 'adminpassword',
    isAdmin: true,
    role: 'admin',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    orderService = OrderService();
    await orderService.init(prefs);

    authService = AuthService();
    await authService.init(prefs);

    Get.reset();
    orderController = Get.put(OrderController(orderService: orderService));
    authController = Get.put(AuthController(authService: authService));
  });

  group('Order Persistence & Supabase Single Source of Truth', () {
    test('Customer order persists across logout and login', () async {
      // 1. Customer A logs in
      authController.setCurrentUser(customerA);
      expect(authController.currentUser?.email, customerA.email);

      // 2. Customer A places an order
      final order = orderController.placeOrder(
        userId: customerA.id,
        customerEmail: customerA.email,
        name: customerA.name,
        phone: '03001234567',
        address: 'Islamabad, Pakistan',
        paymentMethod: 'Stripe (Card: **** 4242)',
        items: const [CartItem(product: testProduct, quantity: 2)],
        total: 7000.0,
        stripePaymentId: 'pi_test_customer_a_001',
        paymentStatus: 'Paid',
      );

      expect(order.userId, customerA.id);
      expect(orderController.orders.length, 1);
      expect(orderController.userOrders.length, 1);
      expect(orderController.userOrders.first.id, order.id);

      // 3. Customer A logs out
      await authController.logout();
      expect(authController.currentUser, isNull);
      expect(orderController.userOrders, isEmpty);

      // 4. Customer A logs back in
      authController.setCurrentUser(customerA);
      await orderController.refreshOrders(customerA.id);

      // 5. Order is successfully retrieved and available
      expect(orderController.userOrders.length, 1);
      expect(orderController.userOrders.first.id, order.id);
      expect(orderController.userOrders.first.total, 7000.0);
      expect(orderController.userOrders.first.paymentStatus, 'Paid');

      final userOrders = orderController.getOrdersForAuthenticatedUser(
        userId: customerA.id,
        user: customerA,
      );
      expect(userOrders.length, 1);
      expect(userOrders.first.id, order.id);
    });

    test('Customer order isolation: Customer B does not see Customer A orders after re-login', () async {
      // 1. Customer A places an order
      authController.setCurrentUser(customerA);
      final orderA = orderController.placeOrder(
        userId: customerA.id,
        customerEmail: customerA.email,
        name: customerA.name,
        phone: '03001111111',
        address: 'Lahore, Pakistan',
        paymentMethod: 'Cash on Delivery',
        items: const [CartItem(product: testProduct, quantity: 1)],
        total: 3500.0,
      );

      // 2. Customer A logs out
      await authController.logout();
      expect(orderController.userOrders, isEmpty);

      // 3. Customer B logs in
      authController.setCurrentUser(customerB);
      await orderController.refreshOrders(customerB.id);

      // Customer B has no orders
      expect(orderController.userOrders, isEmpty);
      final ordersForB = orderController.getOrdersForAuthenticatedUser(
        userId: customerB.id,
        user: customerB,
      );
      expect(ordersForB, isEmpty);

      // 4. Customer B places their own order
      final orderB = orderController.placeOrder(
        userId: customerB.id,
        customerEmail: customerB.email,
        name: customerB.name,
        phone: '03002222222',
        address: 'Karachi, Pakistan',
        paymentMethod: 'Stripe',
        items: const [CartItem(product: testProduct, quantity: 3)],
        total: 10500.0,
        stripePaymentId: 'pi_test_customer_b_002',
        paymentStatus: 'Paid',
      );

      expect(orderController.userOrders.length, 1);
      expect(orderController.userOrders.first.id, orderB.id);

      // 5. Customer B logs out and logs in again
      await authController.logout();
      expect(orderController.userOrders, isEmpty);

      authController.setCurrentUser(customerB);
      await orderController.refreshOrders(customerB.id);

      expect(orderController.userOrders.length, 1);
      expect(orderController.userOrders.first.id, orderB.id);

      // Re-verify Customer A orders
      await authController.logout();
      authController.setCurrentUser(customerA);
      await orderController.refreshOrders(customerA.id);

      expect(orderController.userOrders.length, 1);
      expect(orderController.userOrders.first.id, orderA.id);
    });

    test('Admin order persistence: Admin views all orders from all customers after logout and login', () async {
      // 1. Customer A places Order A
      authController.setCurrentUser(customerA);
      final orderA = orderController.placeOrder(
        userId: customerA.id,
        customerEmail: customerA.email,
        name: customerA.name,
        phone: '03001111111',
        address: 'F-8, Islamabad',
        paymentMethod: 'Cash on Delivery',
        items: const [CartItem(product: testProduct, quantity: 1)],
        total: 3500.0,
      );

      // 2. Customer B places Order B
      authController.setCurrentUser(customerB);
      final orderB = orderController.placeOrder(
        userId: customerB.id,
        customerEmail: customerB.email,
        name: customerB.name,
        phone: '03002222222',
        address: 'DHA, Lahore',
        paymentMethod: 'Stripe (Card: **** 1234)',
        items: const [CartItem(product: testProduct, quantity: 2)],
        total: 7000.0,
        stripePaymentId: 'pi_test_b_999',
        paymentStatus: 'Paid',
      );

      // 3. Customer B logs out
      await authController.logout();

      // 4. Super Admin logs in
      authController.setCurrentUser(superAdmin);
      expect(authController.isAdmin, isTrue);

      await orderController.refreshOrders();

      // Admin must see all customer orders
      expect(orderController.orders.length, greaterThanOrEqualTo(2));
      final allOrderIds = orderController.orders.map((o) => o.id).toSet();
      expect(allOrderIds.contains(orderA.id), isTrue);
      expect(allOrderIds.contains(orderB.id), isTrue);

      // 5. Admin logs out
      await authController.logout();
      expect(authController.currentUser, isNull);

      // 6. Admin logs back in
      authController.setCurrentUser(superAdmin);
      expect(authController.isAdmin, isTrue);
      await orderController.refreshOrders();

      // Admin still sees all customer orders after session re-establishment
      expect(orderController.orders.length, greaterThanOrEqualTo(2));
      final reloadedIds = orderController.orders.map((o) => o.id).toSet();
      expect(reloadedIds.contains(orderA.id), isTrue);
      expect(reloadedIds.contains(orderB.id), isTrue);
    });

    test('App restart simulation preserves orders from OrderService store', () async {
      // 1. User places order
      authController.setCurrentUser(customerA);
      final order = orderController.placeOrder(
        userId: customerA.id,
        customerEmail: customerA.email,
        name: customerA.name,
        phone: '03001234567',
        address: 'Gulberg, Lahore',
        paymentMethod: 'Stripe',
        items: const [CartItem(product: testProduct, quantity: 1)],
        total: 3500.0,
        stripePaymentId: 'pi_restart_test_001',
        paymentStatus: 'Paid',
      );

      // 2. Simulate complete app restart: new OrderService instance with same shared preferences
      final prefs = await SharedPreferences.getInstance();
      final freshOrderService = OrderService();
      await freshOrderService.init(prefs);

      Get.reset();
      final freshOrderController = Get.put(OrderController(orderService: freshOrderService));
      final freshAuthController = Get.put(AuthController(authService: authService));

      freshOrderController.init();
      expect(freshOrderController.isInitialized, isTrue);

      // 3. User session rehydrated
      freshAuthController.setCurrentUser(customerA);
      await freshOrderController.refreshOrders(customerA.id);

      expect(freshOrderController.userOrders.any((o) => o.id == order.id), isTrue);
      final restored = freshOrderController.userOrders.firstWhere((o) => o.id == order.id);
      expect(restored.total, 3500.0);
      expect(restored.stripePaymentId, 'pi_restart_test_001');
      expect(restored.paymentStatus, 'Paid');
    });

    test('ShopOrder toSupabaseMap correctly validates UUIDs and avoids postgres syntax errors', () {
      // Valid UUID
      final validOrder = ShopOrder(
        id: 'SH-VALID',
        userId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        customerEmail: 'valid@example.com',
        customerName: 'Valid User',
        phone: '03001234567',
        address: 'Test Address',
        paymentMethod: 'Cash on Delivery',
        items: const [CartItem(product: testProduct, quantity: 1)],
        total: 3500.0,
        createdAt: DateTime.now(),
        status: OrderStatus.placed,
      );

      final validMap = validOrder.toSupabaseMap();
      expect(validMap['user_id'], 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11');
      // customer_email is embedded safely in items to match Supabase schema
      expect(validMap.containsKey('customer_email'), isFalse);
      expect(ShopOrder.fromJson(validMap).customerEmail, 'valid@example.com');

      // Invalid UUID string (e.g. mock-customer-uuid) should NOT be passed to user_id column
      final mockOrder = ShopOrder(
        id: 'SH-MOCK',
        userId: 'mock-customer-uuid',
        customerEmail: 'mock@example.com',
        customerName: 'Mock User',
        phone: '03001234567',
        address: 'Test Address',
        paymentMethod: 'Cash on Delivery',
        items: const [CartItem(product: testProduct, quantity: 1)],
        total: 3500.0,
        createdAt: DateTime.now(),
        status: OrderStatus.placed,
      );

      final mockMap = mockOrder.toSupabaseMap();
      expect(mockMap.containsKey('user_id'), isFalse);
      expect(mockMap.containsKey('customer_email'), isFalse);
      expect(ShopOrder.fromJson(mockMap).customerEmail, 'mock@example.com');
    });

    test('Customer placed order immediately appears in Admin orders and survives refresh', () async {
      // 1. Customer places an order
      authController.setCurrentUser(customerA);
      final placedOrder = orderController.placeOrder(
        userId: customerA.id,
        customerEmail: customerA.email,
        name: customerA.name,
        phone: '03001234567',
        address: 'Lahore, Pakistan',
        paymentMethod: 'Stripe (Card: **** 4242)',
        items: const [CartItem(product: testProduct, quantity: 2)],
        total: 7000.0,
        stripePaymentId: 'pi_test_admin_view_001',
        paymentStatus: 'Paid',
      );

      // Verify immediate appearance in global orders
      expect(orderController.orders.any((o) => o.id == placedOrder.id), isTrue);

      // 2. Admin switches in
      authController.setCurrentUser(superAdmin);
      expect(authController.isAdmin, isTrue);

      // 3. Admin refreshes orders
      await orderController.refreshOrders();

      // Placed order must still be present and displayed in Admin orders
      expect(orderController.orders.any((o) => o.id == placedOrder.id), isTrue);
      final adminViewOrder = orderController.orders.firstWhere((o) => o.id == placedOrder.id);
      expect(adminViewOrder.customerName, customerA.name);
      expect(adminViewOrder.total, 7000.0);
      expect(adminViewOrder.isPaid, isTrue);
    });
  });
}
