import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/routes/app_routes.dart';
import '../controllers/auth_controller.dart';
import '../controllers/order_controller.dart';
import '../controllers/support_chat_controller.dart';
import '../models/order.dart';
import '../models/support_message.dart';
import '../theme/colors.dart';

/// Customer Support Chat Screen
/// Real-time mobile-friendly chat screen between Customer and ShopHub Admin Support,
/// with automatic order linking and Supabase persistence.
class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key, this.orderId});

  final String? orderId;

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _effectiveOrderId;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initChat();
    });
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      final chatCtrl = Get.isRegistered<SupportChatController>()
          ? Get.find<SupportChatController>()
          : null;
      chatCtrl?.refreshActiveMessages();
    });
  }

  void _initChat() {
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (widget.orderId != null && widget.orderId!.isNotEmpty) {
      _effectiveOrderId = widget.orderId;
    } else if (routeArgs is String && routeArgs.isNotEmpty) {
      _effectiveOrderId = routeArgs;
    } else if (routeArgs is Map && routeArgs['orderId'] != null) {
      _effectiveOrderId = routeArgs['orderId'] as String?;
    }

    if (!Get.isRegistered<AuthController>() ||
        !Get.isRegistered<SupportChatController>()) {
      return;
    }

    final authCtrl = Get.find<AuthController>();
    final user = authCtrl.currentUser;
    if (user == null) return;

    String customerId =
        (user.id != null && user.id!.trim().isNotEmpty) ? user.id!.trim() : '';
    if (customerId.isEmpty) {
      try {
        customerId = Supabase.instance.client.auth.currentUser?.id ?? '';
      } catch (_) {}
    }
    if (customerId.isEmpty) {
      customerId = user.email.trim();
    }

    final chatCtrl = Get.isRegistered<SupportChatController>()
        ? Get.find<SupportChatController>()
        : Get.put(SupportChatController());
    chatCtrl.initCustomerChat(
      customerId: customerId,
      customerName: user.name,
      customerEmail: user.email,
      orderId: _effectiveOrderId,
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final authCtrl = Get.find<AuthController>();
    final chatCtrl = Get.isRegistered<SupportChatController>()
        ? Get.find<SupportChatController>()
        : Get.put(SupportChatController());

    _textController.clear();
    final ok = await chatCtrl.sendMessage(text, sender: authCtrl.currentUser);
    if (ok) {
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send message. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Color _orderStatusColor(OrderStatus? status) {
    if (status == null) return Colors.blue;
    return switch (status) {
      OrderStatus.placed => Colors.blue,
      OrderStatus.processing => Colors.orange,
      OrderStatus.shipped => Colors.purple,
      OrderStatus.delivered => const Color(0xFF10B981),
      OrderStatus.completed => const Color(0xFF059669),
    };
  }

  @override
  Widget build(BuildContext context) {
    final authCtrl = Get.find<AuthController>();
    final chatCtrl = Get.isRegistered<SupportChatController>()
        ? Get.find<SupportChatController>()
        : Get.put(SupportChatController());
    final orderCtrl = Get.isRegistered<OrderController>()
        ? Get.find<OrderController>()
        : null;

    return Obx(() {
      final user = authCtrl.currentUser;

      if (user == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Customer Support')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, size: 54, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Login Required',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please log in to contact customer support and track conversations.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ShopColors.muted),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.login),
                    child: const Text('Login to Continue'),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      final activeConv = chatCtrl.activeConversation;
      final linkedOrderId = _effectiveOrderId ?? activeConv?.orderId;
      final linkedOrder = linkedOrderId != null && orderCtrl != null
          ? orderCtrl.getOrderById(linkedOrderId)
          : null;

      return Scaffold(
        appBar: AppBar(
          elevation: 1,
          titleSpacing: 0,
          title: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white24,
                child: const Icon(
                  Icons.support_agent,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ShopHub Support',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'Online  •  Direct Admin Chat',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            if (activeConv?.isClosed ?? false)
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Closed',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            // Order Context Banner (if discussing an order)
            if (linkedOrderId != null && linkedOrderId.isNotEmpty)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: ShopColors.primary.withValues(alpha: 0.08),
                  border: Border(
                    bottom: BorderSide(
                      color: ShopColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 20,
                      color: ShopColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Regarding Order #$linkedOrderId',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: ShopColors.text,
                            ),
                          ),
                          if (linkedOrder != null)
                            Text(
                              'Status: ${linkedOrder.status.label}',
                              style: TextStyle(
                                fontSize: 12,
                                color: _orderStatusColor(linkedOrder.status),
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          else if (activeConv?.orderStatus != null)
                            Text(
                              'Status: ${activeConv!.orderStatus!}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: ShopColors.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRoutes.orderConfirmation,
                        arguments: linkedOrderId,
                      ),
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('View Order', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),

            // Message Area
            Expanded(
              child: chatCtrl.isLoading && chatCtrl.messages.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : chatCtrl.messages.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          itemCount: chatCtrl.messages.length,
                          itemBuilder: (context, index) {
                            final msg = chatCtrl.messages[index];
                            final isMe = msg.senderRole == 'customer';
                            return _buildMessageBubble(msg, isMe);
                          },
                        ),
            ),

            // Chat Input Bar
            _buildInputBar(chatCtrl),
          ],
        ),
      );
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ShopColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 48,
                color: ShopColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'How can we help you?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: ShopColors.text,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Send a message to our support team. We can assist you with orders, deliveries, payments, returns, and refunds.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: ShopColors.muted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _quickPromptChip('📦 Order status inquiry'),
                _quickPromptChip('🚚 Delivery issue'),
                _quickPromptChip('💳 Payment or Refund'),
                _quickPromptChip('🔄 Return product'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickPromptChip(String prompt) {
    return ActionChip(
      label: Text(
        prompt,
        style: const TextStyle(fontSize: 12, color: ShopColors.text),
      ),
      backgroundColor: Colors.grey.shade100,
      side: BorderSide(color: Colors.grey.shade300),
      onPressed: () {
        _textController.text = prompt;
      },
    );
  }

  Widget _buildMessageBubble(SupportMessage msg, bool isMe) {
    final timeStr = DateFormat('hh:mm a').format(msg.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: ShopColors.primary.withValues(alpha: 0.15),
              child: const Icon(
                Icons.support_agent,
                size: 16,
                color: ShopColors.primary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? ShopColors.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: isMe
                    ? null
                    : Border.all(color: Colors.grey.shade200, width: 1),
              ),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'ShopHub Support (Admin)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  Text(
                    msg.message,
                    style: TextStyle(
                      fontSize: 14,
                      color: isMe ? Colors.white : ShopColors.text,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe ? Colors.white70 : Colors.grey.shade400,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          msg.isRead ? Icons.done_all : Icons.done,
                          size: 13,
                          color: msg.isRead ? Colors.cyanAccent : Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildInputBar(SupportChatController chatCtrl) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _textController,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                maxLines: 4,
                minLines: 1,
                decoration: const InputDecoration(
                  hintText: 'Type your message...',
                  hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                onSubmitted: (_) => _handleSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: chatCtrl.isSending ? null : _handleSend,
            style: IconButton.styleFrom(
              backgroundColor: ShopColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(12),
            ),
            icon: chatCtrl.isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}
