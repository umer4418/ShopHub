import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../app/routes/app_routes.dart';
import '../controllers/chatbot_controller.dart';
import '../models/chat_message.dart';
import '../theme/colors.dart';

/// Chatbot Screen
/// Dedicated interactive chat view for ShopBot AI Assistant.
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();

  late final ChatbotController _chatCtrl;

  @override
  void initState() {
    super.initState();
    // Ensure controller is registered
    if (!Get.isRegistered<ChatbotController>()) {
      Get.put(ChatbotController()..init());
    }
    _chatCtrl = Get.find<ChatbotController>();

    // Scroll to bottom after build
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleSend([String? text]) {
    final toSend = text ?? _textCtrl.text;
    if (toSend.trim().isEmpty) return;

    _chatCtrl.sendMessage(toSend);
    _textCtrl.clear();
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _confirmClearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Chat History?'),
        content: const Text(
          'This will remove all current messages with ShopBot and start a fresh conversation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ShopColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _chatCtrl.clearChat();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: ShopColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: ShopColors.primarySoft,
                  child: const Icon(
                    Icons.smart_toy_rounded,
                    color: ShopColors.primary,
                    size: 24,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ShopBot AI',
                      style: TextStyle(
                        color: ShopColors.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.auto_awesome,
                      color: Colors.amber,
                      size: 14,
                    ),
                  ],
                ),
                Text(
                  'ShopHub App & Orders AI Assistant',
                  style: TextStyle(
                    color: ShopColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Clear conversation',
            icon: const Icon(Icons.delete_sweep_outlined, color: ShopColors.muted),
            onPressed: _confirmClearChat,
          ),
        ],
      ),
      body: Column(
        children: [
          // Guardrail Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: ShopColors.primarySoft.withValues(alpha: 0.5),
            child: Row(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 16,
                  color: ShopColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ShopBot answers questions about the ShopHub app: orders, delivery, account, password reset & stock.',
                    style: TextStyle(
                      fontSize: 11,
                      color: ShopColors.primaryDark.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Messages List
          Expanded(
            child: GetBuilder<ChatbotController>(
              builder: (ctrl) {
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  itemCount: ctrl.messages.length + (ctrl.isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == ctrl.messages.length && ctrl.isTyping) {
                      return const _TypingIndicatorBubble();
                    }

                    final message = ctrl.messages[index];
                    final isLast = index == ctrl.messages.length - 1;

                    return _ChatMessageBubble(
                      message: message,
                      showQuickReplies: isLast && !ctrl.isTyping,
                      onQuickReplyTap: _handleSend,
                    );
                  },
                );
              },
            ),
          ),

          // Quick Action Prompt Bar
          _QuickPromptsStrip(onSelectPrompt: _handleSend),

          // Input Bar
          _ChatInputBar(
            controller: _textCtrl,
            focusNode: _focusNode,
            onSend: _handleSend,
          ),
        ],
      ),
    );
  }
}

/// Message Bubble Widget
class _ChatMessageBubble extends StatelessWidget {
  const _ChatMessageBubble({
    required this.message,
    required this.showQuickReplies,
    required this.onQuickReplyTap,
  });

  final ChatMessage message;
  final bool showQuickReplies;
  final ValueChanged<String> onQuickReplyTap;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final timeStr = DateFormat('hh:mm a').format(message.timestamp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                CircleAvatar(
                  radius: 14,
                  backgroundColor: ShopColors.primarySoft,
                  child: const Icon(
                    Icons.smart_toy_rounded,
                    color: ShopColors.primary,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: isUser ? ShopColors.primary : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: isUser
                        ? null
                        : Border.all(color: ShopColors.border.withValues(alpha: 0.7)),
                  ),
                  child: Column(
                    crossAxisAlignment: isUser
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      _FormattedMessageText(
                        text: message.text,
                        isUser: isUser,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 9,
                          color: isUser ? Colors.white70 : ShopColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: ShopColors.navy.withValues(alpha: 0.1),
                  child: const Icon(
                    Icons.person,
                    color: ShopColors.navy,
                    size: 16,
                  ),
                ),
              ],
            ],
          ),

