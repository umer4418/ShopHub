import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../app/routes/app_routes.dart';
import '../controllers/auth_controller.dart';
import '../controllers/order_controller.dart';
import '../controllers/support_chat_controller.dart';
import '../models/order.dart';
import '../models/support_conversation.dart';
import '../models/support_message.dart';
import '../theme/colors.dart';
import '../utils/money.dart';

/// Admin Customer Support Management Screen
/// Displays all customer conversations, enables live replying, order inspection, and ticket closing.
class AdminSupportScreen extends StatefulWidget {
  const AdminSupportScreen({super.key, this.isEmbedded = false});

  final bool isEmbedded;

  @override
  State<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends State<AdminSupportScreen> {
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchFilter = '';
  String _statusFilter = 'all'; // 'all', 'open', 'closed'
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      final chatCtrl = Get.isRegistered<SupportChatController>()
          ? Get.find<SupportChatController>()
          : null;
      chatCtrl?.refreshAdminData();
    });
  }

  void _loadData() {
    final chatCtrl = Get.isRegistered<SupportChatController>()
        ? Get.find<SupportChatController>()
        : Get.put(SupportChatController());
    chatCtrl.loadAdminConversations();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _replyController.dispose();
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

  Future<void> _sendAdminReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    final authCtrl = Get.find<AuthController>();
    final chatCtrl = Get.isRegistered<SupportChatController>()
        ? Get.find<SupportChatController>()
        : Get.put(SupportChatController());

    _replyController.clear();
    final ok = await chatCtrl.sendMessage(text, sender: authCtrl.currentUser);
    if (ok) {
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send reply. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final chatCtrl = Get.isRegistered<SupportChatController>()
        ? Get.find<SupportChatController>()
        : Get.put(SupportChatController());
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final bodyContent = Obx(() {
      final conversations = chatCtrl.adminConversations.where((c) {
        final matchesStatus = _statusFilter == 'all' ||
            (_statusFilter == 'open' && c.isOpen) ||
            (_statusFilter == 'closed' && c.isClosed);
        if (!matchesStatus) return false;

        final q = _searchFilter.trim().toLowerCase();
        if (q.isEmpty) return true;
        final name = (c.customerName ?? '').toLowerCase();
        final email = (c.customerEmail ?? '').toLowerCase();
        final orderId = (c.orderId ?? '').toLowerCase();
        final lastMsg = (c.lastMessage ?? '').toLowerCase();
        return name.contains(q) ||
            email.contains(q) ||
            orderId.contains(q) ||
            lastMsg.contains(q);
      }).toList();

      final selectedConv = chatCtrl.activeConversation;

      if (isDesktop) {
        // Desktop Split Screen Layout
        return Row(
          children: [
            // Left list panel
            SizedBox(
              width: 360,
              child: _buildConversationListPanel(chatCtrl, conversations),
            ),
            const VerticalDivider(width: 1, color: Color(0xFFE2E8F0)),
            // Right chat detail panel
            Expanded(
              child: selectedConv == null
                  ? _buildNoConversationSelected()
                  : _buildChatDetailPanel(chatCtrl, selectedConv),
            ),
          ],
        );
      } else {
        // Mobile single view layout: if conversation active, show chat; otherwise list
        if (selectedConv != null) {
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              chatCtrl.openAdminConversation(
                selectedConv.copyWith(id: ''),
              ); // clear active
            },
            child: _buildChatDetailPanel(chatCtrl, selectedConv, isMobile: true),
          );
        }
        return _buildConversationListPanel(chatCtrl, conversations);
      }
    });

    if (widget.isEmbedded) {
      return Container(
        color: Colors.white,
        child: bodyContent,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Support Chats'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: bodyContent,
    );
  }

  Widget _buildConversationListPanel(
    SupportChatController chatCtrl,
    List<SupportConversation> list,
  ) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Filter & Search Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search customer, email, order...',
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchFilter = val),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _filterChip('All', 'all'),
                    const SizedBox(width: 6),
                    _filterChip('Open', 'open'),
                    const SizedBox(width: 6),
                    _filterChip('Closed', 'closed'),
                  ],
                ),
              ],
            ),
          ),

          // Conversation List
          Expanded(
            child: chatCtrl.isLoading && list.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? Center(
                        child: Text(
                          _searchFilter.isEmpty
                              ? 'No conversations found.'
                              : 'No matching conversations.',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => chatCtrl.loadAdminConversations(),
                        child: ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, _) => const Divider(
                            height: 1,
                            color: Color(0xFFF1F5F9),
                          ),
                          itemBuilder: (context, index) {
                            final conv = list[index];
                            final isSelected =
                                chatCtrl.activeConversation?.id == conv.id;
                            final name = conv.customerName ??
                                (conv.customerEmail != null
                                    ? conv.customerEmail!.split('@').first
                                    : 'Customer');
                            final initial =
                                name.isNotEmpty ? name[0].toUpperCase() : 'C';

                            return InkWell(
                              onTap: () {
                                chatCtrl.openAdminConversation(conv);
                              },
                              child: Container(
                                color: isSelected
                                    ? const Color(0xFFEFF6FF)
                                    : Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: conv.unreadCount > 0
                                          ? ShopColors.primary
                                          : const Color(0xFFCBD5E1),
                                      child: Text(
                                        initial,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  name,
                                                  style: TextStyle(
                                                    fontWeight: conv.unreadCount > 0
                                                        ? FontWeight.bold
                                                        : FontWeight.w600,
                                                    fontSize: 14,
                                                    color: const Color(0xFF0F172A),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Text(
                                                _formatTimestamp(conv.updatedAt),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: conv.unreadCount > 0
                                                      ? ShopColors.primary
                                                      : Colors.grey,
                                                  fontWeight: conv.unreadCount > 0
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          if (conv.orderId != null)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                bottom: 4,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'Order #${conv.orderId}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.blue.shade800,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          Text(
                                            conv.lastMessage ??
                                                'No messages yet',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: conv.unreadCount > 0
                                                  ? const Color(0xFF0F172A)
                                                  : Colors.grey.shade600,
                                              fontWeight: conv.unreadCount > 0
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (conv.unreadCount > 0)
                                      Container(
                                        margin: const EdgeInsets.only(
                                          left: 8,
                                          top: 2,
                                        ),
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: Colors.redAccent,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          '${conv.unreadCount}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return InkWell(
      onTap: () => setState(() => _statusFilter = value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? ShopColors.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildNoConversationSelected() {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'Select a Customer Conversation',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Click on any support ticket from the list to view history and respond.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatDetailPanel(
    SupportChatController chatCtrl,
    SupportConversation conv, {
    bool isMobile = false,
  }) {
    final orderCtrl = Get.isRegistered<OrderController>()
        ? Get.find<OrderController>()
        : null;
    final order = conv.orderId != null && orderCtrl != null
        ? orderCtrl.getOrderById(conv.orderId!)
        : null;

    final customerTitle = conv.customerName ??
        (conv.customerEmail != null
            ? conv.customerEmail!.split('@').first
            : 'Customer');

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // Detail Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                if (isMobile)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      chatCtrl.onUserChanged(chatCtrl.activeUserId);
                    },
                  ),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: ShopColors.primary.withValues(alpha: 0.15),
                  child: const Icon(
                    Icons.person,
                    color: ShopColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerTitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (conv.customerEmail != null)
                        Text(
                          conv.customerEmail!,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                if (conv.isOpen)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Close Ticket', style: TextStyle(fontSize: 12)),
                    onPressed: () => chatCtrl.closeActiveConversation(),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Ticket Closed',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),

          // Related Order Details Strip (if linked)
          if (conv.orderId != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.amber.shade50,
              child: Row(
                children: [
                  const Icon(
                    Icons.shopping_bag_outlined,
                    size: 18,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Linked to Order #${conv.orderId}'
                      '${order != null ? ' • Status: ${order.status.label} • Total: ${pkr.format(order.total)}' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                  if (order != null)
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRoutes.orderConfirmation,
                        arguments: order.id,
                      ),
                      child: const Text(
                        'View Order',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),

          // Message Stream
          Expanded(
            child: chatCtrl.isLoading && chatCtrl.messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : chatCtrl.messages.isEmpty
                    ? const Center(
                        child: Text(
                          'No messages yet in this ticket.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        itemCount: chatCtrl.messages.length,
                        itemBuilder: (context, index) {
                          final msg = chatCtrl.messages[index];
                          final isAdmin = msg.senderRole == 'admin';
                          return _buildAdminMessageBubble(msg, isAdmin);
                        },
                      ),
          ),

          // Reply Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: conv.isClosed
                          ? 'Ticket is closed. Reply to reopen...'
                          : 'Reply to customer...',
                      hintStyle: const TextStyle(fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _sendAdminReply(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: ShopColors.primary,
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
                  onPressed: chatCtrl.isSending ? null : _sendAdminReply,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminMessageBubble(SupportMessage msg, bool isAdmin) {
    final timeStr = DateFormat('hh:mm a').format(msg.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isAdmin ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isAdmin) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFFCBD5E1),
              child: const Icon(Icons.person, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isAdmin ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isAdmin ? 14 : 2),
                  bottomRight: Radius.circular(isAdmin ? 2 : 14),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
                border: isAdmin
                    ? null
                    : Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment:
                    isAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      isAdmin ? 'Admin (You)' : 'Customer',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isAdmin ? Colors.white60 : Colors.blue.shade700,
                      ),
                    ),
                  ),
                  Text(
                    msg.message,
                    style: TextStyle(
                      fontSize: 13,
                      color: isAdmin ? Colors.white : Colors.black87,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 10,
                      color: isAdmin ? Colors.white60 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isAdmin) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
