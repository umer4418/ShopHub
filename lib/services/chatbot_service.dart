import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
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

  bool _isKeyInvalid = false;
  SharedPreferences? _prefs;

  bool get hasSupabase {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  final Map<String, List<ChatMessage>> _memoryChatHistory = {};

  Future<void> init([SharedPreferences? prefs]) async {
    _prefs = prefs ?? await SharedPreferences.getInstance();
  }

  String _historyKey([String? userId]) {
    if (userId != null && userId.isNotEmpty) {
      return '${_kChatHistory}_$userId';
    }
    return '${_kChatHistory}_guest';
  }

  /// Loads persisted chat messages from local storage (scoped to user).
  List<ChatMessage> loadChatHistory([String? userId]) {
    final key = _historyKey(userId);
    final prefs = _prefs;
    if (prefs != null) {
      var raw = prefs.getString(key);
      if (raw == null && userId == null) {
        raw = prefs.getString(_kChatHistory);
      }
      if (raw != null) {
        try {
          final decoded = jsonDecode(raw) as List;
          final loaded = decoded
              .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
              .toList();
          _memoryChatHistory[key] = loaded;
          return loaded;
        } catch (_) {
          return _memoryChatHistory[key] ?? [];
        }
      }
    }
    return _memoryChatHistory[key] ?? [];
  }

  /// Saves chat messages to local storage (scoped to user).
  Future<void> saveChatHistory(List<ChatMessage> messages, [String? userId]) async {
    final key = _historyKey(userId);
    _memoryChatHistory[key] = List.of(messages);
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final prefs = _prefs;
      if (prefs == null) return;
      // Keep up to last 50 messages to save space
      final trimmed = messages.length > 50
          ? messages.sublist(messages.length - 50)
          : messages;
      final encoded = jsonEncode(trimmed.map((e) => e.toJson()).toList());
      await prefs.setString(key, encoded);
    } catch (_) {}
  }

  /// Clears chat history in local storage.
  Future<void> clearChatHistory([String? userId]) async {
    final key = _historyKey(userId);
    _memoryChatHistory.remove(key);
    if (userId == null) {
      _memoryChatHistory.remove(_kChatHistory);
    }
    try {
      final prefs = _prefs;
      if (prefs == null) return;
      await prefs.remove(key);
      await prefs.remove(_kChatHistory);
    } catch (_) {}
  }

  SupabaseClient? get _supabaseClient {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Fetches orders for a specific user ID from Supabase Postgres.
  Future<List<ShopOrder>> fetchUserOrdersFromSupabase(String userId) async {
    final client = _supabaseClient;
    if (client == null) return [];
    try {
      final res = await client
          .from('orders')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (res as List)
          .map((e) => ShopOrder.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching user orders from Supabase: $e');
      return [];
    }
  }

  /// Fetches an order by ID strictly belonging to [userId] from Supabase Postgres.
  Future<ShopOrder?> fetchOrderByIdForUserFromSupabase({
    required String orderId,
    required String userId,
  }) async {
    final client = _supabaseClient;
    if (client == null) return null;
    try {
      final cleanId = orderId.replaceAll('#', '').trim();
      final res = await client
          .from('orders')
          .select()
          .eq('id', cleanId)
          .eq('user_id', userId)
          .maybeSingle();

      if (res != null) {
        return ShopOrder.fromJson(res);
      }

      final partialRes = await client
          .from('orders')
          .select()
          .ilike('id', '%$cleanId%')
          .eq('user_id', userId)
          .limit(1);

      if (partialRes.isNotEmpty) {
        return ShopOrder.fromJson(partialRes.first);
      }
    } catch (e) {
      debugPrint('Error fetching order by ID for user from Supabase: $e');
    }
    return null;
  }

  String? _getAuthenticatedUserId(String? fallbackUserId) {
    if (fallbackUserId != null && fallbackUserId.isNotEmpty) {
      return fallbackUserId;
    }
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && user.id.isNotEmpty) {
        return user.id;
      }
    } catch (_) {}
    return null;
  }

  bool _isOrderTrackingQuery(String text, {String? orderId}) {
    if (orderId != null && orderId.isNotEmpty) return true;

    final lower = text.toLowerCase().trim();

    // General FAQ inquiries should not be intercepted as tracking
    if ((lower.contains('how to') || lower.contains('how do i') || lower.contains('how can i')) &&
        (lower.contains('order') || lower.contains('buy') || lower.contains('place'))) {
      return false;
    }
    if (lower.contains('processing time') ||
        lower.contains('dispatch time') ||
        lower.contains('how long') ||
        lower.contains('stock') ||
        lower.contains('available') ||
        lower.contains('restock')) {
      return false;
    }

    if (extractOrderId(text) != null) return true;

    final hasTrackKeyword = RegExp(r'\btrack(ing)?\b').hasMatch(lower);

    return hasTrackKeyword ||
        lower.contains('my order') ||
        lower.contains('where is my order') ||
        lower.contains('order status') ||
        lower.contains('check order') ||
        lower.contains('show my orders') ||
        lower.contains('view my orders') ||
        lower.contains('list my orders') ||
        lower == 'orders' ||
        lower == 'my orders';
  }

  /// Public order tracking handler adhering to Steps 1-4.
  Future<ChatMessage> handleOrderTracking({
    required String message,
    String? userId,
    String? userName,
    String? userEmail,
    String? orderId,
    List<ShopOrder> localOrders = const [],
  }) async {
    final currentAuthId = _getAuthenticatedUserId(userId);
    final effectiveEmail = userEmail?.trim();

    // Step 1: Identify Logged-in User
    final isLoggedIn = (currentAuthId != null && currentAuthId.isNotEmpty) ||
        (effectiveEmail != null && effectiveEmail.isNotEmpty);

    if (!isLoggedIn) {
      return ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: "🔒 **Account Login Required:**\n\n"
            "Please log into your ShopHub account so I can look up and track your personal orders.\n\n"
            "For your security and privacy, ShopBot only tracks orders placed with your own authenticated account.",
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: const [
          "How to reset password?",
          "How to create account",
          "What is the delivery time?",
          "Payment options",
        ],
      );
    }

    // Step 2: Fetch User Orders strictly for authenticated user
    List<ShopOrder> userOrders = [];
    if (currentAuthId != null && hasSupabase) {
      userOrders = await fetchUserOrdersFromSupabase(currentAuthId);
    }

    if (userOrders.isEmpty) {
      userOrders = localOrders.where((o) {
        if (currentAuthId != null && o.userId != null) {
          return o.userId == currentAuthId;
        }
        if (effectiveEmail != null &&
            effectiveEmail.isNotEmpty &&
            o.customerEmail != null &&
            o.customerEmail!.isNotEmpty) {
          return o.customerEmail!.toLowerCase().trim() == effectiveEmail.toLowerCase();
        }
        if (effectiveEmail != null && o.customerEmail == null && o.userId == null) {
          return true;
        }
        return false;
      }).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    // If user has no orders:
    if (userOrders.isEmpty) {
      final displayName = (userName != null && userName.isNotEmpty)
          ? userName
          : (effectiveEmail ?? 'Customer');
      return ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: "📦 **No Orders Found:**\n\n"
            "Hi $displayName! You have no orders yet under your account.\n\n"
            "Once you place an order on ShopHub, you can track its live status, processing, and delivery right here!",
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: const [
          "How to place an order?",
          "Payment options",
          "What is the delivery time?",
        ],
      );
    }

    final queryOrderId = orderId ?? extractOrderId(message);

    // Step 3: Present the Orders & Ask which one to track
    if (queryOrderId == null) {
      final buffer = StringBuffer();
      buffer.writeln("📦 **Your Orders:**\n");
      buffer.writeln("Here are the orders found under your account:\n");
      for (final o in userOrders) {
        final dateStr = DateFormat('MMM dd, yyyy').format(o.createdAt);
        final statusLabel = o.status.label;
        buffer.writeln("• **Order #${o.id}** — $statusLabel — $dateStr — Rs. ${o.total.toStringAsFixed(0)}");
      }
      buffer.writeln("\nWhich order would you like to track? Please enter the order number or tap an option below.");

      final quickReplies = userOrders.map((o) => "Order #${o.id}").take(5).toList();
      quickReplies.add("What is the delivery time?");

      return ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: buffer.toString(),
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: quickReplies,
      );
    }

    // Step 4: Track the Selected Order & Verify Ownership
    final cleanId = queryOrderId.replaceAll('#', '').trim();
    ShopOrder? matchedOrder;

    if (currentAuthId != null && hasSupabase) {
      matchedOrder = await fetchOrderByIdForUserFromSupabase(
        orderId: cleanId,
        userId: currentAuthId,
      );
    }

    if (matchedOrder == null) {
      final lowerClean = cleanId.toLowerCase();
      for (final o in userOrders) {
        final oId = o.id.toLowerCase();
        final oNum = oId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        final cleanNum = lowerClean.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        if (oId == lowerClean || oNum == cleanNum || oId.endsWith(lowerClean)) {
          matchedOrder = o;
          break;
        }
      }
    }

    // If order does NOT belong to the user
    if (matchedOrder == null) {
      return ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: "🔒 **Order Not Found In Your Account:**\n\n"
            "I couldn't find that order (#$cleanId) in your account. Please check the order number and try again.",
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: userOrders.isNotEmpty
            ? userOrders.map((o) => "Order #${o.id}").take(4).toList()
            : const [
                "Track my order",
                "What is the delivery time?",
                "Contact support",
              ],
      );
    }

    // If order DOES belong to the user, display detailed order tracking information
    String statusEmoji;
    switch (matchedOrder.status) {
      case OrderStatus.placed:
        statusEmoji = "📦 Placed (Order received & warehouse verification in progress)";
        break;
      case OrderStatus.processing:
        statusEmoji = "⚙️ Processing (Being packed in warehouse)";
        break;
      case OrderStatus.shipped:
        statusEmoji = "🚚 Shipped (Handed over to courier partner)";
        break;
      case OrderStatus.delivered:
        statusEmoji = "✅ Delivered (Successfully delivered to doorstep)";
        break;
      case OrderStatus.completed:
        statusEmoji = "🎉 Completed (Order verified and marked completed by customer)";
        break;
    }

    final orderDateStr = DateFormat('MMM dd, yyyy – hh:mm a').format(matchedOrder.createdAt);
    final estimatedDeliveryStr = DateFormat('MMM dd, yyyy').format(
      matchedOrder.createdAt.add(const Duration(days: 3)),
    );

    final itemsList = matchedOrder.items.isNotEmpty
        ? matchedOrder.items
            .map((i) => "• **${i.product.name}** (x${i.quantity}) — Rs. ${(i.product.price * i.quantity).toStringAsFixed(0)}")
            .join('\n')
        : "• ${matchedOrder.items.length} item(s)";

    final trackingText = "📦 **Order #${matchedOrder.id} Tracking Details:**\n\n"
        "• **Order ID:** #${matchedOrder.id}\n"
        "• **Order Date:** $orderDateStr\n"
        "• **Current Status:** $statusEmoji\n"
        "• **Total Amount:** Rs. ${matchedOrder.total.toStringAsFixed(0)}\n"
        "• **Payment Method:** ${matchedOrder.paymentMethod}\n"
        "• **Shipping Address:** ${matchedOrder.address}\n"
        "• **Estimated Delivery:** 2 to 4 business days (by $estimatedDeliveryStr)\n\n"
        "**Items in this Order:**\n$itemsList";

    final otherOrders = userOrders.where((o) => o.id != matchedOrder!.id).take(2);
    final trackingQuickReplies = <String>[];
    for (final o in otherOrders) {
      trackingQuickReplies.add("Order #${o.id}");
    }
    trackingQuickReplies.addAll(const [
      "What is the delivery time?",
      "Processing time details",
      "Contact support",
    ]);

    return ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: trackingText,
      isUser: false,
      timestamp: DateTime.now(),
      orderId: matchedOrder.id,
      quickReplies: trackingQuickReplies,
    );
  }

  /// Backwards-compatible alias for sendMessage
  Future<ChatMessage> reply(
    String message, {
    String? userId,
    String? userEmail,
    String? userName,
    String? userPhone,
    String? orderId,
    List<ShopOrder>? userOrders,
    List<ChatMessage> history = const [],
    List<Product> localProducts = const [],
  }) {
    return sendMessage(
      message: message,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      userPhone: userPhone,
      orderId: orderId,
      history: history,
      localOrders: userOrders ?? const [],
      localProducts: localProducts,
    );
  }

  /// Sends user message to the AI Chatbot.
  /// 1. If it's an order tracking query and Gemini is empty/disabled, uses deterministic order tracker.
  /// 2. Calls Gemini AI directly with live order & product context if API key is active.
  /// 3. If Gemini is unavailable, tries invoking Supabase Edge Function 'shopbot'.
  /// 4. If offline, falls back to the deterministic local rule engine.
  Future<ChatMessage> sendMessage({
    required String message,
    String? userId,
    String? userName,
    String? userEmail,
    String? userPhone,
    String? orderId,
    List<ChatMessage> history = const [],
    List<ShopOrder> localOrders = const [],
    List<Product> localProducts = const [],
  }) async {
    final cleanMessage = message.trim();

    // Fast-path: Order tracking inquiries when Gemini key is not configured or invalidated
    final isOrderQuery = _isOrderTrackingQuery(cleanMessage, orderId: orderId);
    if (isOrderQuery && (geminiApiKey.isEmpty || _isKeyInvalid)) {
      return await handleOrderTracking(
        message: cleanMessage,
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        orderId: orderId,
        localOrders: localOrders,
      );
    }

    // 1. Direct Gemini AI Call with Live Supabase Context Grounding (Primary AI Engine)
    if (geminiApiKey.isNotEmpty && !_isKeyInvalid) {
      final geminiMsg = await _callGemini(
        message: cleanMessage,
        history: history,
        localOrders: localOrders,
        localProducts: localProducts,
        userName: userName,
        userEmail: userEmail,
        orderId: orderId,
      );

      if (geminiMsg != null) {
        return geminiMsg;
      }
    }

    // Fallback for order tracking when Gemini fails or times out
    if (isOrderQuery) {
      return await handleOrderTracking(
        message: cleanMessage,
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        orderId: orderId,
        localOrders: localOrders,
      );
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
            'customerEmail': userEmail,
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
      userId: userId,
      orderId: orderId,
      localOrders: localOrders,
      localProducts: localProducts,
      userName: userName,
      userEmail: userEmail,
    );
  }

  /// Calls Google Gemini API with fallback across flash models.
  Future<ChatMessage?> _callGemini({
    required String message,
    List<ChatMessage> history = const [],
    List<ShopOrder> localOrders = const [],
    List<Product> localProducts = const [],
    String? userName,
    String? userEmail,
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
      userEmail: userEmail,
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

        if (response.statusCode == 401 || response.statusCode == 403) {
          debugPrint('Gemini API key is invalid, revoked, or leaked (HTTP ${response.statusCode}). Falling back immediately to fast local engine.');
          _isKeyInvalid = true;
          break;
        }

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
            final List<String> quickReplies;
            if (matchedId != null) {
              quickReplies = const ["What is the delivery time?", "Processing time details", "Contact support"];
            } else if (localOrders.isNotEmpty && (message.toLowerCase().contains('order') || message.toLowerCase().contains('track'))) {
              quickReplies = localOrders.map((o) => "Order #${o.id}").take(4).toList()..add("What is the delivery time?");
            } else {
              quickReplies = const [
                "Track my order",
                "How to reset password?",
                "What is the delivery time?",
                "Payment options",
              ];
            }

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
    String? userEmail,
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
- When a user asks "Track my order", "Where is my order", or asks about their orders WITHOUT providing a specific Order ID:
  1. Check [LINKED SUPABASE ORDERS DATA] below.
  2. If they have orders, list all their orders formatted like:
     • Order #<id> — <Status> — <Date> — Rs. <total>
  3. Ask: "Which order would you like to track? Please enter the order number or tap an option below."
  4. NEVER automatically choose or track an order for them without asking first.
  5. If the user has no orders, say: "You have no orders yet under your account."
- When the user specifies an Order ID to track:
  1. Check if that Order ID exists in [LINKED SUPABASE ORDERS DATA].
  2. If it belongs to them, provide full details: Order ID, Date, Status with emoji indicator (📦 Placed, ⚙️ Processing, 🚚 Shipped, ✅ Delivered), Payment Method, Total Amount, Shipping Address, and Estimated Delivery.
  3. If the order is NOT listed in [LINKED SUPABASE ORDERS DATA], say:
     "I couldn't find that order in your account. Please check the order number and try again."
     Never reveal, mention, or track an order belonging to another customer.
''';

    if (userEmail != null && userEmail.isNotEmpty) {
      prompt += '\n[LOGGED-IN CUSTOMER]\nName: ${userName ?? 'Customer'}, Email: $userEmail\n';
      prompt += 'CRITICAL PRIVACY RULE: You can ONLY track orders listed under [LINKED SUPABASE ORDERS DATA] which belong exclusively to this customer ($userEmail). Never invent, disclose, or track orders belonging to other customers.\n';
    } else {
      prompt += '\nNOTE: The user is NOT currently logged in. If they ask to track an order or check order status, instruct them to log into their ShopHub account first.\n';
    }

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

    // 11. Prominent People & Leaders
    if (lower.contains('elon musk')) return 'Elon Musk is the CEO of Tesla, SpaceX, and owner of X (formerly Twitter).';
    if (lower.contains('bill gates')) return 'Bill Gates is the co-founder of Microsoft and a prominent philanthropist.';
    if (lower.contains('steve jobs')) return 'Steve Jobs was the co-founder and former visionary CEO of Apple Inc.';
    if (lower.contains('imran khan')) return 'Imran Khan is a former Prime Minister of Pakistan and 1992 Cricket World Cup winning captain.';
    if (lower.contains('albert einstein') || lower.contains('einstein')) return 'Albert Einstein was a theoretical physicist famous for the theory of relativity (E=mc²).';
    if (lower.contains('newton') || lower.contains('isaac newton')) return 'Sir Isaac Newton was an English mathematician and physicist who formulated the laws of motion and gravity.';

    // 12. General Knowledge & Explanations
    if (lower.contains('photosynthesis')) return 'Photosynthesis is the process green plants use to convert sunlight, carbon dioxide, and water into oxygen and glucose.';
    if (lower.contains('artificial intelligence') || lower.contains('what is ai') || lower == 'ai') return 'Artificial intelligence refers to computer systems designed to perform cognitive tasks typically requiring human intelligence.';
    if (lower.contains('gravity')) return 'Gravity is the natural force that pulls objects toward the center of the Earth or other physical bodies.';
    if (lower.contains('grass') && lower.contains('green')) return 'Grass is green because chlorophyll absorbs red and blue light while reflecting green light.';
    if (lower.contains('how are you')) return 'I am doing great and ready to assist you!';
    if (lower.contains('who created you') || lower.contains('who made you')) return 'I was created by the ShopHub development team to assist you with e-commerce shopping.';
    if (lower.contains('poem')) return 'Roses are red, violets are blue, shopping on ShopHub is fast and true.';

    // 13. General Fallback
    if (lower.startsWith('why is') || lower.startsWith('why do') || lower.startsWith('why does') || lower.startsWith('why are')) {
      return 'Scientific and factual explanations for that phenomenon can be found in educational resources.';
    }
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
    String? userId,
    String? orderId,
    List<ShopOrder> localOrders = const [],
    List<Product> localProducts = const [],
    String? userName,
    String? userEmail,
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
        lower.contains('cash on delivery') ||
        lower.contains('stripe') ||
        RegExp(r'\b(pay|paying|cod|card|cards|credit|debit)\b').hasMatch(lower)) {
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
            "• **Live Human Support:** Connect with our admin team directly via chat in real-time.\n"
            "• **Email:** support@shophub.com\n"
            "• **Toll-Free Helpline:** 0800-SHOPHUB (0800-7467482)\n"
            "• **Operating Hours:** Monday to Saturday, 9:00 AM – 6:00 PM\n"
            "• **Live AI Support:** I am available 24/7 right here in the app!",
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: const [
          "Chat with Admin Support",
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
      // Exact match
      for (final p in localProducts) {
        if (lower.contains(p.name.toLowerCase())) {
          matchedProduct = p;
          break;
        }
      }
      // Multi-word partial match
      if (matchedProduct == null) {
        for (final p in localProducts) {
          final words = p.name.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length >= 4).toList();
          final matchCount = words.where((w) => lower.contains(w)).length;
          if (matchCount >= 2 || (words.length == 1 && matchCount == 1)) {
            matchedProduct = p;
            break;
          }
        }
      }
      // Single significant keyword match
      if (matchedProduct == null) {
        for (final p in localProducts) {
          final words = p.name.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length >= 4).toList();
          if (words.any((w) => lower.contains(w))) {
            matchedProduct = p;
            break;
          }
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
    if (_isOrderTrackingQuery(message, orderId: orderId)) {
      return _generateLocalOrderResponse(
        message: message,
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        orderId: orderId,
        localOrders: localOrders,
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

  ChatMessage _generateLocalOrderResponse({
    required String message,
    String? userId,
    String? userName,
    String? userEmail,
    String? orderId,
    List<ShopOrder> localOrders = const [],
  }) {
    final currentAuthId = _getAuthenticatedUserId(userId);
    final effectiveEmail = userEmail?.trim();

    // Step 1: Identify Logged-in User
    final isLoggedIn = (currentAuthId != null && currentAuthId.isNotEmpty) ||
        (effectiveEmail != null && effectiveEmail.isNotEmpty);

    if (!isLoggedIn) {
      return ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: "🔒 **Account Login Required:**\n\n"
            "Please log into your ShopHub account so I can look up and track your personal orders.\n\n"
            "For your security and privacy, ShopBot only tracks orders placed with your own authenticated account.",
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: const [
          "How to reset password?",
          "How to create account",
          "What is the delivery time?",
          "Payment options",
        ],
      );
    }

    // Step 2: Fetch and filter user orders strictly for authenticated user
    final userOrders = localOrders.where((o) {
      if (currentAuthId != null && o.userId != null) {
        return o.userId == currentAuthId;
      }
      if (effectiveEmail != null &&
          effectiveEmail.isNotEmpty &&
          o.customerEmail != null &&
          o.customerEmail!.isNotEmpty) {
        return o.customerEmail!.toLowerCase().trim() == effectiveEmail.toLowerCase();
      }
      if (effectiveEmail != null && o.customerEmail == null && o.userId == null) {
        return true;
      }
      return false;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // If user has no orders:
    if (userOrders.isEmpty) {
      final displayName = (userName != null && userName.isNotEmpty)
          ? userName
          : (effectiveEmail ?? 'Customer');
      return ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: "📦 **No Orders Found:**\n\n"
            "Hi $displayName! You have no orders yet under your account.\n\n"
            "Once you place an order on ShopHub, you can track its live status, processing, and delivery right here!",
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: const [
          "How to place an order?",
          "Payment options",
          "What is the delivery time?",
        ],
      );
    }

    final queryOrderId = orderId ?? extractOrderId(message);

    // Step 3: Present the Orders & Ask which one to track
    if (queryOrderId == null) {
      final buffer = StringBuffer();
      buffer.writeln("📦 **Your Orders:**\n");
      buffer.writeln("Here are the orders found under your account:\n");
      for (final o in userOrders) {
        final dateStr = DateFormat('MMM dd, yyyy').format(o.createdAt);
        final statusLabel = o.status.label;
        buffer.writeln("• **Order #${o.id}** — $statusLabel — $dateStr — Rs. ${o.total.toStringAsFixed(0)}");
      }
      buffer.writeln("\nWhich order would you like to track? Please enter the order number or tap an option below.");

      final quickReplies = userOrders.map((o) => "Order #${o.id}").take(5).toList();
      quickReplies.add("What is the delivery time?");

      return ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: buffer.toString(),
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: quickReplies,
      );
    }

    // Step 4: Track the Selected Order & Verify Ownership
    final cleanId = queryOrderId.replaceAll('#', '').trim();
    ShopOrder? matchedOrder;
    final lowerClean = cleanId.toLowerCase();

    for (final o in userOrders) {
      final oId = o.id.toLowerCase();
      final oNum = oId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      final cleanNum = lowerClean.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      if (oId == lowerClean || oNum == cleanNum || oId.endsWith(lowerClean)) {
        matchedOrder = o;
        break;
      }
    }

    // If order does NOT belong to the user
    if (matchedOrder == null) {
      return ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: "🔒 **Order Not Found In Your Account:**\n\n"
            "I couldn't find that order (#$cleanId) in your account. Please check the order number and try again.",
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: userOrders.isNotEmpty
            ? userOrders.map((o) => "Order #${o.id}").take(4).toList()
            : const [
                "Track my order",
                "What is the delivery time?",
                "Contact support",
              ],
      );
    }

    // If order DOES belong to the user, display detailed order tracking information
    String statusEmoji;
    switch (matchedOrder.status) {
      case OrderStatus.placed:
        statusEmoji = "📦 Placed (Order received & warehouse verification in progress)";
        break;
      case OrderStatus.processing:
        statusEmoji = "⚙️ Processing (Being packed in warehouse)";
        break;
      case OrderStatus.shipped:
        statusEmoji = "🚚 Shipped (Handed over to courier partner)";
        break;
      case OrderStatus.delivered:
        statusEmoji = "✅ Delivered (Successfully delivered to doorstep)";
        break;
      case OrderStatus.completed:
        statusEmoji = "🎉 Completed (Order verified and marked completed by customer)";
        break;
    }

    final orderDateStr = DateFormat('MMM dd, yyyy – hh:mm a').format(matchedOrder.createdAt);
    final estimatedDeliveryStr = DateFormat('MMM dd, yyyy').format(
      matchedOrder.createdAt.add(const Duration(days: 3)),
    );

    final itemsList = matchedOrder.items.isNotEmpty
        ? matchedOrder.items
            .map((i) => "• **${i.product.name}** (x${i.quantity}) — Rs. ${(i.product.price * i.quantity).toStringAsFixed(0)}")
            .join('\n')
        : "• ${matchedOrder.items.length} item(s)";

    final trackingText = "📦 **Order #${matchedOrder.id} Tracking Details:**\n\n"
        "• **Order ID:** #${matchedOrder.id}\n"
        "• **Order Date:** $orderDateStr\n"
        "• **Current Status:** $statusEmoji\n"
        "• **Total Amount:** Rs. ${matchedOrder.total.toStringAsFixed(0)}\n"
        "• **Payment Method:** ${matchedOrder.paymentMethod}\n"
        "• **Shipping Address:** ${matchedOrder.address}\n"
        "• **Estimated Delivery:** 2 to 4 business days (by $estimatedDeliveryStr)\n\n"
        "**Items in this Order:**\n$itemsList";

    final otherOrders = userOrders.where((o) => o.id != matchedOrder!.id).take(2);
    final trackingQuickReplies = <String>[];
    for (final o in otherOrders) {
      trackingQuickReplies.add("Order #${o.id}");
    }
    trackingQuickReplies.addAll(const [
      "What is the delivery time?",
      "Processing time details",
      "Contact support",
    ]);

    return ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: trackingText,
      isUser: false,
      timestamp: DateTime.now(),
      orderId: matchedOrder.id,
      quickReplies: trackingQuickReplies,
    );
  }

  /// Determines if a query is relevant to shopping, orders, stock, delivery, or any ShopHub app features.
  bool _isRelevantQuery(String text) {
    final lower = text.toLowerCase().trim();

    // Explicit off-topic indicators (programming, trivia, general science, math, recipes, jokes)
    if (RegExp(r'\b(python|java|c\+\+|javascript|html|css|algorithm|binary tree|capital of|president of|prime minister|mona lisa|speed of light|photosynthesis|gravity|who wrote|who painted|bake a|recipe for|tell me a joke)\b').hasMatch(lower)) {
      return false;
    }

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

  /// Extracts an Order ID or code (e.g. ORD-1234, SH-1234, #1234, #1001, 1001, UUID) from text.
  static String? extractOrderId(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    // 1. Explicit ID format like ORD-9988, SH-1234, ORD1234, SH8821, ORD-OTHER
    // Requires a hyphen/underscore OR digits after prefix so words like "order" won't match!
    final idMatch = RegExp(
      r'\b((?:ORD|SH)(?:[-_][0-9a-zA-Z]+|\d+))\b',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (idMatch != null) {
      return idMatch.group(1);
    }

    // 2. Hash notation like #1234 or #1001 or #ORD-1234
    final hashMatch = RegExp(r'#([0-9a-zA-Z_-]+)').firstMatch(trimmed);
    if (hashMatch != null) {
      return hashMatch.group(1);
    }

    // 3. Standard UUID format (36 chars with hyphens)
    final uuidMatch = RegExp(
      r'\b([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\b',
    ).firstMatch(trimmed);
    if (uuidMatch != null) {
      return uuidMatch.group(1);
    }

    // 4. Keyword followed by order code, e.g. "order 1234", "track 1001", "track order 1001"
    const stopWords = {
      'details', 'status', 'time', 'times', 'processing', 'tracking',
      'history', 'my', 'the', 'an', 'a', 'this', 'that', 'please',
      'now', 'update', 'updates', 'info', 'information', 'here',
      'all', 'orders', 'order', 'me', 'package', 'parcel',
      'on', 'in', 'at', 'to', 'for', 'from', 'with', 'by', 'of',
      'about', 'is', 'are', 'was', 'were', 'it', 'its', 'there',
      'can', 'could', 'would', 'should', 'how', 'what', 'where',
      'when', 'why', 'who', 'which', 'do', 'does', 'did', 'done',
      'app', 'take', 'takes', 'item', 'items', 'product', 'products',
    };

    final keywordMatches = RegExp(
      r'\b(?:track(?:ing)?\s+order|order|track(?:ing)?)\b\s*(?:id|#|number)?\s*[:#]?\s*([0-9a-zA-Z_-]+)\b',
      caseSensitive: false,
    ).allMatches(trimmed);
    for (final m in keywordMatches) {
      final code = m.group(1)!;
      if (!stopWords.contains(code.toLowerCase())) {
        return code;
      }
    }

    // 5. Standalone numeric code (e.g. "1001", "8821")
    if (RegExp(r'^\d{3,10}$').hasMatch(trimmed)) {
      return trimmed;
    }

    return null;
  }
}

