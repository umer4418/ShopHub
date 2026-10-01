import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shophub/app/routes/app_routes.dart';
import 'package:shophub/controllers/auth_controller.dart';
import 'package:shophub/controllers/order_controller.dart';
import 'package:shophub/controllers/support_chat_controller.dart';
import 'package:shophub/models/cart_item.dart';
import 'package:shophub/models/order.dart';
import 'package:shophub/models/product.dart';
import 'package:shophub/models/user.dart';
import 'package:shophub/admin/admin_support_screen.dart';
import 'package:shophub/screens/profile_screen.dart';
import 'package:shophub/screens/support_chat_screen.dart';
import 'package:shophub/services/support_chat_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testProduct = Product(
    id: 'prod-test-99',
    name: 'Wireless Noise-Cancelling Headphones',
    categoryId: 'electronics',
    imageUrl: '',
    price: 12000.0,
    originalPrice: 15000.0,
    rating: 4.9,
    reviewCount: 140,
    shortDescription: 'Premium sound experience',
    description: 'Detailed description',
    stock: 25,
  );

  const customerA = ShopUser(
    id: 'user-cust-a',
    name: 'Customer A',
    email: 'customera@example.com',
    password: 'password123',
    role: 'customer',
  );

  const customerB = ShopUser(
    id: 'user-cust-b',
    name: 'Customer B',
    email: 'customerb@example.com',
    password: 'password123',
    role: 'customer',
  );

  const adminUser = ShopUser(
    id: 'user-admin-root',
    name: 'Admin User',
    email: 'admin@shophub.com',
    password: 'password123',
    isAdmin: true,
    role: 'admin',
  );

  ShopOrder createTestOrder({
    required String id,
    required String userId,
    required String customerName,
    required String customerEmail,
    required OrderStatus status,
  }) {
    return ShopOrder(
      id: id,
      userId: userId,
      customerName: customerName,
      customerEmail: customerEmail,
      phone: '03001234567',
      address: '123 Market Street, Lahore',
      paymentMethod: 'Cash on Delivery',
      items: const [CartItem(product: testProduct, quantity: 1)],
      total: 12000.0,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      status: status,
    );
  }

  Widget createTestApp(Widget home) {
    return GetMaterialApp(
      home: home,
      routes: {
        AppRoutes.supportChat: (_) => const SupportChatScreen(),
        AppRoutes.orderConfirmation: (_) =>
            const Scaffold(body: Text('Order Confirmation Screen')),
      },
    );
  }

  group('Part 1: Completed Orders Flow & Isolation Tests', () {
    late AuthController authCtrl;
    late OrderController orderCtrl;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      Get.reset();
      authCtrl = AuthController()..init();
      orderCtrl = OrderController()..init();
      Get.put(authCtrl);
      Get.put(orderCtrl);
    });

    test('Customer can only transition Delivered -> Completed', () async {
      final placedOrder = createTestOrder(
        id: 'ord-101',
        userId: customerA.id!,
        customerName: customerA.name,
        customerEmail: customerA.email,
        status: OrderStatus.placed,
      );
      final processingOrder = createTestOrder(
        id: 'ord-102',
        userId: customerA.id!,
        customerName: customerA.name,
        customerEmail: customerA.email,
        status: OrderStatus.processing,
      );
      final deliveredOrder = createTestOrder(
        id: 'ord-103',
        userId: customerA.id!,
        customerName: customerA.name,
        customerEmail: customerA.email,
        status: OrderStatus.delivered,
      );

      orderCtrl.setOrdersForTesting([placedOrder, processingOrder, deliveredOrder]);
      authCtrl.setCurrentUser(customerA);

      // Attempting to mark Placed order as completed must fail
      final resPlaced = await orderCtrl.markOrderAsCompleted('ord-101', userId: customerA.id!);
      expect(resPlaced, isFalse);
      expect(orderCtrl.getOrderById('ord-101')?.status, OrderStatus.placed);

      // Attempting to mark Processing order as completed must fail
      final resProcessing = await orderCtrl.markOrderAsCompleted('ord-102', userId: customerA.id!);
      expect(resProcessing, isFalse);
      expect(orderCtrl.getOrderById('ord-102')?.status, OrderStatus.processing);

      // Marking Delivered order as completed must succeed
      final resDelivered = await orderCtrl.markOrderAsCompleted('ord-103', userId: customerA.id!);
      expect(resDelivered, isTrue);
      expect(orderCtrl.getOrderById('ord-103')?.status, OrderStatus.completed);
    });

    test('Customer cannot mark another customer\'s delivered order as completed', () async {
      final deliveredOrderB = createTestOrder(
        id: 'ord-201',
        userId: customerB.id!,
        customerName: customerB.name,
        customerEmail: customerB.email,
        status: OrderStatus.delivered,
      );

      orderCtrl.setOrdersForTesting([deliveredOrderB]);
      authCtrl.setCurrentUser(customerA); // Customer A logged in

      // Customer A tries to mark Customer B's order
      final result = await orderCtrl.markOrderAsCompleted('ord-201', userId: customerA.id!);
      expect(result, isFalse);
      expect(orderCtrl.getOrderById('ord-201')?.status, OrderStatus.delivered);
    });

    testWidgets('Profile Screen displays 5 tabs including Completed, with Mark as Completed action', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final ordPlaced = createTestOrder(
        id: 'ord-p1',
        userId: customerA.id!,
        customerName: customerA.name,
        customerEmail: customerA.email,
        status: OrderStatus.placed,
      );
      final ordDelivered = createTestOrder(
        id: 'ord-d1',
        userId: customerA.id!,
        customerName: customerA.name,
        customerEmail: customerA.email,
        status: OrderStatus.delivered,
      );

      orderCtrl.setOrdersForTesting([ordPlaced, ordDelivered]);
      authCtrl.setCurrentUser(customerA);

      await tester.pumpWidget(createTestApp(const Scaffold(body: ProfileScreen())));
      await tester.pumpAndSettle();

      // Verify all 5 tabs exist
      expect(find.byKey(const ValueKey('order_tab_all')), findsOneWidget);
      expect(find.byKey(const ValueKey('order_tab_placed')), findsOneWidget);
      expect(find.byKey(const ValueKey('order_tab_processing')), findsOneWidget);
      expect(find.byKey(const ValueKey('order_tab_delivered')), findsOneWidget);
      expect(find.byKey(const ValueKey('order_tab_completed')), findsOneWidget);

      // In All Orders, ord-p1 and ord-d1 are visible
      expect(find.text('Order #ord-p1'), findsOneWidget);
      expect(find.text('Order #ord-d1'), findsOneWidget);

      // Go to Delivered tab
      await tester.tap(find.byKey(const ValueKey('order_tab_delivered')));
      await tester.pumpAndSettle();

      // Only delivered order visible
      expect(find.text('Order #ord-d1'), findsOneWidget);
      expect(find.text('Order #ord-p1'), findsNothing);

      // Check for Mark as Completed button on delivered order
      final markCompletedBtn = find.textContaining('Mark as Completed');
      expect(markCompletedBtn, findsOneWidget);

      // Contact Support button must also be present
      expect(find.textContaining('Contact Support'), findsWidgets);

      // Tap "Mark as Completed"
      await tester.tap(markCompletedBtn);
      await tester.pumpAndSettle();

      // Delivered tab should now be empty for ord-d1
      expect(find.text('Order #ord-d1'), findsNothing);
      expect(find.textContaining('No delivered orders yet'), findsOneWidget);

      // Switch to Completed tab
      await tester.tap(find.byKey(const ValueKey('order_tab_completed')));
      await tester.pumpAndSettle();

      // ord-d1 should now be visible under Completed!
      expect(find.text('Order #ord-d1'), findsOneWidget);
      expect(find.text('Completed'), findsWidgets);

      // In Completed tab, Mark as Completed button is not visible anymore
      expect(find.textContaining('Mark as Completed'), findsNothing);
      // Contact Support is still visible
      expect(find.textContaining('Contact Support'), findsWidgets);
    });

    testWidgets('Completed orders data isolation between User A and User B', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final ordACompleted = createTestOrder(
        id: 'ord-a-comp',
        userId: customerA.id!,
        customerName: customerA.name,
        customerEmail: customerA.email,
        status: OrderStatus.completed,
      );
      final ordBCompleted = createTestOrder(
        id: 'ord-b-comp',
        userId: customerB.id!,
        customerName: customerB.name,
        customerEmail: customerB.email,
        status: OrderStatus.completed,
      );

      orderCtrl.setOrdersForTesting([ordACompleted, ordBCompleted]);

      // Login as Customer A
      authCtrl.setCurrentUser(customerA);
      await tester.pumpWidget(createTestApp(const Scaffold(body: ProfileScreen())));
      await tester.pumpAndSettle();

      // Switch to Completed tab
      await tester.tap(find.byKey(const ValueKey('order_tab_completed')));
      await tester.pumpAndSettle();

      // Customer A sees only their completed order
      expect(find.text('Order #ord-a-comp'), findsOneWidget);
      expect(find.text('Order #ord-b-comp'), findsNothing);

      // Switch to Customer B
      authCtrl.setCurrentUser(customerB);
      await tester.pumpAndSettle();

      // Customer B sees only their completed order
      expect(find.text('Order #ord-b-comp'), findsOneWidget);
      expect(find.text('Order #ord-a-comp'), findsNothing);
    });
  });

  group('Part 2: Customer Support Chat Architecture & Isolation Tests', () {
    late SupportChatService chatService;
    late SupportChatController chatCtrl;
    late AuthController authCtrl;

    setUp(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      Get.reset();

      chatService = SupportChatService();
      await chatService.init(prefs);

      authCtrl = AuthController()..init();
      Get.put(authCtrl);

      chatCtrl = SupportChatController(service: chatService);
      await chatCtrl.init();
      Get.put(chatService);
      Get.put(chatCtrl);
    });

    test('Customer can start conversation and send message', () async {
      chatCtrl.onUserChanged(customerA.id);

      await chatCtrl.initCustomerChat(
        customerId: customerA.id!,
        customerName: customerA.name,
        customerEmail: customerA.email,
        orderId: 'ord-123',
      );

      expect(chatCtrl.activeConversation, isNotNull);
      expect(chatCtrl.activeConversation?.customerId, customerA.id);
      expect(chatCtrl.activeConversation?.orderId, 'ord-123');

      // Customer sends a message
      final success = await chatCtrl.sendMessage('Hello, I need help with my delivery.');
      expect(success, isTrue);
      expect(chatCtrl.messages.length, 1);
      expect(chatCtrl.messages.first.senderRole, 'customer');
      expect(chatCtrl.messages.first.message, 'Hello, I need help with my delivery.');
    });

    test('Admin can fetch conversations, read messages, and reply to customer', () async {
      // 1. Customer A sends message
      chatCtrl.onUserChanged(customerA.id);
      await chatCtrl.initCustomerChat(
        customerId: customerA.id!,
        customerName: customerA.name,
        customerEmail: customerA.email,
        orderId: 'ord-123',
      );
      await chatCtrl.sendMessage('Customer question about order #ord-123');

      // 2. Switch to Admin
      chatCtrl.onUserChanged(adminUser.id);
      await chatCtrl.loadAdminConversations();
      expect(chatCtrl.adminConversations.isNotEmpty, isTrue);

      final targetConv = chatCtrl.adminConversations.firstWhere(
        (c) => c.customerId == customerA.id,
      );
      expect(targetConv.orderId, 'ord-123');

      // Select conversation and load messages
      await chatCtrl.openAdminConversation(targetConv);
      expect(chatCtrl.messages.length, 1);
      expect(chatCtrl.messages.first.message, 'Customer question about order #ord-123');

      // Admin sends reply
      final success = await chatCtrl.sendMessage(
        'We have checked your order and it is on schedule for delivery tomorrow.',
        sender: adminUser,
      );
      expect(success, isTrue);
      expect(chatCtrl.messages.length, 2);
      expect(chatCtrl.messages.last.senderRole, 'admin');
    });

    test('Strict user isolation: Customer B cannot see Customer A\'s conversation or messages', () async {
      // Customer A sends message
      chatCtrl.onUserChanged(customerA.id);
      await chatCtrl.initCustomerChat(
        customerId: customerA.id!,
        customerName: customerA.name,
        customerEmail: customerA.email,
        orderId: 'ord-123',
      );
      await chatCtrl.sendMessage('Confidential message from Customer A');
      expect(chatCtrl.messages.length, 1);

      // Customer B logs in
      chatCtrl.onUserChanged(customerB.id);
      // Messages should be cleared for fresh user session
      expect(chatCtrl.messages, isEmpty);
      expect(chatCtrl.activeConversation, isNull);

      // Customer B starts their own conversation
      await chatCtrl.initCustomerChat(
        customerId: customerB.id!,
        customerName: customerB.name,
        customerEmail: customerB.email,
      );
      await chatCtrl.sendMessage('Inquiry from Customer B');
      expect(chatCtrl.messages.length, 1);
      expect(chatCtrl.messages.first.message, 'Inquiry from Customer B');

      // Verify Customer A's message never leaked
      for (final m in chatCtrl.messages) {
        expect(m.message.contains('Customer A'), isFalse);
      }

      // Logout clears state completely
      chatCtrl.onUserChanged(null);
      expect(chatCtrl.activeConversation, isNull);
      expect(chatCtrl.messages, isEmpty);
    });

    testWidgets('SupportChatScreen displays order link banner and message bubbles', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      authCtrl.setCurrentUser(customerA);
      chatCtrl.onUserChanged(customerA.id);
      await chatCtrl.initCustomerChat(
        customerId: customerA.id!,
        customerName: customerA.name,
        customerEmail: customerA.email,
        orderId: 'ord-555',
      );
      await chatCtrl.sendMessage('Hello support team!');

      await tester.pumpWidget(createTestApp(const SupportChatScreen(orderId: 'ord-555')));
      await tester.pumpAndSettle();

      // Header and Order banner are visible
      expect(find.text('ShopHub Support'), findsOneWidget);
      expect(find.textContaining('Order #ord-555'), findsOneWidget);

      // Message bubble is visible
      expect(find.text('Hello support team!'), findsOneWidget);

      // Input field and send button are visible
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    });

    test('Bidirectional chat: Customer sends message, Admin receives it on admin dashboard, Admin replies, Customer receives reply', () async {
      // Step 1: Customer A initiates chat and sends an inquiry
      chatCtrl.onUserChanged(customerA.id);
      await chatCtrl.initCustomerChat(
        customerId: customerA.id!,
        customerName: customerA.name,
        customerEmail: customerA.email,
        orderId: 'ord-999',
      );
      final customerMsgSent = await chatCtrl.sendMessage('Where is my package?');
      expect(customerMsgSent, isTrue);
      expect(chatCtrl.messages.length, 1);
      expect(chatCtrl.messages.first.message, 'Where is my package?');

      final convId = chatCtrl.activeConversation!.id;

      // Step 2: Switch to Admin Dashboard view
      chatCtrl.onUserChanged(adminUser.id);
      await chatCtrl.loadAdminConversations();

      // Admin Dashboard must receive Customer A's conversation
      expect(chatCtrl.adminConversations.any((c) => c.id == convId), isTrue);
      final adminViewConv = chatCtrl.adminConversations.firstWhere((c) => c.id == convId);
      expect(adminViewConv.customerName, customerA.name);
      expect(adminViewConv.lastMessage, 'Where is my package?');
      expect(adminViewConv.unreadCount, 1);
      expect(chatCtrl.totalAdminUnreadCount, 1);

      // Admin opens the conversation
      await chatCtrl.openAdminConversation(adminViewConv);
      expect(chatCtrl.messages.length, 1);
      expect(chatCtrl.messages.first.message, 'Where is my package?');
      expect(chatCtrl.adminConversations.firstWhere((c) => c.id == convId).unreadCount, 0);

      // Admin sends reply
      final adminReplySent = await chatCtrl.sendMessage(
        'Your package is with the courier and will arrive today.',
        sender: adminUser,
      );
      expect(adminReplySent, isTrue);
      expect(chatCtrl.messages.length, 2);
      expect(chatCtrl.messages.last.senderRole, 'admin');

      // Step 3: Switch back to Customer A
      chatCtrl.onUserChanged(customerA.id);
      await chatCtrl.initCustomerChat(
        customerId: customerA.id!,
        customerName: customerA.name,
        customerEmail: customerA.email,
        orderId: 'ord-999',
      );

      // Customer receives both messages: initial message + admin reply
      expect(chatCtrl.messages.length, 2);
      expect(chatCtrl.messages.first.message, 'Where is my package?');
      expect(chatCtrl.messages.last.message, 'Your package is with the courier and will arrive today.');
      expect(chatCtrl.messages.last.senderRole, 'admin');

      // Step 4: Verify polling refresh synchronization
      await chatCtrl.refreshActiveMessages();
      expect(chatCtrl.messages.length, 2);
    });
  });

  group('Part 3: Persistent Conversations, Ticket Separation, Reopen & Delete Confirmation Tests', () {
    late SupportChatService chatService;
    late SupportChatController chatCtrl;
    late AuthController authCtrl;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      Get.reset();

      chatService = SupportChatService();
      await chatService.init(prefs);

      authCtrl = AuthController()..init();
      Get.put(authCtrl);

      chatCtrl = SupportChatController(service: chatService);
      await chatCtrl.init();
      Get.put(chatService);
      Get.put(chatCtrl);
    });

    test('Customer can create multiple tickets with distinct subjects without losing or overwriting previous tickets', () async {
      chatCtrl.onUserChanged(customerA.id);

      // Ticket 1: Delivery issue
      final t1 = await chatCtrl.createCustomerTicket(
        customerId: customerA.id!,
        customerName: customerA.name,
        customerEmail: customerA.email,
        subject: 'Delayed delivery inquiry',
        initialMessage: 'My delivery has been delayed for 2 days.',
      );
      expect(t1, isNotNull);
      expect(t1?.subject, 'Delayed delivery inquiry');

      // Ticket 2: Refund request for an order
      final t2 = await chatCtrl.createCustomerTicket(
        customerId: customerA.id!,
        customerName: customerA.name,
        customerEmail: customerA.email,
        orderId: 'ord-777',
        subject: 'Refund request for damaged item',
        initialMessage: 'The item arrived damaged, please process refund.',
      );
      expect(t2, isNotNull);
      expect(t2?.orderId, 'ord-777');
      expect(t2?.subject, 'Refund request for damaged item');

      // Both tickets must coexist in customerConversations
      expect(chatCtrl.customerConversations.length, 2);
      expect(chatCtrl.customerOpenTickets.length, 2);
      expect(chatCtrl.customerClosedTickets.length, 0);

      final fetchedIds = chatCtrl.customerConversations.map((c) => c.id).toSet();
      expect(fetchedIds.contains(t1!.id), isTrue);
      expect(fetchedIds.contains(t2!.id), isTrue);
    });

    test('Closing a ticket sets status=closed and closedAt timestamp, never deletes conversation or messages', () async {
      chatCtrl.onUserChanged(customerA.id);

      final t1 = await chatCtrl.createCustomerTicket(
        customerId: customerA.id!,
        customerName: customerA.name,
        customerEmail: customerA.email,
        subject: 'General Question',
        initialMessage: 'What are your support hours?',
      );
      expect(t1, isNotNull);

      // Customer sends a follow-up
      await chatCtrl.sendMessage('Also, do you offer weekend delivery?');
      expect(chatCtrl.messages.length, 2);

      // Close the conversation
      await chatCtrl.closeActiveConversation();

      // Conversation must be marked closed with closedAt timestamp
      expect(chatCtrl.activeConversation?.isClosed, isTrue);
      expect(chatCtrl.activeConversation?.closedAt, isNotNull);

      // Separation: 0 open tickets, 1 closed ticket
      expect(chatCtrl.customerOpenTickets.length, 0);
      expect(chatCtrl.customerClosedTickets.length, 1);

      // Critical requirement: Closing MUST NOT delete messages
      final storedMessages = await chatService.fetchMessages(t1!.id);
      expect(storedMessages.length, 2);
      expect(storedMessages[0].message, 'What are your support hours?');
      expect(storedMessages[1].message, 'Also, do you offer weekend delivery?');
    });

    test('Customer can view closed tickets and full message history remains intact', () async {
      chatCtrl.onUserChanged(customerA.id);

      await chatCtrl.createCustomerTicket(
        customerId: customerA.id!,
        customerName: customerA.name,
        customerEmail: customerA.email,
        subject: 'Product Question',
        initialMessage: 'Is this water resistant?',
      );
      await chatCtrl.sendMessage('Thanks, got it.');
      await chatCtrl.closeActiveConversation();

      // Reset active conversation to simulate leaving and reopening
      chatCtrl.clearActiveConversation();
      expect(chatCtrl.activeConversation, isNull);
      expect(chatCtrl.messages, isEmpty);

      // Reload customer conversations from service
      await chatCtrl.loadCustomerConversations(customerA.id!);
      expect(chatCtrl.customerClosedTickets.length, 1);

      // Open the closed ticket
      await chatCtrl.openConversation(chatCtrl.customerClosedTickets.first, role: 'customer');
      expect(chatCtrl.activeConversation, isNotNull);
      expect(chatCtrl.activeConversation?.isClosed, isTrue);
      expect(chatCtrl.messages.length, 2);
      expect(chatCtrl.messages.first.message, 'Is this water resistant?');
      expect(chatCtrl.messages.last.message, 'Thanks, got it.');
    });

    test('Admin portal separates open and closed tickets, and can reopen a closed ticket', () async {
      // 1. Customer creates ticket and closes it
      chatCtrl.onUserChanged(customerA.id);
      final t1 = await chatCtrl.createCustomerTicket(
        customerId: customerA.id!,
        customerName: customerA.name,
        customerEmail: customerA.email,
        subject: 'Need help with order #ord-888',
        orderId: 'ord-888',
        initialMessage: 'Package was not delivered.',
      );
      await chatCtrl.closeActiveConversation();

      // 2. Switch to Admin
      chatCtrl.onUserChanged(adminUser.id);
      await chatCtrl.loadAdminConversations();

      // Admin Open Tickets: 0, Closed Tickets: 1
      expect(chatCtrl.adminOpenTickets.length, 0);
      expect(chatCtrl.adminClosedTickets.length, 1);
      final closedTicket = chatCtrl.adminClosedTickets.first;
      expect(closedTicket.id, t1!.id);
      expect(closedTicket.isClosed, isTrue);

      // Admin opens the closed ticket
      await chatCtrl.openAdminConversation(closedTicket);
      expect(chatCtrl.messages.length, 1);
      expect(chatCtrl.messages.first.message, 'Package was not delivered.');

      // Admin reopens the ticket
      await chatCtrl.reopenActiveConversation();
      expect(chatCtrl.activeConversation?.isOpen, isTrue);
      expect(chatCtrl.activeConversation?.closedAt, isNull);
      expect(chatCtrl.adminOpenTickets.length, 1);
      expect(chatCtrl.adminClosedTickets.length, 0);

      // Admin replies on reopened ticket
      final replyOk = await chatCtrl.sendMessage(
        'We have contacted the courier and they are re-delivering today.',
        sender: adminUser,
      );
      expect(replyOk, isTrue);
      expect(chatCtrl.messages.length, 2);
    });

    test('Customer and admin can permanently delete conversation after confirmation', () async {
      chatCtrl.onUserChanged(customerA.id);
      final t1 = await chatCtrl.createCustomerTicket(
        customerId: customerA.id!,
        customerName: customerA.name,
        customerEmail: customerA.email,
        subject: 'Disposable Inquiry',
        initialMessage: 'This will be deleted.',
      );
      expect(chatCtrl.customerConversations.length, 1);

      // Delete the conversation
      final deleted = await chatCtrl.deleteConversation(t1!.id);
      expect(deleted, isTrue);

      // Removed from controller state
      expect(chatCtrl.customerConversations, isEmpty);
      expect(chatCtrl.activeConversation, isNull);
      expect(chatCtrl.messages, isEmpty);

      // Removed from service storage
      final storedAfter = await chatService.fetchConversationsForCustomer(customerA.id!);
      expect(storedAfter, isEmpty);
      final messagesAfter = await chatService.fetchMessages(t1.id);
      expect(messagesAfter, isEmpty);
    });

    testWidgets('Customer tickets hub displays Open & Closed tabs, and delete triggers exact confirmation dialog', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      authCtrl.setCurrentUser(customerA);
      chatCtrl.onUserChanged(customerA.id);

      // Create an open ticket and a closed ticket
      final openConv = await chatCtrl.createCustomerTicket(
        customerId: customerA.id!,
        customerName: customerA.name,
        customerEmail: customerA.email,
        subject: 'Open Issue Ticket',
        initialMessage: 'This ticket is open.',
      );
      expect(openConv, isNotNull);

      await tester.pumpWidget(createTestApp(const Scaffold(body: SupportChatScreen())));
      await tester.pumpAndSettle();

      // Verify Open and Closed Tabs exist
      expect(find.textContaining('Open Tickets (1)'), findsOneWidget);
      expect(find.textContaining('Closed Tickets (0)'), findsOneWidget);

      // Open ticket card is visible
      expect(find.text('Open Issue Ticket'), findsOneWidget);
      expect(find.text('OPEN'), findsOneWidget);

      // Tap delete button on the ticket card
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      // Verify exact confirmation dialog requirement
      expect(find.text('Delete Conversation'), findsWidgets);
      expect(
        find.text('Are you sure you want to delete this conversation? This action cannot be undone.'),
        findsOneWidget,
      );

      // Cancel deletion
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Ticket still exists
      expect(find.text('Open Issue Ticket'), findsOneWidget);
    });

    testWidgets('Admin Support screen displays Open and Closed tickets with reopen and delete actions', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      authCtrl.setCurrentUser(adminUser);
      chatCtrl.onUserChanged(adminUser.id);

      // Seed a ticket
      await chatService.createTicket(
        customerId: customerA.id!,
        customerName: customerA.name,
        customerEmail: customerA.email,
        subject: 'Admin Inspection Ticket',
        initialMessage: 'Customer inquiry for admin review.',
      );
      await chatCtrl.loadAdminConversations();

      await tester.pumpWidget(createTestApp(const Scaffold(body: AdminSupportScreen())));
      await tester.pumpAndSettle();

      // Verify filter chips with counts exist
      expect(find.textContaining('Open (1)'), findsOneWidget);
      expect(find.textContaining('Closed (0)'), findsOneWidget);

      // Ticket visible in list
      expect(find.text('Customer A'), findsWidgets);
      expect(find.text('Admin Inspection Ticket'), findsOneWidget);

      // Select ticket
      await tester.tap(find.text('Admin Inspection Ticket'));
      await tester.pumpAndSettle();

      // Detail view opened
      expect(find.text('Customer inquiry for admin review.'), findsWidgets);
      expect(find.text('Close Ticket'), findsOneWidget);

      // Close ticket
      await tester.tap(find.text('Close Ticket'));
      await tester.pumpAndSettle();

      // Ticket now closed; Reopen Ticket button appears
      expect(find.text('Reopen Ticket'), findsOneWidget);

      // Reopen ticket
      await tester.tap(find.text('Reopen Ticket'));
      await tester.pumpAndSettle();

      // Ticket is open again
      expect(find.text('Close Ticket'), findsOneWidget);
    });
  });
}

