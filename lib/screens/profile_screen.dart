import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/routes/app_routes.dart';
import '../controllers/auth_controller.dart';
import '../controllers/order_controller.dart';
import '../models/order.dart';
import '../theme/colors.dart';
import '../utils/money.dart';

enum ProfileOrderTab {
  all('All Orders'),
  placed('Placed'),
  processing('Processing'),
  delivered('Delivered'),
  completed('Completed');

  final String label;
  const ProfileOrderTab(this.label);
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ProfileOrderTab _selectedTab = ProfileOrderTab.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initUserOrders();
    });
  }

  void _initUserOrders() {
    if (!mounted) return;
    if (Get.isRegistered<AuthController>() && Get.isRegistered<OrderController>()) {
      final authCtrl = Get.find<AuthController>();
      final orderCtrl = Get.find<OrderController>();
      final uid = _resolveAuthenticatedUserId(authCtrl);
      if (uid != null && uid.isNotEmpty) {
        orderCtrl.refreshOrders(uid);
        orderCtrl.subscribeToOrders(uid);
      }
    }
  }

  String? _resolveAuthenticatedUserId(AuthController authCtrl) {
    try {
      final supaUser = Supabase.instance.client.auth.currentUser;
      if (supaUser != null && supaUser.id.isNotEmpty) {
        return supaUser.id;
      }
    } catch (_) {}
    return authCtrl.currentUser?.id;
  }

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.placed:
        return Colors.blue;
      case OrderStatus.processing:
        return Colors.orange;
      case OrderStatus.shipped:
        return Colors.purple;
      case OrderStatus.delivered:
        return const Color(0xFF10B981); // Emerald Green
      case OrderStatus.completed:
        return const Color(0xFF059669); // Forest / Deep Emerald
    }
  }

  List<ShopOrder> _filterOrders(List<ShopOrder> orders, ProfileOrderTab tab) {
    return switch (tab) {
      ProfileOrderTab.all => orders,
      ProfileOrderTab.placed =>
        orders.where((o) => o.status == OrderStatus.placed).toList(),
      ProfileOrderTab.processing => orders
          .where((o) =>
              o.status == OrderStatus.processing ||
              o.status == OrderStatus.shipped)
          .toList(),
      ProfileOrderTab.delivered =>
        orders.where((o) => o.status == OrderStatus.delivered).toList(),
      ProfileOrderTab.completed =>
        orders.where((o) => o.status == OrderStatus.completed).toList(),
    };
  }

  String _emptyStateMessage(ProfileOrderTab tab) {
    return switch (tab) {
      ProfileOrderTab.all => 'No orders placed yet.',
      ProfileOrderTab.placed => 'No placed orders yet.',
      ProfileOrderTab.processing => 'No processing orders yet.',
      ProfileOrderTab.delivered => 'No delivered orders yet.',
      ProfileOrderTab.completed => 'No completed orders yet.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final authCtrl = Get.find<AuthController>();
    final orderCtrl = Get.find<OrderController>();

    return Obx(() {
      final user = authCtrl.currentUser;

      if (user == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Account')),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hello, guest',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text(
                    'Log in to track orders, save a wishlist, and check out faster.'),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
                    child: const Text('Login'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.register),
                    child: const Text('Register'),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      final authId = _resolveAuthenticatedUserId(authCtrl);
      final userOrders = orderCtrl.getOrdersForAuthenticatedUser(
        userId: authId,
        user: user,
      );
      final filteredOrders = _filterOrders(userOrders, _selectedTab);

      return Scaffold(
        appBar: AppBar(title: const Text('My profile')),
        body: RefreshIndicator(
          onRefresh: () async {
            if (authId != null) {
              await orderCtrl.refreshOrders(authId);
            }
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // User Avatar & Details Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: ShopColors.primary,
                      child: Text(
                        user.name.characters.first.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            user.email,
                            style: const TextStyle(color: ShopColors.muted),
                          ),
                          if (user.phone.isNotEmpty)
                            Text(
                              user.phone,
                              style: const TextStyle(color: ShopColors.muted),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Wishlist Tile
              ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: const Icon(Icons.favorite_border,
                    color: ShopColors.primary),
                title: const Text('Wishlist'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, AppRoutes.wishlist),
              ),
              const SizedBox(height: 8),

              // Customer Support Tile
              ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: const Icon(Icons.support_agent,
                    color: ShopColors.primary),
                title: const Text('Customer Support'),
                subtitle: const Text('Chat with Admin & Order Assistance'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, AppRoutes.supportChat),
              ),

              // Admin Dashboard Tile (if Admin)
              if (user.isAdmin) ...[
                const SizedBox(height: 8),
                ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: const Icon(Icons.admin_panel_settings_outlined,
                    color: ShopColors.primary),
                  title: const Text('Admin dashboard'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.adminDashboard),
                ),
              ],
              const SizedBox(height: 24),

              // My Orders Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Orders',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (orderCtrl.isLoadingUserOrders)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Filter Category Chips: [ All Orders ] [ Placed ] [ Processing ] [ Delivered ]
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ProfileOrderTab.values.map((tab) {
                    final isSelected = _selectedTab == tab;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        key: ValueKey('order_tab_${tab.name}'),
                        label: Text(tab.label),
                        selected: isSelected,
                        selectedColor: ShopColors.primary,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : ShopColors.text,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? ShopColors.primary
                                : Colors.grey.shade300,
                          ),
                        ),
                        onSelected: (_) {
                          setState(() => _selectedTab = tab);
                          if (authId != null) {
                            orderCtrl.refreshOrders(authId);
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),

              // Orders List or Empty State
              if (filteredOrders.isEmpty)
                Container(
                  key: ValueKey('empty_state_${_selectedTab.name}'),
                  padding: const EdgeInsets.symmetric(
                    vertical: 28,
                    horizontal: 16,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 36, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        _emptyStateMessage(_selectedTab),
                        style: const TextStyle(
                          color: ShopColors.muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...filteredOrders.map(
                  (o) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      key: ValueKey('order_card_${o.id}'),
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.orderConfirmation,
                        arguments: o.id,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Order #${o.id}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusColor(o.status).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _statusColor(o.status).withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Text(
                                    o.status.label,
                                    style: TextStyle(
                                      color: _statusColor(o.status),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Status: ${o.status.label}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: ShopColors.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Date: ${DateFormat('MMM dd, yyyy').format(o.createdAt)}',
                              style: const TextStyle(
                                color: ShopColors.muted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total: ${pkr.format(o.total)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Row(
                                  children: [
                                    Text(
                                      'Details',
                                      style: TextStyle(
                                        color: ShopColors.primary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      size: 16,
                                      color: ShopColors.primary,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                if (o.status == OrderStatus.delivered) ...[
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      key: ValueKey('mark_completed_${o.id}'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF059669),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 9),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      icon: const Icon(Icons.check_circle_outline, size: 16),
                                      label: const Text(
                                        '✓ Mark as Completed',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      onPressed: () async {
                                        final ok = await orderCtrl.markOrderAsCompleted(
                                          o.id,
                                          userId: authId,
                                        );
                                        if (ok && context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Order #${o.id} marked as Completed!'),
                                              backgroundColor: const Color(0xFF059669),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ] else ...[
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      key: ValueKey('view_order_${o.id}'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 9),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      icon: const Icon(Icons.receipt_outlined, size: 16),
                                      label: const Text(
                                        'View Order',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      onPressed: () => Navigator.pushNamed(
                                        context,
                                        AppRoutes.orderConfirmation,
                                        arguments: o.id,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: OutlinedButton.icon(
                                    key: ValueKey('contact_support_${o.id}'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: ShopColors.primary,
                                      side: const BorderSide(color: ShopColors.primary),
                                      padding: const EdgeInsets.symmetric(vertical: 9),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    icon: const Icon(Icons.chat_outlined, size: 16),
                                    label: const Text(
                                      '💬 Contact Support',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    onPressed: () => Navigator.pushNamed(
                                      context,
                                      AppRoutes.supportChat,
                                      arguments: o.id,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Logout Button
              OutlinedButton(
                onPressed: () => authCtrl.logout(),
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      );
    });
  }
}
