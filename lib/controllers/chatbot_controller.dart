import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_message.dart';
import '../models/order.dart';
import '../services/chatbot_service.dart';
import 'auth_controller.dart';
import 'order_controller.dart';
import 'product_controller.dart';

/// Chatbot Controller
/// Manages chat state, messaging queue, quick prompts, and AI responses for ShopHub.
class ChatbotController extends GetxController {
  final ChatbotService _service;

  ChatbotController({ChatbotService? service})
      : _service = service ?? ChatbotService();

  static ChatbotController get to => Get.find<ChatbotController>();

  final RxList<ChatMessage> _messages = <ChatMessage>[].obs;
  final RxBool _isTyping = false.obs;
  final RxBool _isInitialized = false.obs;
  String? _currentUserId;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isTyping => _isTyping.value;
  bool get isInitialized => _isInitialized.value;
  String? get currentUserId => _currentUserId;

  final List<String> defaultQuickPrompts = const [
    "How to reset password?",
    "Track my order",
    "What is the delivery time?",
    "Payment options",
    "Return & refund policy",
    "When will out-of-stock items restock?",
    "How to place an order?",
  ];

  void init() {
    _resolveCurrentUserId();
    final history = _service.loadChatHistory(_currentUserId);
    if (history.isNotEmpty) {
      _messages.assignAll(history);
    } else {
      _addWelcomeMessage();
    }
    _isInitialized.value = true;
    update();
  }

  void _resolveCurrentUserId() {
    try {
      final supaUser = Supabase.instance.client.auth.currentUser;
      if (supaUser != null && supaUser.id.isNotEmpty) {
        _currentUserId = supaUser.id;
        return;
      }
    } catch (_) {}

    if (Get.isRegistered<AuthController>()) {
      _currentUserId = AuthController.to.currentUser?.id;
    }
  }

  /// Refreshes state and context when active user changes (login, logout, switch).
  void onUserChanged(String? newUserId) {
    _currentUserId = newUserId;
    final history = _service.loadChatHistory(newUserId);
    if (history.isNotEmpty) {
      _messages.assignAll(history);
    } else {
      _messages.clear();
      _addWelcomeMessage();
    }
    update();
  }

  void _addWelcomeMessage() {
    _messages.assignAll([
      ChatMessage(
        id: 'welcome-${DateTime.now().millisecondsSinceEpoch}',
        text: "👋 Hi! I'm **ShopBot**, your dedicated ShopHub AI Assistant.\n\n"
            "I'm here to answer any questions about the ShopHub app:\n"
            "• 🔑 **Account & Password** — How to reset password or update profile\n"
            "• 📦 **Order Tracking** — Live status and order history\n"
            "• 🚚 **Delivery & Processing** — Timelines, shipping rates & dispatch\n"
            "• 💳 **Payments & Checkout** — Cash on Delivery and Stripe card support\n"
            "• 🏷️ **Product Stock** — Real-time availability & restocking schedules\n"
            "• 🔄 **Returns & Refunds** — 7-day hassle-free return policy\n\n"
            "What can I help you with today?",
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: defaultQuickPrompts,
      )
    ]);
  }

  /// Sends a message typed by the user or chosen from quick replies.
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // 1. Add user message
    final userMsg = ChatMessage(
      id: 'usr-${DateTime.now().microsecondsSinceEpoch}',
      text: trimmed,
      isUser: true,
      timestamp: DateTime.now(),
    );
    _messages.add(userMsg);
    _isTyping.value = true;
    update();

    // 2. Fetch context from active controllers if registered
    String? userId;
    String? userName;
    String? userEmail;
    String? userPhone;
    List<ShopOrder> userOrders = const [];

    // Prioritize authenticated Supabase user UUID
    try {
      final supaUser = Supabase.instance.client.auth.currentUser;
      if (supaUser != null && supaUser.id.isNotEmpty) {
        userId = supaUser.id;
        userEmail = supaUser.email;
      }
    } catch (_) {}

    if (Get.isRegistered<AuthController>()) {
      final auth = AuthController.to;
      final currentUser = auth.currentUser;
      if (currentUser != null) {
        userId ??= currentUser.id;
        userName = currentUser.name;
        userEmail ??= currentUser.email;
        userPhone = currentUser.phone;

        if (Get.isRegistered<OrderController>()) {
          // Strictly only pass orders belonging to the logged in user!
          userOrders = OrderController.to.getOrdersForUser(currentUser);
        }
      }
    }

    userId ??= _currentUserId;
    _currentUserId = userId ?? _currentUserId;

    final localProducts = Get.isRegistered<ProductController>()
        ? ProductController.to.products
        : const [];

    // 3. Request reply from ChatbotService
    try {
      final reply = await _service.sendMessage(
        message: trimmed,
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        userPhone: userPhone,
        history: _messages.toList(),
        localOrders: userOrders,
        localProducts: localProducts.cast(),
      );

      _messages.add(reply);
      _service.saveChatHistory(_messages.toList(), _currentUserId);
    } catch (e) {
      _messages.add(
        ChatMessage(
          id: 'err-${DateTime.now().microsecondsSinceEpoch}',
          text: "I am having trouble connecting right now. However, I can assure you that standard ShopHub delivery takes 2 to 4 business days and orders are processed within 24 hours.",
          isUser: false,
          timestamp: DateTime.now(),
          quickReplies: defaultQuickPrompts,
        ),
      );
    } finally {
      _isTyping.value = false;
      update();
    }
  }

  /// Triggered when user taps a quick action button.
  void askQuickQuestion(String question) {
    sendMessage(question);
  }

  /// Direct order tracking helper.
  void trackOrder(String orderId) {
    sendMessage("Track order #$orderId");
  }

  /// Clears the chat history and resets to the welcome screen.
  Future<void> clearChat() async {
    await _service.clearChatHistory(_currentUserId);
    _messages.clear();
    _addWelcomeMessage();
    update();
  }
}
