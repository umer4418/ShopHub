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
import '../models/support_conversation.dart';
import '../models/support_message.dart';
import '../theme/colors.dart';
import '../utils/responsive.dart';

/// Customer Support Chat Screen
/// Features persistent support ticketing with Open and Closed ticket separation,
/// direct order linking, real-time sync with Supabase single source of truth,
/// and explicit delete confirmation.
class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key, this.orderId});

  final String? orderId;

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;

  String? _effectiveOrderId;
  bool _showingChatDetail = false;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initScreen();
    });

    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      final chatCtrl = Get.isRegistered<SupportChatController>()
          ? Get.find<SupportChatController>()
          : null;
      if (chatCtrl == null) return;

      if (_showingChatDetail && chatCtrl.activeConversation != null) {
        chatCtrl.refreshActiveMessages();
      } else if (chatCtrl.activeUserId.isNotEmpty) {
        chatCtrl.refreshCustomerData(chatCtrl.activeUserId);
      }
    });
  }

  void _initScreen() {
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

    if (_effectiveOrderId != null && _effectiveOrderId!.isNotEmpty) {
      // Direct deep link from an order: open chat detail immediately
      _showingChatDetail = true;
      chatCtrl.initCustomerChat(
        customerId: customerId,
        customerName: user.name,
        customerEmail: user.email,
        orderId: _effectiveOrderId,
      );
    } else {
      // General support navigation: load all tickets
      _showingChatDetail = false;
      chatCtrl.loadCustomerConversations(customerId);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
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

    // If active ticket is closed, automatically reopen so communication can resume
    if (chatCtrl.activeConversation?.isClosed ?? false) {
      await chatCtrl.reopenActiveConversation();
    }

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

  Future<void> _confirmDeleteConversation(
    SupportConversation conv,
    SupportChatController chatCtrl,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: const Text(
          'Are you sure you want to delete this conversation? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await chatCtrl.deleteConversation(conv.id);
      if (!mounted) return;
      setState(() {
        _showingChatDetail = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conversation deleted permanently.'),
          backgroundColor: Colors.black87,
        ),
      );
    }
  }

  void _showNewTicketModal(
    BuildContext context,
    SupportChatController chatCtrl,
    AuthController authCtrl,
  ) {
    final user = authCtrl.currentUser;
    if (user == null) return;

    final subjectCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    final orderCtrl = Get.isRegistered<OrderController>()
        ? Get.find<OrderController>()
        : null;

    String? selectedOrderId;
    final userOrders = orderCtrl?.userOrders ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final isModalSmall = Responsive.isSmallMobile(modalCtx);
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: Responsive.maxMobileContentWidth),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: isModalSmall ? 14 : 20,
                    right: isModalSmall ? 14 : 20,
                    top: 20,
                    bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
                  ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Start New Ticket',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Subject / Topic',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: subjectCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Order inquiry, Refund, Delivery issue',
                        hintStyle: const TextStyle(fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (userOrders.isNotEmpty) ...[
                      const Text(
                        'Related Order (Optional)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: selectedOrderId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        hint: const Text('None (General inquiry)'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('None (General inquiry)'),
                          ),
                          ...userOrders.map((o) => DropdownMenuItem<String>(
                                value: o.id,
                                child: Text('Order #${o.id} (${o.status.label})'),
                              )),
                        ],
                        onChanged: (val) {
                          setModalState(() => selectedOrderId = val);
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    const Text(
                      'Your Message',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: messageCtrl,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Describe your issue or question in detail...',
                        hintStyle: const TextStyle(fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ShopColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final msg = messageCtrl.text.trim();
                          final sub = subjectCtrl.text.trim();
                          if (msg.isEmpty) {
                            ScaffoldMessenger.of(modalCtx).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a message.'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }

                          Navigator.pop(modalCtx);

                          String customerId =
                              (user.id != null && user.id!.trim().isNotEmpty)
                                  ? user.id!.trim()
                                  : '';
                          if (customerId.isEmpty) {
                            customerId = Supabase
                                    .instance.client.auth.currentUser?.id ??
                                user.email.trim();
                          }

                          final conv = await chatCtrl.createCustomerTicket(
                            customerId: customerId,
                            customerName: user.name,
                            customerEmail: user.email,
                            orderId: selectedOrderId,
                            subject: sub.isNotEmpty ? sub : null,
                            initialMessage: msg,
                          );

                          if (conv != null && mounted) {
                            setState(() {
                              _showingChatDetail = true;
                              _effectiveOrderId = conv.orderId;
                            });
                          }
                        },
                        child: const Text(
                          'Create Support Ticket',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  },
);
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

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d, hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final authCtrl = Get.find<AuthController>();
    final chatCtrl = Get.isRegistered<SupportChatController>()
        ? Get.find<SupportChatController>()
        : Get.put(SupportChatController());

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

      // If viewing active chat thread
      if (_showingChatDetail && chatCtrl.activeConversation != null) {
        return PopScope(
          canPop: widget.orderId != null,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            setState(() {
              _showingChatDetail = false;
              _effectiveOrderId = null;
            });
            chatCtrl.clearActiveConversation();
          },
          child: _buildChatThreadView(context, chatCtrl, authCtrl),
        );
      }

      // Otherwise show Support Tickets Hub (Open & Closed tabs)
      return _buildTicketsHubView(context, chatCtrl, authCtrl);
    });
  }

  // ===========================================================================
  // Support Tickets Hub (Open Tickets & Closed Tickets)
  // ===========================================================================

  Widget _buildTicketsHubView(
    BuildContext context,
    SupportChatController chatCtrl,
    AuthController authCtrl,
  ) {
    final openTickets = chatCtrl.customerOpenTickets;
    final closedTickets = chatCtrl.customerClosedTickets;

    final isSmall = Responsive.isSmallMobile(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Support'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: [
            Tab(text: isSmall ? 'Open (${openTickets.length})' : 'Open Tickets (${openTickets.length})'),
            Tab(text: isSmall ? 'Closed (${closedTickets.length})' : 'Closed Tickets (${closedTickets.length})'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              chatCtrl.loadCustomerConversations(chatCtrl.activeUserId);
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTicketsListTab(
            chatCtrl,
            openTickets,
            isOpenTab: true,
            authCtrl: authCtrl,
          ),
          _buildTicketsListTab(
            chatCtrl,
            closedTickets,
            isOpenTab: false,
            authCtrl: authCtrl,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ShopColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('New Ticket'),
        onPressed: () => _showNewTicketModal(context, chatCtrl, authCtrl),
      ),
    );
  }

  Widget _buildTicketsListTab(
    SupportChatController chatCtrl,
    List<SupportConversation> tickets, {
    required bool isOpenTab,
    required AuthController authCtrl,
  }) {
    if (chatCtrl.isLoading && tickets.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (tickets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isOpenTab
                    ? Icons.mark_chat_read_outlined
                    : Icons.history_toggle_off_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                isOpenTab ? 'No Open Tickets' : 'No Closed Tickets',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ShopColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isOpenTab
                    ? 'You do not have any active support conversations. Need help with an order or inquiry? Start a new ticket.'
                    : 'Closed and resolved conversations will be saved here permanently so you can inspect past solutions at any time.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: ShopColors.muted),
              ),
              if (isOpenTab) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ShopColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () =>
                      _showNewTicketModal(context, chatCtrl, authCtrl),
                  icon: const Icon(Icons.add),
                  label: const Text('Start New Ticket'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await chatCtrl.loadCustomerConversations(chatCtrl.activeUserId);
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: tickets.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final conv = tickets[index];
          return _buildTicketCard(conv, chatCtrl);
        },
      ),
    );
  }

  Widget _buildTicketCard(
    SupportConversation conv,
    SupportChatController chatCtrl,
  ) {
    final title = conv.subject?.isNotEmpty == true
        ? conv.subject!
        : (conv.orderId != null
            ? 'Order #${conv.orderId}'
            : 'Support Ticket #${conv.id.length > 8 ? conv.id.substring(0, 8) : conv.id}');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          setState(() {
            _showingChatDetail = true;
            _effectiveOrderId = conv.orderId;
          });
          chatCtrl.openConversation(conv, role: 'customer');
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: conv.isOpen
                                ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            conv.isOpen ? 'OPEN' : 'CLOSED',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: conv.isOpen
                                  ? const Color(0xFF047857)
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                        if (conv.orderId != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Order #${conv.orderId}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Colors.grey,
                    ),
                    tooltip: 'Delete Conversation',
                    onPressed: () {
                      _confirmDeleteConversation(conv, chatCtrl);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ShopColors.text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                conv.lastMessage ?? 'No messages yet.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      conv.isClosed && conv.closedAt != null
                          ? 'Closed ${_formatTimestamp(conv.closedAt!)}'
                          : 'Updated ${_formatTimestamp(conv.updatedAt)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      if (conv.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          child: Text(
                            '${conv.unreadCount} new',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Chat Thread Detail View
  // ===========================================================================

  Widget _buildChatThreadView(
    BuildContext context,
    SupportChatController chatCtrl,
    AuthController authCtrl,
  ) {
    final activeConv = chatCtrl.activeConversation;
    final orderCtrl = Get.isRegistered<OrderController>()
        ? Get.find<OrderController>()
        : null;

    final linkedOrderId = _effectiveOrderId ?? activeConv?.orderId;
    final linkedOrder = linkedOrderId != null && orderCtrl != null
        ? orderCtrl.getOrderById(linkedOrderId)
        : null;

    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.orderId != null) {
              Navigator.pop(context);
            } else {
              setState(() {
                _showingChatDetail = false;
                _effectiveOrderId = null;
              });
              chatCtrl.clearActiveConversation();
            }
          },
        ),
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
            Expanded(
              child: Column(
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
                        decoration: BoxDecoration(
                          color: (activeConv?.isOpen ?? true)
                              ? const Color(0xFF10B981)
                              : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        (activeConv?.isOpen ?? true)
                            ? 'Online • Admin Chat'
                            : 'Ticket Closed',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (activeConv != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (val) async {
                if (val == 'close') {
                  await chatCtrl.closeActiveConversation();
                } else if (val == 'reopen') {
                  await chatCtrl.reopenActiveConversation();
                } else if (val == 'delete') {
                  _confirmDeleteConversation(activeConv, chatCtrl);
                }
              },
              itemBuilder: (ctx) => [
                if (activeConv.isOpen)
                  const PopupMenuItem(
                    value: 'close',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 18, color: Colors.black87),
                        SizedBox(width: 8),
                        Text('Close Ticket'),
                      ],
                    ),
                  )
                else
                  const PopupMenuItem(
                    value: 'reopen',
                    child: Row(
                      children: [
                        Icon(Icons.replay, size: 18, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Reopen Ticket'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline,
                          size: 18, color: Colors.redAccent),
                      SizedBox(width: 8),
                      Text('Delete Conversation',
                          style: TextStyle(color: Colors.redAccent)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Order Context Banner (if linked)
          if (linkedOrderId != null && linkedOrderId.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                    label:
                        const Text('View Order', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),

          // Closed ticket banner
          if (activeConv?.isClosed ?? false)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: Colors.grey.shade200,
              child: Row(
                children: [
                  const Icon(Icons.lock_clock, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This ticket is closed. Full conversation is preserved. You can reopen it anytime.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                    ),
                  ),
                  TextButton(
                    onPressed: () => chatCtrl.reopenActiveConversation(),
                    child: const Text('Reopen',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

          // Message Stream
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
                          color:
                              msg.isRead ? Colors.cyanAccent : Colors.white70,
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
                decoration: InputDecoration(
                  hintText: (chatCtrl.activeConversation?.isClosed ?? false)
                      ? 'Type to reopen ticket and reply...'
                      : 'Type your message...',
                  hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
