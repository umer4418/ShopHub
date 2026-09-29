import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shophub/controllers/chatbot_controller.dart';
import 'package:shophub/controllers/order_controller.dart';
import 'package:shophub/models/cart_item.dart';
import 'package:shophub/models/order.dart';
import 'package:shophub/models/product.dart';
import 'package:shophub/models/user.dart';
import 'package:shophub/services/chatbot_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const productWatch = Product(
    id: 'prod-watch-1',
    name: 'Smart Fitness Tracker Watch',
    categoryId: 'electronics',
    imageUrl: 'https://example.com/watch.jpg',
    price: 4999.0,
    originalPrice: 6999.0,
    rating: 4.7,
    reviewCount: 85,
    shortDescription: 'Waterproof fitness watch',
    description: 'Detailed description',
    stock: 25,
  );

  const productShoes = Product(
    id: 'prod-shoes-1',
    name: 'Running Shoes Men',
    categoryId: 'footwear',
    imageUrl: 'https://example.com/shoes.jpg',
    price: 7500.0,
    originalPrice: 9000.0,
    rating: 4.8,
    reviewCount: 110,
    shortDescription: 'Breathable running shoes',
    description: 'Detailed description',
    stock: 12,
  );

  final userAOrder1 = ShopOrder(
    id: '1001',
    userId: 'user-a-uuid-1111',
    customerName: 'User A',
    customerEmail: 'usera@example.com',
    phone: '03001111111',
    address: 'House 1, Street A, Lahore',
    paymentMethod: 'Cash on Delivery',
    items: const [
      CartItem(product: productWatch, quantity: 1),
    ],
    total: 4999.0,
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    status: OrderStatus.placed,
  );

  final userAOrder2 = ShopOrder(
    id: '1002',
    userId: 'user-a-uuid-1111',
    customerName: 'User A',
    customerEmail: 'usera@example.com',
    phone: '03001111111',
    address: 'House 1, Street A, Lahore',
    paymentMethod: 'Online Payment (Stripe)',
    items: const [
      CartItem(product: productShoes, quantity: 2),
    ],
    total: 15000.0,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    status: OrderStatus.processing,
  );

  final userBOrder1 = ShopOrder(
    id: '2001',
    userId: 'user-b-uuid-2222',
    customerName: 'User B',
    customerEmail: 'userb@example.com',
    phone: '03002222222',
    address: 'House 2, Street B, Karachi',
    paymentMethod: 'Cash on Delivery',
    items: const [
      CartItem(product: productShoes, quantity: 1),
    ],
    total: 7500.0,
    createdAt: DateTime.now(),
    status: OrderStatus.shipped,
  );

  final allOrders = [userAOrder1, userAOrder2, userBOrder1];

  group('ShopBot Order Tracking — Flow Requirements', () {
    late ChatbotService service;

    setUp(() {
      service = ChatbotService(geminiApiKey: '');
    });

    test('Step 1: Prompts login when unauthenticated user asks to track orders', () async {
      final res = await service.sendMessage(
        message: 'Track my order',
        localOrders: allOrders,
      );

      expect(res.text, contains('Account Login Required'));
      expect(res.text, contains('Please log into your ShopHub account'));
      expect(res.text, contains('ShopBot only tracks orders placed with your own authenticated account'));
    });

    test('Step 2: Displays polite message when logged-in user has 0 orders', () async {
      final res = await service.sendMessage(
        message: 'Track my order',
        userId: 'user-empty-uuid',
        userName: 'New Customer',
        userEmail: 'newcustomer@example.com',
        localOrders: allOrders,
      );

      expect(res.text, contains('No Orders Found'));
      expect(res.text, contains('You have no orders yet under your account'));
      // Must not show User A or User B orders
      expect(res.text.contains('1001'), isFalse);
      expect(res.text.contains('2001'), isFalse);
    });

    test('Step 3: Lists all user orders and asks which one to track (does NOT pick automatically)', () async {
      final res = await service.sendMessage(
        message: 'Track my order',
        userId: 'user-a-uuid-1111',
        userName: 'User A',
        userEmail: 'usera@example.com',
        localOrders: allOrders,
      );

      // Must list both orders belonging to User A
      expect(res.text, contains('Your Orders'));
      expect(res.text, contains('Order #1001'));
      expect(res.text, contains('Order #1002'));
      // Must NOT include User B's order
      expect(res.text.contains('2001'), isFalse);

      // Must ask user to specify or tap an option
      expect(res.text, contains('Which order would you like to track?'));
      expect(res.text, contains('Please enter the order number or tap an option below'));

      // Must provide quick reply chips for each user order
      expect(res.quickReplies, contains('Order #1001'));
      expect(res.quickReplies, contains('Order #1002'));
      expect(res.quickReplies.contains('Order #2001'), isFalse);

      // Must NOT automatically set orderId on initial selection prompt
      expect(res.orderId, isNull);
    });

    test('Step 4: Displays detailed tracking info when user chooses their order', () async {
      final res = await service.sendMessage(
        message: 'Order #1001',
        userId: 'user-a-uuid-1111',
        userName: 'User A',
        userEmail: 'usera@example.com',
        localOrders: allOrders,
      );

      expect(res.orderId, '1001');
      expect(res.text, contains('Order #1001 Tracking Details'));
      expect(res.text, contains('📦 Placed'));
      expect(res.text, contains('Rs. 4999'));
      expect(res.text, contains('Cash on Delivery'));
      expect(res.text, contains('House 1, Street A, Lahore'));
      expect(res.text, contains('Estimated Delivery'));
      expect(res.text, contains('Smart Fitness Tracker Watch'));
    });

    test('Step 4: Accepts standalone number "1002" to track', () async {
      final res = await service.sendMessage(
        message: '1002',
        userId: 'user-a-uuid-1111',
        userName: 'User A',
        userEmail: 'usera@example.com',
        localOrders: allOrders,
      );

      expect(res.orderId, '1002');
      expect(res.text, contains('Order #1002 Tracking Details'));
      expect(res.text, contains('⚙️ Processing'));
      expect(res.text, contains('Rs. 15000'));
      expect(res.text, contains('Running Shoes Men'));
    });

    test('Security Step 5: User A CANNOT track User B\'s order (#2001)', () async {
      final res = await service.sendMessage(
        message: 'Track order #2001',
        userId: 'user-a-uuid-1111',
        userName: 'User A',
        userEmail: 'usera@example.com',
        localOrders: allOrders,
      );

      // Must reject with privacy message and never reveal details of order 2001
      expect(res.text, contains('Order Not Found In Your Account'));
      expect(res.text, contains('I couldn\'t find that order (#2001) in your account'));
      expect(res.text.contains('Karachi'), isFalse);
      expect(res.text.contains('userb@example.com'), isFalse);
      expect(res.text.contains('Shipped'), isFalse);
      expect(res.orderId, isNull);
    });

    test('Security Step 5: User B sees ONLY User B\'s order (#2001)', () async {
      final res = await service.sendMessage(
        message: 'Track my order',
        userId: 'user-b-uuid-2222',
        userName: 'User B',
        userEmail: 'userb@example.com',
        localOrders: allOrders,
      );

      expect(res.text, contains('Order #2001'));
      expect(res.text.contains('1001'), isFalse);
      expect(res.text.contains('1002'), isFalse);

      final trackRes = await service.sendMessage(
        message: 'Order #2001',
        userId: 'user-b-uuid-2222',
        userName: 'User B',
        userEmail: 'userb@example.com',
        localOrders: allOrders,
      );

      expect(trackRes.orderId, '2001');
      expect(trackRes.text, contains('Order #2001 Tracking Details'));
      expect(trackRes.text, contains('🚚 Shipped'));
      expect(trackRes.text, contains('Karachi'));
    });
  });

  group('OrderController Cross-User Isolation', () {
    test('Strict user_id filtering in getOrdersForUser', () {
      final controller = OrderController();
      controller.setOrdersForTesting(allOrders);

      const userA = ShopUser(
        id: 'user-a-uuid-1111',
        name: 'User A',
        email: 'usera@example.com',
        password: 'pass',
      );

      const userB = ShopUser(
        id: 'user-b-uuid-2222',
        name: 'User B',
        email: 'userb@example.com',
        password: 'pass',
      );

      final userAOrders = controller.getOrdersForUser(userA);
      expect(userAOrders.length, 2);
      expect(userAOrders.map((o) => o.id), containsAll(['1001', '1002']));
      expect(userAOrders.any((o) => o.id == '2001'), isFalse);

      final userBOrders = controller.getOrdersForUser(userB);
      expect(userBOrders.length, 1);
      expect(userBOrders.first.id, '2001');
      expect(userBOrders.any((o) => o.id == '1001'), isFalse);
    });
  });

  group('ChatbotController Session Switching & Context Isolation', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      Get.reset();
    });

    test('User A logs in, chats, logs out, User B logs in without seeing User A chat', () async {
      final ctrl = ChatbotController();
      ctrl.init();

      // User A logs in
      ctrl.onUserChanged('user-a-uuid-1111');
      expect(ctrl.currentUserId, 'user-a-uuid-1111');

      // User A sends a message
      await ctrl.sendMessage('How to reset password?');
      expect(ctrl.messages.any((m) => m.text == 'How to reset password?'), isTrue);

      // User A logs out
      ctrl.onUserChanged(null);
      expect(ctrl.currentUserId, isNull);
      // Chat should reset to fresh welcome greeting
      expect(ctrl.messages.length, 1);
      expect(ctrl.messages.first.isUser, isFalse);

      // User B logs in
      ctrl.onUserChanged('user-b-uuid-2222');
      expect(ctrl.currentUserId, 'user-b-uuid-2222');
      // User B does NOT see User A's password question
      expect(ctrl.messages.any((m) => m.text == 'How to reset password?'), isFalse);
      expect(ctrl.messages.length, 1);
      expect(ctrl.messages.first.isUser, isFalse);

      // User B sends a message
      await ctrl.sendMessage('What is the delivery time?');
      expect(ctrl.messages.any((m) => m.text == 'What is the delivery time?'), isTrue);

      // User A logs back in -> User A's previous session is restored
      ctrl.onUserChanged('user-a-uuid-1111');
      expect(ctrl.currentUserId, 'user-a-uuid-1111');
      expect(ctrl.messages.any((m) => m.text == 'How to reset password?'), isTrue);
      // User A does not see User B's delivery time question
      expect(ctrl.messages.any((m) => m.text == 'What is the delivery time?'), isFalse);
    });
  });
}