          // Order Action button if orderId is linked
          if (!isUser && message.orderId != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 6),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ShopColors.navy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: const Icon(Icons.receipt_long, size: 14),
                label: Text('Track Order #${message.orderId}'),
                onPressed: () {
                  // Direct navigation to orders
                  Navigator.pushNamed(context, AppRoutes.adminOrders);
                },
              ),
            ),
          ],

          // Quick Replies
          if (showQuickReplies && message.quickReplies.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: message.quickReplies.map((qr) {
                  return ActionChip(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: ShopColors.primary, width: 0.8),
                    label: Text(
                      qr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: ShopColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () => onQuickReplyTap(qr),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Helper that neatly formats markdown-like bold (**text**) and bullet lists
class _FormattedMessageText extends StatelessWidget {
  const _FormattedMessageText({
    required this.text,
    required this.isUser,
  });

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontSize: 13.5,
      height: 1.45,
      color: isUser ? Colors.white : ShopColors.text,
    );

    // Simple markdown inline parser for bold **text**
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: baseStyle,
        ));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: baseStyle.copyWith(
          fontWeight: FontWeight.w800,
          color: isUser ? Colors.white : const Color(0xFF1E293B),
        ),
      ));
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: baseStyle,
      ));
    }

    return Text.rich(TextSpan(children: spans));
  }
}

/// Typing animation bubble
class _TypingIndicatorBubble extends StatefulWidget {
  const _TypingIndicatorBubble();

  @override
  State<_TypingIndicatorBubble> createState() => _TypingIndicatorBubbleState();
}

class _TypingIndicatorBubbleState extends State<_TypingIndicatorBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: ShopColors.primarySoft,
            child: const Icon(
              Icons.smart_toy_rounded,
              color: ShopColors.primary,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ShopColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) {
                    return Row(
                      children: List.generate(3, (i) {
                        final val = ((_ctrl.value * 3) - i).clamp(0.0, 1.0);
                        final opacity = (val < 0.5 ? val * 2 : (1 - val) * 2).clamp(0.3, 1.0);
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: ShopColors.primary.withValues(alpha: opacity),
                            shape: BoxShape.circle,
                          ),
                        );
                      }),
                    );
                  },
                ),
                const SizedBox(width: 8),
                const Text(
                  'ShopBot is typing...',
                  style: TextStyle(
                    fontSize: 11,
                    color: ShopColors.muted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick suggested queries strip
class _QuickPromptsStrip extends StatelessWidget {
  const _QuickPromptsStrip({required this.onSelectPrompt});

  final ValueChanged<String> onSelectPrompt;

  static const List<String> prompts = [
    "🔑 Reset password",
    "📦 Track my order",
    "🚚 Delivery times",
    "💳 Payment options",
    "🔄 Return & refund",
    "🛒 How to order",
    "🏷️ Stock availability",
    "📞 Customer support",
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: prompts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final p = prompts[i];
          return ActionChip(
            visualDensity: VisualDensity.compact,
            backgroundColor: Colors.white,
            side: const BorderSide(color: ShopColors.border),
            label: Text(
              p,
              style: const TextStyle(
                fontSize: 11,
                color: ShopColors.text,
                fontWeight: FontWeight.w500,
              ),
            ),
            onPressed: () => onSelectPrompt(p.replaceAll(RegExp(r'^[^\w]+'), '').trim()),
          );
        },
      ),
    );
  }
}

/// Chat Input Bar
class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: ShopColors.border),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  style: const TextStyle(fontSize: 13.5, color: ShopColors.text),
                  decoration: const InputDecoration(
                    hintText: 'Ask about orders, delivery time, stock...',
                    hintStyle: TextStyle(fontSize: 12.5, color: ShopColors.muted),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: ShopColors.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onSend,
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
