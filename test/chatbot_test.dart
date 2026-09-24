import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shophub/app/routes/app_routes.dart';
import 'package:shophub/controllers/chatbot_controller.dart';
import 'package:shophub/models/cart_item.dart';
import 'package:shophub/models/order.dart';
import 'package:shophub/models/product.dart';
import 'package:shophub/services/chatbot_service.dart';
import 'package:shophub/widgets/shop_bot_fab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatbotService Guardrails & Business Logic', () {
    late ChatbotService service;

    const productInStock = Product(
      id: 'p-1',
      name: 'Wireless Bluetooth Headphones',
      categoryId: 'electronics',
      imageUrl: '',
      price: 3500,
      originalPrice: 4000,
      rating: 4.8,
      reviewCount: 120,
      shortDescription: 'Great headphones',
      description: 'Details',
      stock: 15,
    );

    setUp(() {
      // Initialize with empty Gemini key to test local fallback & guardrail engine deterministically
      service = ChatbotService(geminiApiKey: '');
    });

    test('Strict Guardrail answers off-topic questions in 1 line with ShopHub redirect', () async {
      final irrelevantQuestions = [
        ('What is the capital of France?', 'The capital of France is Paris.'),
        ('Write me python code to invert a binary tree', 'Invert a binary tree'),
        ('How do I bake a chocolate cake?', 'bake at 350°F'),
        ('Who won the world cup in 1998?', 'France won the 1998 FIFA World Cup'),
        ('Solve 45 * 299', '45 * 299 = 13455.'),
        ('What is 50 + 50?', '50 + 50 = 100.'),
        ('Who wrote Romeo and Juliet?', 'William Shakespeare wrote Romeo and Juliet.'),
      ];

      for (final (q, expectedSnippet) in irrelevantQuestions) {
        final res = await service.sendMessage(message: q);
        expect(res.isGuardrail, isTrue);
        expect(res.text, contains(expectedSnippet));
        expect(
          res.text,
          contains('I am here to assist you regarding the ShopHub app only. How can I help you with your ShopHub shopping, orders, or account today?'),
        );
        // Verify 2-part structure (1st line answer, subsequent line redirect)
        final lines = res.text.split('\n').where((l) => l.trim().isNotEmpty).toList();
        expect(lines.length, greaterThanOrEqualTo(2));
        expect(lines.first, contains(expectedSnippet));
        expect(lines.last, contains('I am here to assist you regarding the ShopHub app only'));
      }
    });

    test('Responds accurately to password reset queries', () async {
      final res = await service.sendMessage(message: 'forget password how to do it');
      expect(res.isGuardrail, isFalse);
      expect(res.text, contains('Reset Your ShopHub Password'));
      expect(res.text, contains('Account'));
      expect(res.text, contains('Forgot Password'));
    });

    test('Responds accurately to payment methods queries', () async {
      final res = await service.sendMessage(message: 'What payment methods do you support?');
      expect(res.isGuardrail, isFalse);
      expect(res.text, contains('Cash on Delivery'));
      expect(res.text, contains('Stripe'));
    });

    test('Responds accurately to return and refund policy queries', () async {
      final res = await service.sendMessage(message: 'What is your refund and return policy?');
      expect(res.isGuardrail, isFalse);
      expect(res.text, contains('7-Day Return Window'));
      expect(res.text, contains('3 to 5 business days'));
    });

    test('Responds accurately to how to place order queries', () async {
      final res = await service.sendMessage(message: 'How to place an order on this app?');
      expect(res.isGuardrail, isFalse);
      expect(res.text, contains('How to Place an Order'));
      expect(res.text, contains('Add to Cart'));
      expect(res.text, contains('Checkout'));
    });

    test('Responds accurately to customer support queries', () async {
      final res = await service.sendMessage(message: 'How can I contact customer support?');
      expect(res.isGuardrail, isFalse);
      expect(res.text, contains('support@shophub.com'));
      expect(res.text, contains('0800-SHOPHUB'));
    });

    test('Responds accurately to delivery time queries', () async {
      final res = await service.sendMessage(message: 'What is the delivery time for my area?');
      expect(res.isGuardrail, isFalse);
      expect(res.text, contains('2 to 4 business days'));
      expect(res.text, contains('Delivery Times'));
    });

    test('Responds accurately to processing time queries', () async {
      final res = await service.sendMessage(message: 'How long does order processing take?');
      expect(res.isGuardrail, isFalse);
      expect(res.text.toLowerCase(), contains('within 24 hours'));
      expect(res.text, contains('1 to 2 business days'));
    });

    test('Responds accurately to stock availability queries', () async {
      final inStockRes = await service.sendMessage(
        message: 'Is the Wireless Bluetooth Headphones available in stock?',
        localProducts: [productInStock],
      );
      expect(inStockRes.isGuardrail, isFalse);
      expect(inStockRes.text, contains('in stock'));
      expect(inStockRes.text, contains('15 unit'));

      const outOfStockProduct = Product(
        id: 'p-2',
        name: 'Smart Fitness Tracker',
        categoryId: 'electronics',
        imageUrl: '',
        price: 2500,
        originalPrice: 3000,
        rating: 4.5,
        reviewCount: 40,
        shortDescription: 'Fitness band',
        description: 'Details',
        stock: 0,
      );

      final outOfStockRes = await service.sendMessage(
        message: 'When will the Smart Fitness Tracker be in the stock?',
        localProducts: [outOfStockProduct],
      );
      expect(outOfStockRes.isGuardrail, isFalse);
      expect(outOfStockRes.text, contains('out of stock'));
      expect(outOfStockRes.text, contains('3 to 5 business days'));
    });

    test('Tracks order when order number is provided', () async {
      final sampleOrder = ShopOrder(
        id: 'ORD-9988',
        customerName: 'Ahmed Ali',
        phone: '03001234567',
        address: 'House 12, Street 4, Lahore',
        paymentMethod: 'Cash on Delivery',
        items: const [
          CartItem(
            product: productInStock,
            quantity: 1,
          ),
        ],
        total: 5000,
        createdAt: DateTime.now(),
        status: OrderStatus.processing,
      );

      final res = await service.sendMessage(
        message: 'Where is my order ORD-9988?',
        localOrders: [sampleOrder],
      );

      expect(res.orderId, 'ORD-9988');
      expect(res.text, contains('ORD-9988'));
      expect(res.text.toUpperCase(), contains('PROCESSING'));
      expect(res.text, contains('Lahore'));
    });
  });

  group('Gemini AI Configuration & Client Integration', () {
    test('exposes user-configured Gemini constants', () {
      expect(ChatbotService.defaultGeminiApiKey, 'AIzaSyCDIEz5yERvB7ip2Iicdy0d8sZUFZN-vNE');
      expect(ChatbotService.defaultGeminiModel, 'gemini-flash-latest');
      expect(ChatbotService.defaultGeminiUrl, 'https://generativelanguage.googleapis.com/v1beta/models');
    });

    test('parses Gemini API responses with order tracking and suggestions', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), contains('generativelanguage.googleapis.com'));
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': 'Your order #ORD-1234 is currently SHIPPED and will arrive in 2 business days.',
                    }
                  ]
                }
              }
            ]
          }),
          200,
        );
      });

      final geminiService = ChatbotService(
        httpClient: mockClient,
      );

      final reply = await geminiService.sendMessage(message: 'Where is my order ORD-1234?');
      expect(reply.isUser, isFalse);
      expect(reply.text, contains('ORD-1234'));
      expect(reply.text, contains('SHIPPED'));
      expect(reply.orderId, 'ORD-1234');
      expect(reply.quickReplies.isNotEmpty, isTrue);
    });

    test('identifies Gemini guardrail refusal accurately', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': 'I am here to assist you regarding the ShopHub app only. How can I help you with your ShopHub shopping, orders, or account today?',
                    }
                  ]
                }
              }
            ]
          }),
          200,
        );
      });

      final geminiService = ChatbotService(httpClient: mockClient);
      final reply = await geminiService.sendMessage(message: 'Help me with python code');
      expect(reply.isGuardrail, isTrue);
      expect(reply.text, contains('I am here to assist you regarding the ShopHub app only'));
    });

    test('handles off-topic query with 1-line answer and next line ShopHub redirect', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': 'The capital of France is Paris.\nI am here to assist you regarding the ShopHub app only. How can I help you with your ShopHub shopping, orders, or account today?',
                    }
                  ]
                }
              }
            ]
          }),
          200,
        );
      });

      final geminiService = ChatbotService(httpClient: mockClient);
      final reply = await geminiService.sendMessage(message: 'What is the capital of France?');
      expect(reply.isGuardrail, isTrue);
      expect(reply.text, contains('The capital of France is Paris.'));
      expect(reply.text, contains('I am here to assist you regarding the ShopHub app only'));
    });
  });

  group('ChatbotController (GetX)', () {
    late ChatbotController ctrl;

    setUp(() {
      Get.reset();
      ctrl = ChatbotController()..init();
    });

    test('initializes with greeting message and quick replies', () {
      expect(ctrl.isInitialized, isTrue);
      expect(ctrl.messages.isNotEmpty, isTrue);
      expect(ctrl.messages.first.isUser, isFalse);
      expect(ctrl.messages.first.text, contains('ShopBot'));
      expect(ctrl.messages.first.quickReplies.isNotEmpty, isTrue);
    });

    test('sendMessage adds user message and bot response', () async {
      final initialCount = ctrl.messages.length;
      await ctrl.sendMessage('What is the delivery time?');

      expect(ctrl.messages.length, initialCount + 2);
      expect(ctrl.messages[initialCount].isUser, isTrue);
      expect(ctrl.messages[initialCount].text, 'What is the delivery time?');
      expect(ctrl.messages[initialCount + 1].isUser, isFalse);
      expect(ctrl.messages[initialCount + 1].text, contains('Delivery Times'));
    });

    test('handles consecutive questions in sequence without stopping or getting stuck', () async {
      await ctrl.sendMessage('What is the capital of France?');
      expect(ctrl.isTyping, isFalse);
      expect(ctrl.messages.last.text, contains('The capital of France is Paris.'));
      expect(ctrl.messages.last.text, contains('I am here to assist you regarding the ShopHub app only'));

      await ctrl.sendMessage('What is 50 + 50?');
      expect(ctrl.isTyping, isFalse);
      expect(ctrl.messages.last.text, contains('50 + 50 = 100.'));
      expect(ctrl.messages.last.text, contains('I am here to assist you regarding the ShopHub app only'));

      await ctrl.sendMessage('How to reset password?');
      expect(ctrl.isTyping, isFalse);
      expect(ctrl.messages.last.text, contains('Reset Your ShopHub Password'));

      await ctrl.sendMessage('Who wrote Romeo and Juliet?');
      expect(ctrl.isTyping, isFalse);
      expect(ctrl.messages.last.text, contains('William Shakespeare wrote Romeo and Juliet.'));
      expect(ctrl.messages.last.text, contains('I am here to assist you regarding the ShopHub app only'));
    });

    test('clearChat resets messages back to welcome message', () async {
      await ctrl.sendMessage('Hello');
      expect(ctrl.messages.length, greaterThan(1));

      await ctrl.clearChat();
      expect(ctrl.messages.length, 1);
      expect(ctrl.messages.first.isUser, isFalse);
    });
  });

  group('ShopBotFab Widget', () {
    testWidgets('renders floating button with ShopBot AI label and icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            AppRoutes.chatbot: (_) => const Scaffold(body: Text('Chatbot Screen')),
          },
          home: const Scaffold(
            floatingActionButton: ShopBotFab(),
          ),
        ),
      );

      expect(find.byType(ShopBotFab), findsOneWidget);
      expect(find.text('ShopBot AI'), findsOneWidget);
      expect(find.byIcon(Icons.smart_toy_rounded), findsOneWidget);

      // Tap FAB to navigate to chatbot screen
      await tester.tap(find.byType(ShopBotFab));
      await tester.pumpAndSettle();
      expect(find.text('Chatbot Screen'), findsOneWidget);
    });
  });
}
