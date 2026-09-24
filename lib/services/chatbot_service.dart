import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_message.dart';
import '../models/order.dart';
import '../models/product.dart';

/// Chatbot Service
/// Communicates with Google Gemini AI and the Supabase Edge Function 'shopbot'.
/// Features live Supabase order tracking, app assistance, and strict domain guardrails.
class ChatbotService {
  static const _kChatHistory = 'shophub.chat_history';

  // Configured Gemini API constants
  static const defaultGeminiApiKey = 'AIzaSyCDIEz5yERvB7ip2Iicdy0d8sZUFZN-vNE';
  static const defaultGeminiModel = 'gemini-flash-latest';
  static const defaultGeminiUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  final String geminiApiKey;
  final String geminiModel;
  final String geminiUrl;
  final http.Client _httpClient;

  ChatbotService({
    this.geminiApiKey = defaultGeminiApiKey,
    this.geminiModel = defaultGeminiModel,
    this.geminiUrl = defaultGeminiUrl,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  SharedPreferences? _prefs;

  bool get hasSupabase {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> init([SharedPreferences? prefs]) async {
    _prefs = prefs ?? await SharedPreferences.getInstance();
  }

  /// Loads persisted chat messages from local storage.
  List<ChatMessage> loadChatHistory() {
    final prefs = _prefs;
    if (prefs == null) return [];

    final raw = prefs.getString(_kChatHistory);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List;
        return decoded
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return [];
      }
    }
    return [];
  }

  /// Saves chat messages to local storage.
  Future<void> saveChatHistory(List<ChatMessage> messages) async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      // Keep up to last 50 messages to save space
      final trimmed = messages.length > 50
          ? messages.sublist(messages.length - 50)
          : messages;
      final encoded = jsonEncode(trimmed.map((e) => e.toJson()).toList());
      await prefs.setString(_kChatHistory, encoded);
    } catch (_) {}
  }

  /// Clears chat history in local storage.
  Future<void> clearChatHistory() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.remove(_kChatHistory);
  }

  /// Sends user message to the AI Chatbot.
  /// 1. Filters out irrelevant off-topic queries immediately via domain guardrails.
  /// 2. Tries invoking the Supabase Edge Function 'shopbot'.
  /// 3. If Edge Function is unavailable or throws, calls Gemini AI directly with live order & product context.
  /// 4. If network is offline, falls back to the local deterministic rule engine.
  Future<ChatMessage> sendMessage({
    required String message,
    String? userId,
    String? userName,
    String? userPhone,
    String? orderId,
    List<ChatMessage> history = const [],
    List<ShopOrder> localOrders = const [],
    List<Product> localProducts = const [],
  }) async {
    final cleanMessage = message.trim();

    // 1. Direct Gemini AI Call with Live Supabase Context Grounding (Primary AI Engine)
    if (geminiApiKey.isNotEmpty) {
      final geminiMsg = await _callGemini(
        message: cleanMessage,
        history: history,
        localOrders: localOrders,
        localProducts: localProducts,
        userName: userName,
        orderId: orderId,
      );

      if (geminiMsg != null) {
        return geminiMsg;
      }
    }

    // 2. Try invoking the Supabase Edge Function 'shopbot' (if Edge Function is deployed)
    if (hasSupabase) {
      try {
        final response = await Supabase.instance.client.functions.invoke(
          'shopbot',
          body: {
            'message': cleanMessage,
            'userId': userId,
            'customerName': userName,
            'customerPhone': userPhone,
            'orderId': orderId,
            'conversationHistory': history.take(6).map((m) => {
              'role': m.isUser ? 'user' : 'assistant',
              'content': m.text,
            }).toList(),
          },
        );

        if (response.status == 200 && response.data != null) {
          final data = response.data;
          final replyText = (data['reply'] as String?) ?? '';
          final quickReplies = (data['quickReplies'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const <String>[];
          final respOrderId = data['orderId'] as String?;
          final isGuardrail = data['isGuardrail'] as bool? ?? false;

          if (replyText.isNotEmpty) {
            return ChatMessage(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              text: replyText,
              isUser: false,
              timestamp: DateTime.now(),
              quickReplies: quickReplies,
              orderId: respOrderId,
              isGuardrail: isGuardrail,
            );
          }
        }
      } catch (e) {
        debugPrint('Supabase Edge Function "shopbot" invoke failed: $e');
      }
    }

    // 3. Local Deterministic Rule Fallback (if completely offline or Gemini rate-limited)
    return _generateLocalResponse(
      message: cleanMessage,
      orderId: orderId,
      localOrders: localOrders,
      localProducts: localProducts,
    );
  }

  /// Calls Google Gemini API with fallback across flash models.
  Future<ChatMessage?> _callGemini({
    required String message,
    List<ChatMessage> history = const [],
    List<ShopOrder> localOrders = const [],
    List<Product> localProducts = const [],
    String? userName,
    String? orderId,
  }) async {
    final modelsToTry = [
      'gemini-flash-lite-latest',
      'gemini-3.6-flash',
      geminiModel,
    ];

    final systemInstruction = _buildSystemPrompt(
      localOrders: localOrders,
      localProducts: localProducts,
      userName: userName,
    );

    // Look for order ID in query
    final explicitOrderId = orderId ?? extractOrderId(message);

    for (final model in modelsToTry.toSet()) {
      try {
        final endpoint = Uri.parse('$geminiUrl/$model:generateContent?key=$geminiApiKey');
        final response = await _httpClient.post(
          endpoint,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': '$systemInstruction\n\n[USER QUESTION]\n$message'}
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.2,
              'maxOutputTokens': 400,
            }
          }),
        ).timeout(const Duration(milliseconds: 3500));

        if (response.statusCode == 429) {
          debugPrint('Gemini model $model returned HTTP 429 (quota limit). Falling back to fast local engine.');
          break;
        }

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final parts = decoded['candidates']?[0]?['content']?['parts'] as List?;
          final textPart = parts?.firstWhere(
            (p) => p['text'] != null && p['text'].toString().trim().isNotEmpty,
            orElse: () => null,
          );
          final text = textPart?['text']?.toString().trim();

          if (text != null && text.isNotEmpty) {
            String formattedText = text;
            final isRefusal = text.contains('I am here to assist you regarding the ShopHub app only');
            final isOffTopic = isRefusal || !_isRelevantQuery(message.toLowerCase());

            if (isOffTopic && !isRefusal) {
              final firstLine = formattedText.split('\n').firstWhere(
                (l) => l.trim().isNotEmpty,
                orElse: () => formattedText,
              ).trim();
              formattedText = '$firstLine\nI am here to assist you regarding the ShopHub app only. How can I help you with your ShopHub shopping, orders, or account today?';
            }

            // Find matching order in local context
            String? matchedId = explicitOrderId;
            if (matchedId == null && localOrders.isNotEmpty && (message.toLowerCase().contains('order') || message.toLowerCase().contains('track'))) {
              matchedId = localOrders.first.id;
            }

            final quickReplies = matchedId != null
                ? const ["What is the delivery time?", "Processing time details", "Contact support"]
                : const [
                    "Track my order",
                    "How to reset password?",
                    "What is the delivery time?",
                    "Payment options",
                  ];

            return ChatMessage(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              text: formattedText,
              isUser: false,
              timestamp: DateTime.now(),
              quickReplies: quickReplies,
              orderId: matchedId,
              isGuardrail: isOffTopic,
            );
          }
        }
      } on TimeoutException {
        debugPrint('Gemini API call timed out after 3.5s, switching to fast local solver.');
        break;
      } catch (e) {
        debugPrint('Gemini API call to model $model failed: $e');
      }
    }
    return null;
  }

  /// Builds system prompt training Gemini on ShopHub app features and Supabase context.
  String _buildSystemPrompt({
    List<ShopOrder> localOrders = const [],
    List<Product> localProducts = const [],
    String? userName,
  }) {
    var prompt = '''
You are ShopBot, the dedicated official AI customer support assistant for the ShopHub mobile e-commerce application.

YOUR CORE BEHAVIOR & RESPONSE RULES:
1. SHOPHUB APP QUESTIONS:
   If the customer asks about the ShopHub app (including password reset, account management, registration, login, order tracking, delivery times, processing times, product stock, payment options COD & Stripe, returns and refunds, or helpline):
   Provide a detailed, helpful, and friendly response with clear markdown bullet points and emojis.

2. ANYTHING ELSE / GENERAL QUESTIONS (Non-ShopHub Topics):
   If the customer asks ANYTHING ELSE that is not related to ShopHub (such as general knowledge, coding, python/java code, math, history, science, recipes, weather, definitions, casual chitchat):
   Answer their question in EXACTLY 1 concise line.
   Then, on the very next line, you MUST say:
   "I am here to assist you regarding the ShopHub app only. How can I help you with your ShopHub shopping, orders, or account today?"

SHOPHUB APP KNOWLEDGE BASE:
- How to Reset Password:
  1. Open the ShopHub app and tap on the 'Account' tab at the bottom right.
  2. If logged out, tap 'Forgot Password?' on the Login screen.
  3. Enter your registered ShopHub email address.
  4. Check your email for the password recovery link.
  5. Open the link to set your new password and sign back into ShopHub.
- Account Registration & Login:
  * New users can tap Register in the Account tab and sign up with their name, email, and password.
  * To log out, visit the Account tab and tap 'Log Out'.
- Delivery Times:
  * Major metropolitan cities: 2 to 4 business days.
  * Regional and nationwide delivery: 3 to 7 business days.
  * Express delivery: 24 to 48 hours where available.
- Processing Times:
  * Order verification & warehouse packaging takes within 24 hours of placement.
  * Courier dispatch is handled in 1 to 2 business days (Monday to Saturday).
- Product Stock & Restocking:
  * Listed items show live stock.
  * If an item is out of stock, it is restocked within 3 to 5 business days. Customers can add it to their Wishlist to receive an instant restock alert.
- Payment Methods:
  1. Cash on Delivery (COD) - Pay with cash upon doorstep delivery.
  2. Secure Card Payment (Stripe) - Visa, MasterCard, credit and debit cards.
- Return, Refund & Cancellation Policy:
  * 7-day hassle-free return window for damaged, defective, or incorrect items.
  * Free cancellation before the order is dispatched (while status is 'Placed').
  * Approved refunds are processed in 3 to 5 business days back to the original payment method.
- Customer Helpline & Support:
  * Email: support@shophub.com
  * Toll-Free Helpline: 0800-SHOPHUB (0800-7467482)
  * Operating Hours: Mon-Sat, 9:00 AM - 6:00 PM.

ORDER TRACKING GUIDELINES:
- When a user asks about an order or provides an Order ID (like ORD-xxxx or SH-xxxx), check the [LINKED SUPABASE ORDERS DATA] below.
- If order data is present, present the Order ID, status (Placed, Processing, Shipped, Delivered, Cancelled), recipient name, delivery address, items, and total amount with markdown bullet points and emojis.
- If the Order ID is not in their records, inform them politely and suggest checking the Account > Orders section or double-checking the order number.
''';

    if (localOrders.isNotEmpty) {
      final ordersStr = localOrders.take(5).map((o) =>
        'Order ID: ${o.id}, Status: ${o.status.name.toUpperCase()}, Customer: ${o.customerName}, Address: ${o.address}, Total: Rs. ${o.total.toStringAsFixed(0)}, Items: ${o.items.map((i) => '${i.product.name} (x${i.quantity})').join(', ')}'
      ).join('\n');
      prompt += '\n[LINKED SUPABASE ORDERS DATA]\n$ordersStr\n';
    }

    if (localProducts.isNotEmpty) {
      final productsStr = localProducts.take(15).map((p) =>
        'Product: ${p.name}, Price: Rs. ${p.price.toStringAsFixed(0)}, Stock: ${p.stock}'
      ).join('\n');
      prompt += '\n[LINKED SUPABASE PRODUCTS DATA]\n$productsStr\n';
    }

    return prompt;
  }

  /// Generates a fast, intelligent 1-line answer for off-topic/general knowledge queries.
  String _generateOffTopicAnswer(String message) {
    final lower = message.toLowerCase().trim();

    // 1. Math calculation solver (e.g. "solve 45 * 299", "what is 50 + 50", "100 / 4")
    final mathMatch = RegExp(
      r'(?:solve|calculate|what is)?\s*(-?\d+(?:\.\d+)?)\s*([\+\-\*\/xX]|times|plus|minus|divided by)\s*(-?\d+(?:\.\d+)?)\s*\??',
      caseSensitive: false,
    ).firstMatch(lower);

    if (mathMatch != null) {
      try {
        final n1 = double.parse(mathMatch.group(1)!);
        final op = mathMatch.group(2)!.trim();
        final n2 = double.parse(mathMatch.group(3)!);
        double? result;

        if (op == '+' || op == 'plus') {
          result = n1 + n2;
        } else if (op == '-' || op == 'minus') {
          result = n1 - n2;
        } else if (op == '*' || op == 'x' || op == 'X' || op == 'times') {
          result = n1 * n2;
        } else if (op == '/' || op == 'divided by') {
          if (n2 != 0) result = n1 / n2;
        }

        if (result != null) {
          final resStr = result == result.roundToDouble()
              ? result.toInt().toString()
              : result.toStringAsFixed(2);
          final n1Str = n1 == n1.roundToDouble() ? n1.toInt().toString() : n1.toString();
          final n2Str = n2 == n2.roundToDouble() ? n2.toInt().toString() : n2.toString();
          return "$n1Str ${op == 'times' ? '*' : op == 'plus' ? '+' : op == 'minus' ? '-' : op} $n2Str = $resStr.";
        }
      } catch (_) {}
    }

    // 2. Geography & Capitals
    if (lower.contains('capital')) {
      if (lower.contains('france')) return 'The capital of France is Paris.';
      if (lower.contains('canada')) return 'The capital of Canada is Ottawa.';
      if (lower.contains('usa') || lower.contains('united states') || lower.contains('america')) return 'The capital of the United States is Washington, D.C.';
      if (lower.contains('uk') || lower.contains('united kingdom') || lower.contains('england')) return 'The capital of the United Kingdom is London.';
      if (lower.contains('pakistan')) return 'The capital of Pakistan is Islamabad.';
      if (lower.contains('india')) return 'The capital of India is New Delhi.';
      if (lower.contains('germany')) return 'The capital of Germany is Berlin.';
      if (lower.contains('australia')) return 'The capital of Australia is Canberra.';
      if (lower.contains('japan')) return 'The capital of Japan is Tokyo.';
      if (lower.contains('china')) return 'The capital of China is Beijing.';
      if (lower.contains('italy')) return 'The capital of Italy is Rome.';
      if (lower.contains('spain')) return 'The capital of Spain is Madrid.';
      if (lower.contains('russia')) return 'The capital of Russia is Moscow.';
      if (lower.contains('turkey')) return 'The capital of Turkey is Ankara.';
      if (lower.contains('brazil')) return 'The capital of Brazil is Brasília.';
    }

    // 3. World Leaders & Presidents
    if (lower.contains('president') || lower.contains('prime minister') || lower.contains('leader')) {
      if (lower.contains('france')) return 'The current president of France is Emmanuel Macron.';
      if (lower.contains('usa') || lower.contains('united states') || lower.contains('us') || lower.contains('america')) return 'The current president of the United States is Joe Biden.';
      if (lower.contains('pakistan')) return 'The prime minister of Pakistan is Shehbaz Sharif.';
      if (lower.contains('uk') || lower.contains('united kingdom')) return 'The prime minister of the United Kingdom is Keir Starmer.';
      if (lower.contains('india')) return 'The prime minister of India is Narendra Modi.';
      if (lower.contains('russia')) return 'The president of Russia is Vladimir Putin.';
      if (lower.contains('canada')) return 'The prime minister of Canada is Justin Trudeau.';
    }

    // 4. Literature & Art
    if (lower.contains('romeo and juliet') || lower.contains('shakespeare')) {
      return 'William Shakespeare wrote Romeo and Juliet.';
    }
    if (lower.contains('harry potter') || lower.contains('rowling')) {
      return 'J.K. Rowling wrote the Harry Potter series.';
    }
    if (lower.contains('mona lisa') || lower.contains('da vinci')) {
      return 'Leonardo da Vinci painted the Mona Lisa.';
    }

    // 5. Programming & Algorithms
    if (lower.contains('binary tree')) {
      return 'Invert a binary tree by swapping each node\'s left and right child pointers recursively (root.left, root.right = root.right, root.left).';
    }
    if (lower.contains('python') || lower.contains('code') || lower.contains('program') || lower.contains('java') || lower.contains('c++')) {
      if (lower.contains('sort')) {
        return 'You can sort an array using built-in methods like .sort() or algorithms like Quicksort and Mergesort.';
      }
      return 'Programming languages like Python and Java use structured syntax, functions, and object-oriented principles.';
    }

    // 6. Cooking & Recipes
    if (lower.contains('cake') || lower.contains('bake')) {
      return 'Combine flour, sugar, cocoa powder, eggs, milk, and bake at 350°F (175°C) for about 30 minutes.';
    }
    if (lower.contains('tea') || lower.contains('coffee')) {
      return 'Brew tea leaves or ground coffee beans in boiling water, then add milk or sweetener to taste.';
    }
    if (lower.contains('recipe') || lower.contains('cook')) {
      return 'Follow standard culinary steps: prepare fresh ingredients, season appropriately, and cook at the proper temperature.';
    }

    // 7. Sports & World Cups
    if (lower.contains('world cup')) {
      if (lower.contains('1998')) return 'France won the 1998 FIFA World Cup by defeating Brazil 3-0.';
      if (lower.contains('2022')) return 'Argentina won the 2022 FIFA World Cup.';
      if (lower.contains('2018')) return 'France won the 2018 FIFA World Cup.';
      if (lower.contains('2014')) return 'Germany won the 2014 FIFA World Cup.';
      if (lower.contains('1992')) return 'Pakistan won the 1992 Cricket World Cup.';
      return 'The FIFA World Cup is the premier international soccer tournament held every four years.';
    }

    // 8. Jokes & Humor
    if (lower.contains('joke')) {
      if (lower.contains('dog')) return 'What kind of dog does a magician have? A Labracadabrador!';
      if (lower.contains('cat')) return 'Why was the cat sitting on the computer? To keep an eye on the mouse!';
      return 'Why don\'t scientists trust atoms? Because they make up everything!';
    }

    // 9. Science, Nature & Space
    if (lower.contains('speed of light')) return 'The speed of light in a vacuum is approximately 299,792 kilometers per second.';
    if (lower.contains('boiling point')) return 'Water boils at 100°C (212°F) under standard atmospheric pressure.';
    if (lower.contains('planets') || lower.contains('solar system')) return 'There are 8 planets in our solar system: Mercury, Venus, Earth, Mars, Jupiter, Saturn, Uranus, and Neptune.';
    if (lower.contains('sky') && lower.contains('blue')) return 'The sky appears blue because molecules in Earth\'s atmosphere scatter short-wavelength blue sunlight.';
    if (lower.contains('largest animal') || lower.contains('largest mammal')) return 'The blue whale is the largest animal on Earth.';
    if (lower.contains('fastest animal')) return 'The cheetah is the fastest land animal, running up to 120 km/h (75 mph).';

    // 10. Weather & Time
    if (lower.contains('weather')) return 'Weather conditions vary by location; please check a dedicated weather service for your area.';
    if (lower.contains('time') || lower.contains('date')) return 'Please check your device\'s system clock for the current local time and date.';

    // 11. General Fallback
    if (lower.startsWith('who is') || lower.startsWith('who was')) {
      return 'That person is a recognized public or historical figure.';
    }
    if (lower.startsWith('what is') || lower.startsWith('what are')) {
      return 'That is a recognized concept in general knowledge.';
    }
    if (lower.startsWith('where is')) {
      return 'That location can be referenced on international mapping services.';
    }
    if (lower.startsWith('how to') || lower.startsWith('how do')) {
      return 'Detailed steps for that task can be found in general educational resources.';
    }

    return 'That is an interesting topic outside the scope of retail shopping.';
  }

  /// Evaluates query locally to ensure continuous assistance even if offline or if Edge Function is still deploying.
  ChatMessage _generateLocalResponse({
    required String message,
    String? orderId,
    List<ShopOrder> localOrders = const [],
    List<Product> localProducts = const [],
  }) {
    final lower = message.toLowerCase().trim();

    // If query is off-topic and local fallback is used, provide the 1-line answer and guardrail redirect
    if (!_isRelevantQuery(lower)) {
      final answer = _generateOffTopicAnswer(message);
      return ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: "$answer\nI am here to assist you regarding the ShopHub app only. How can I help you with your ShopHub shopping, orders, or account today?",
        isUser: false,
        timestamp: DateTime.now(),
        isGuardrail: true,
        quickReplies: const [
          "How to reset password?",
          "Track my order",
          "What is the delivery time?",
          "Payment options",
        ],
      );
    }

    // Password reset / Forgot password inquiries
    if (lower.contains('password') ||
        (lower.contains('forgot') && (lower.contains('pass') || lower.contains('account') || lower.contains('login'))) ||
        lower.contains('reset')) {
      return ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: "🔑 **How to Reset Your ShopHub Password:**\n\n"
            "1. Tap the **Account** tab in the bottom navigation bar.\n"
            "2. If you are not logged in, tap **'Forgot Password?'** on the login screen.\n"
            "3. Enter the email address registered with your ShopHub account.\n"
            "4. Check your email for the password recovery link.\n"
            "5. Click the link to set your new password and sign back in!\n\n"
            "💡 *Tip:* Check your spam or junk folder if you don't receive the email within 2 minutes.",
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: const [
          "How to create account",
          "Track my order",
          "Contact support",
        ],
      );
    }

    // Account registration & login inquiries
    if (lower.contains('register') ||
        lower.contains('sign up') ||
        lower.contains('create account') ||
        lower.contains('login') ||
        lower.contains('sign in') ||
        lower.contains('logout') ||
        lower.contains('log out') ||
        lower.contains('profile')) {
      if (lower.contains('logout') || lower.contains('log out')) {
        return ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          text: "🚪 **How to Log Out:**\n\n"
              "1. Navigate to the **Account** tab at the bottom right.\n"
              "2. Scroll down and tap the red **'Log Out'** button to safely end your session.",
          isUser: false,
          timestamp: DateTime.now(),
          quickReplies: const [
            "How to reset password?",
            "How to create account",
          ],
        );
      }
      return ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: "👤 **ShopHub Account & Registration:**\n\n"
            "• **New Users:** Go to Account > tap **Register**, enter your name, email, and password.\n"
            "• **Existing Users:** Enter your credentials on the Login screen.\n"
            "• **Edit Profile:** Visit the Account tab to review your name, phone number, and shipping addresses.",
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: const [
          "How to reset password?",
          "Track my order",
          "Payment options",
        ],
      );
    }

    // Payment methods inquiries
    if (lower.contains('payment') ||
        lower.contains('pay') ||
        lower.contains('cash on delivery') ||
        lower.contains('cod') ||
        lower.contains('stripe') ||
        lower.contains('card') ||
        lower.contains('credit') ||
        lower.contains('debit')) {
      return ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: "💳 **ShopHub Payment Methods:**\n\n"
            "1. 💵 **Cash on Delivery (COD):** Pay with cash when the courier delivers your package to your doorstep.\n"
            "2. 💳 **Online Card Payment (Stripe):** We accept Visa, MasterCard, and debit/credit cards securely powered by Stripe.\n\n"
            "All online transactions are encrypted with 256-bit SSL security.",
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: const [
          "What is the delivery time?",
          "How to place an order?",
          "Return & refund policy",
        ],
      );
    }

    // Return & refund policy inquiries
    if (lower.contains('refund') ||
        lower.contains('return') ||
        lower.contains('cancel') ||
        lower.contains('exchange') ||
        lower.contains('warranty') ||
        lower.contains('damaged')) {
      return ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: "🔄 **ShopHub Return & Refund Policy:**\n\n"
            "• **7-Day Return Window:** You can return eligible items within 7 days of delivery if damaged, defective, or incorrect.\n"
            "• **Order Cancellation:** Orders can be cancelled free of charge before they are dispatched (status: Placed).\n"
            "• **Refund Processing:** Approved refunds are processed within **3 to 5 business days** back to your original payment method.",
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: const [
          "Track my order",
          "Contact support",
          "Delivery times",
        ],
      );
    }

    // How to order inquiries
    if (lower.contains('how to order') ||
        lower.contains('place an order') ||
        lower.contains('how to buy') ||
        lower.contains('checkout') ||
        lower.contains('cart')) {
      return ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: "🛒 **How to Place an Order on ShopHub:**\n\n"
            "1. **Browse Products:** Search or select items from categories on the Home screen.\n"
            "2. **Add to Cart:** Select your desired quantity and tap **Add to Cart**.\n"
            "3. **Proceed to Checkout:** Open the Cart tab and tap **Checkout**.\n"
            "4. **Enter Shipping Details:** Provide your name, contact phone, and delivery address.\n"
            "5. **Select Payment:** Choose Cash on Delivery or Card Payment and tap **Place Order**!\n\n"
            "You'll immediately receive an Order ID to track your package.",
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: const [
          "Payment options",
          "Delivery times",
          "Track my order",
        ],
      );
    }

    // Customer support inquiries
    if (lower.contains('contact') ||
        lower.contains('support') ||
        lower.contains('helpline') ||
        lower.contains('call') ||
        lower.contains('email') ||
        lower.contains('agent') ||
        lower.contains('human')) {
      return ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: "📞 **ShopHub Customer Support:**\n\n"
            "• **Email:** support@shophub.com\n"
            "• **Toll-Free Helpline:** 0800-SHOPHUB (0800-7467482)\n"
            "• **Operating Hours:** Monday to Saturday, 9:00 AM – 6:00 PM\n"
            "• **Live AI Support:** I am available 24/7 right here in the app!",
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: const [
          "Track my order",
          "How to reset password?",
          "Return & refund policy",
        ],
      );
    }

    // Delivery time inquiries
    if (lower.contains('delivery time') ||
        (lower.contains('how long') &&
            (lower.contains('deliver') || lower.contains('arrive') || lower.contains('reach'))) ||
        lower.contains('shipping time')) {
      return ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: "🚚 **ShopHub Delivery Times:**\n\n"
            "• **Major Metropolitan Cities:** 2 to 4 business days.\n"
            "• **Regional & Nationwide Shipping:** 3 to 7 business days.\n"
            "• **Express Shipping:** 24 to 48 hours (where available).\n\n"
            "All orders are dispatched with live tracking so you can monitor your package step by step!",
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: const [
          "Order processing time",
          "Track my order",
          "When will out-of-stock items restock?",
        ],
      );
    }

    // Processing time inquiries
    if (lower.contains('process') ||
        lower.contains('processing time') ||
        lower.contains('dispatch time') ||
        lower.contains('prepare')) {
      return ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: "⏱️ **ShopHub Order Processing Time:**\n\n"
            "• **Order Verification & Packaging:** Within 24 hours of order placement.\n"
            "• **Courier Handover:** Dispatched within 1 to 2 business days.\n"
            "• Processing operates Monday through Saturday (excluding national holidays).\n\n"
            "Once dispatched, you will receive an in-app tracking update!",
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: const [
          "What is the delivery time?",
          "Track my order",
          "When will out-of-stock items restock?",
        ],
      );
    }

    // Product stock inquiries
    if (lower.contains('stock') ||
        lower.contains('available') ||
        lower.contains('restock')) {
      Product? matchedProduct;
      for (final p in localProducts) {
        if (lower.contains(p.name.toLowerCase())) {
          matchedProduct = p;
          break;
        }
      }

      if (matchedProduct != null) {
        if (matchedProduct.stock > 0) {
          return ChatMessage(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            text: "✅ **${matchedProduct.name}** is currently **in stock** with ${matchedProduct.stock} unit(s) available at Rs. ${matchedProduct.price.toStringAsFixed(0)}.\n\nYou can add it to your cart directly from the product page.",
            isUser: false,
            timestamp: DateTime.now(),
            quickReplies: const [
              "What is the delivery time?",
              "How long does processing take?",
              "Track my order",
            ],
          );
        } else {
          return ChatMessage(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            text: "⏳ **${matchedProduct.name}** is currently out of stock.\n\nOur restocking timeline typically takes **3 to 5 business days**. You can add this item to your Wishlist to receive an alert the moment it returns to stock!",
            isUser: false,
            timestamp: DateTime.now(),
            quickReplies: const [
              "What is the delivery time?",
              "Explore other products",
              "Contact customer care",
            ],
          );
        }
      }

      return ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: "📦 **Stock & Restocking Policy:**\n\n"
            "• Most items in ShopHub are kept in stock and ready to ship.\n"
            "• Out-of-stock items are typically restocked within **3 to 5 business days**.\n"
            "• High-demand electronics or imported goods may take up to 7 business days.\n\n"
            "Which product are you interested in? Tell me the product name and I'll check its current stock!",
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: const [
          "What is the delivery time?",
          "Processing time details",
          "Track my order",
        ],
      );
    }

    // Order tracking inquiries
    final queryOrderId = orderId ?? extractOrderId(message);

    if (queryOrderId != null || lower.contains('track') || lower.contains('my order')) {
      ShopOrder? foundOrder;
      if (queryOrderId != null) {
        try {
          foundOrder = localOrders.firstWhere(
            (o) => o.id.toLowerCase() == queryOrderId.toLowerCase() ||
                o.id.toLowerCase().contains(queryOrderId.toLowerCase()),
          );
        } catch (_) {}
      } else if (localOrders.isNotEmpty) {
        foundOrder = localOrders.first;
      }

      if (foundOrder != null) {
        final statusMap = {
          OrderStatus.placed: 'Placed (Warehouse verification in progress)',
          OrderStatus.processing: 'Processing (Being packed in warehouse)',
          OrderStatus.shipped: 'Shipped (Handed over to courier partner)',
          OrderStatus.delivered: 'Delivered (Successfully received)',
        };

        return ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          text: "📦 **Order #${foundOrder.id} Status:**\n\n"
              "• **Current Status:** ${statusMap[foundOrder.status] ?? foundOrder.status.name.toUpperCase()}\n"
              "• **Recipient:** ${foundOrder.customerName}\n"
              "• **Shipping Address:** ${foundOrder.address}\n"
              "• **Items:** ${foundOrder.items.length} item(s)\n"
              "• **Total Amount:** Rs. ${foundOrder.total.toStringAsFixed(0)}\n"
              "• **Payment:** ${foundOrder.paymentMethod}\n\n"
              "Expected delivery: 2 to 4 business days from placement date.",
          isUser: false,
          timestamp: DateTime.now(),
          orderId: foundOrder.id,
          quickReplies: const [
            "What is the delivery time?",
            "Processing time details",
            "Contact support",
          ],
        );
      }

      if (localOrders.isNotEmpty) {
        final latest = localOrders.first;
        return ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          text: "📦 **Your Most Recent Order (#${latest.id}):**\n\n"
              "• **Status:** ${latest.status.name.toUpperCase()}\n"
              "• **Items:** ${latest.items.length} item(s)\n"
              "• **Total:** Rs. ${latest.total.toStringAsFixed(0)}\n"
              "• **Address:** ${latest.address}\n\n"
              "Expected delivery: 2 to 4 business days from placement date.",
          isUser: false,
          timestamp: DateTime.now(),
          orderId: latest.id,
          quickReplies: const [
            "Delivery times",
            "Order processing time",
            "Stock inquiry",
          ],
        );
      }

      return ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: "🔍 To track your order, please provide your **Order ID** (e.g. `ORD-1234` or `#1001`).\n\nYou can also view all your placed orders under **Account > My Orders**.",
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: const [
          "Delivery times",
          "Processing time details",
          "Stock availability",
        ],
      );
    }

    // Default shopping greeting
    return ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: "👋 Hi! I'm **ShopBot**, your 24/7 AI shopping assistant.\n\n"
          "I specialize in answering questions about:\n"
          "• 📦 **Order Tracking & Status**\n"
          "• 🚚 **Delivery Times & Shipping**\n"
          "• ⏱️ **Order Processing Timelines**\n"
          "• 🏷️ **Product Stock & Restocking**\n\n"
          "How can I assist you today?",
      isUser: false,
      timestamp: DateTime.now(),
      quickReplies: const [
        "Track my order",
        "What is the delivery time?",
        "Order processing time",
        "When will out-of-stock items restock?",
      ],
    );
  }

  /// Determines if a query is relevant to shopping, orders, stock, delivery, or any ShopHub app features.
  bool _isRelevantQuery(String text) {
    // Greeting or general help
    if (RegExp(r'^(hi|hello|hey|greetings|help|who are you|what can you do|assalam|aoa|guide|support)\b', caseSensitive: false).hasMatch(text)) {
      return true;
    }

    // App features & commerce keywords matching whole words
    final wordPattern = RegExp(
      r'\b(orders?|track(ing)?|status|deliver(y|ies|ing)?|ship(ping|ped|ment)?|dispatch(ed)?|'
      r'process(ing)?|stocks?|availab(le|ility)|restock(ing)?|products?|items?|prices?|costs?|'
      r'buy(ing)?|cart|checkout|pay(ment|ing)?|cash on delivery|cod|stripe|cards?|'
      r'cancel(lation)?|returns?|refunds?|exchanges?|warranty|shophub|store|packages?|parcels?|'
      r'couriers?|arriv(e|al|ing)|delay(ed)?|address(es)?|accounts?|'
      r'passwords?|forgot|reset|login|log in|signin|sign in|signup|sign up|register(ing)?|'
      r'logout|log out|signout|sign out|profiles?|users?|names?|phones?|mobiles?|settings|'
      r'wishlists?|favorites?|coupons?|promos?|discounts?|vouchers?|categories?|search(ing)?|'
      r'filters?|sort(ing)?|reviews?|ratings?|admin|dashboard|contacts?|helplines?|emails?|'
      r'apps?|features?|how to|working)\b',
      caseSensitive: false,
    );

    if (wordPattern.hasMatch(text)) return true;

    // Order ID patterns like ORD-1234, SH-1234 or #1234
    if (RegExp(r'ord-?\d+|sh-?\d+|#\d+', caseSensitive: false).hasMatch(text)) return true;

    return false;
  }

  /// Extracts an Order ID or code (e.g. ORD-1234, SH-1234, #1234) from text.
  static String? extractOrderId(String text) {
    // 1. Explicit ID format like ORD-9988, SH-1234, ORD1234
    final idMatch = RegExp(r'\b((?:ORD|SH)(?:[-_][0-9a-zA-Z]+|\d+))\b', caseSensitive: false).firstMatch(text);
    if (idMatch != null) {
      return idMatch.group(1);
    }
    // 2. Hash notation like #1234
    final hashMatch = RegExp(r'#([0-9a-zA-Z_-]+)').firstMatch(text);
    if (hashMatch != null) {
      return hashMatch.group(1);
    }
    // 3. Keyword followed by order code, e.g. "order 1234"
    final keywordMatch = RegExp(r'\border\s*(?:id|#|number)?\s*[:#]?\s*([0-9a-zA-Z_-]+)\b', caseSensitive: false).firstMatch(text);
    if (keywordMatch != null) {
      final code = keywordMatch.group(1)!;
      if (!['details', 'status', 'time', 'times', 'processing', 'tracking', 'history', 'my', 'the'].contains(code.toLowerCase())) {
        return code;
      }
    }
    return null;
  }
}

