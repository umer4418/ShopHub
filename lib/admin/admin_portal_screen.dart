import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../app/routes/app_routes.dart';
import '../controllers/auth_controller.dart';
import '../controllers/coupon_controller.dart';
import '../controllers/order_controller.dart';
import '../controllers/product_controller.dart';
import '../controllers/support_chat_controller.dart';
import '../models/category.dart';
import '../models/coupon.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/user.dart';
import '../theme/colors.dart';
import '../utils/money.dart';
import 'admin_login_screen.dart';
import 'admin_support_screen.dart';

const Color _kEmerald = Color(0xFF10B981);
const Color _kEmeraldDark = Color(0xFF065F46);

/// Admin Portal Screen
/// Enterprise Web Dashboard for ShopHub Super Admin.
class AdminPortalScreen extends StatefulWidget {
  const AdminPortalScreen({super.key});

  static const route = AppRoutes.adminDashboard;

  @override
  State<AdminPortalScreen> createState() => _AdminPortalScreenState();
}

class _AdminPortalScreenState extends State<AdminPortalScreen> {
  int _selectedTab = 0; // 0: Dashboard, 1: Orders, 2: Products, 3: Categories, 4: Coupons, 5: Users, 6: Payments, 7: Support, 8: Settings
  String _orderSearchQuery = '';
  String _orderStatusFilter = 'all';
  String _orderPaymentFilter = 'all';
  String _dashboardPeriod = 'all'; // 'all', 'month', 'week', 'today'
  String _productSearchQuery = '';
  String? _productCategoryFilter;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isRegistered<OrderController>()) {
        Get.find<OrderController>().refreshOrders();
      }
      final chatCtrl = Get.isRegistered<SupportChatController>()
          ? Get.find<SupportChatController>()
          : Get.put(SupportChatController());
      chatCtrl.loadAdminConversations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authCtrl = Get.find<AuthController>();

    return Obx(() {
      final user = authCtrl.currentUser;

      // Access Control: Only Super Admin can access this portal
      if (user == null || !user.isAdmin) {
        return const AdminLoginScreen();
      }

      final isDesktop = MediaQuery.of(context).size.width >= 1000;

      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFF1F5F9), // Light enterprise slate background
        drawer: isDesktop ? null : _buildSidebar(isDrawer: true),
        bottomNavigationBar: isDesktop ? null : _buildMobileBottomBar(),
        body: Row(
          children: [
            if (isDesktop) _buildSidebar(isDrawer: false),
            Expanded(
              child: Column(
                children: [
                  _buildHeader(context, isDesktop),
                  Expanded(
                    child: IndexedStack(
                      index: _selectedTab,
                      children: [
                        _buildDashboardTab(),
                        _buildOrdersTab(),
                        _buildProductsTab(),
                        _buildCategoriesTab(),
                        _buildCouponsTab(),
                        _buildUsersTab(),
                        _buildPaymentsTab(),
                        const AdminSupportScreen(isEmbedded: true),
                        _buildSettingsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  // ==========================================
  // MOBILE BOTTOM NAVIGATION BAR
  // ==========================================
  Widget _buildMobileBottomBar() {
    final supportChatCtrl = Get.isRegistered<SupportChatController>()
        ? Get.find<SupportChatController>()
        : null;

    int currentNavIndex = 4;
    if (_selectedTab == 0) {
      currentNavIndex = 0;
    } else if (_selectedTab == 1) {
      currentNavIndex = 1;
    } else if (_selectedTab == 2) {
      currentNavIndex = 2;
    } else if (_selectedTab == 7) {
      currentNavIndex = 3;
    }

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(top: BorderSide(color: Color(0xFF1E293B))),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            indicatorColor: ShopColors.primary.withValues(alpha: 0.22),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const TextStyle(
                  color: ShopColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                );
              }
              return const TextStyle(
                color: Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: ShopColors.primary, size: 22);
              }
              return const IconThemeData(color: Colors.white60, size: 22);
            }),
          ),
          child: NavigationBar(
            backgroundColor: const Color(0xFF0F172A),
            selectedIndex: currentNavIndex,
            height: 60,
            onDestinationSelected: (index) {
              if (index == 0) {
                setState(() => _selectedTab = 0);
              } else if (index == 1) {
                setState(() => _selectedTab = 1);
              } else if (index == 2) {
                setState(() => _selectedTab = 2);
              } else if (index == 3) {
                setState(() => _selectedTab = 7);
              } else if (index == 4) {
                _scaffoldKey.currentState?.openDrawer();
              }
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              const NavigationDestination(
                icon: Icon(Icons.shopping_bag_outlined),
                selectedIcon: Icon(Icons.shopping_bag),
                label: 'Orders',
              ),
              const NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: 'Products',
              ),
              NavigationDestination(
                icon: supportChatCtrl != null
                    ? Obx(() {
                        final unread = supportChatCtrl.totalAdminUnreadCount;
                        return Badge(
                          isLabelVisible: unread > 0,
                          label: Text('$unread'),
                          child: const Icon(Icons.support_agent_outlined),
                        );
                      })
                    : const Icon(Icons.support_agent_outlined),
                selectedIcon: const Icon(Icons.support_agent),
                label: 'Support',
              ),
              const NavigationDestination(
                icon: Icon(Icons.menu_rounded),
                selectedIcon: Icon(Icons.menu_open_rounded),
                label: 'More',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // SIDEBAR NAVIGATION
  // ==========================================
  Widget _buildSidebar({required bool isDrawer}) {
    final authCtrl = Get.find<AuthController>();

    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Enterprise Dark Slate
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo & Super Admin Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ShopColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.storefront, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ShopHub',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                      Row(
                        children: const [
                          Icon(Icons.shield, color: Colors.amber, size: 12),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Super Admin Portal',
                              style: TextStyle(color: Colors.white60, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),

          // Menu Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              children: [
                _navItem(0, Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
                _navItem(1, Icons.receipt_long_outlined, Icons.receipt_long, 'Orders & Details'),
                _navItem(2, Icons.inventory_2_outlined, Icons.inventory_2, 'Products & Stock'),
                _navItem(3, Icons.category_outlined, Icons.category, 'Categories'),
                _navItem(4, Icons.local_offer_outlined, Icons.local_offer, 'Coupons & Promos'),
                _navItem(5, Icons.people_outline, Icons.people, 'Customers & Users'),
                _navItem(6, Icons.payment_outlined, Icons.payment, 'Payments & Subscriptions'),
                Builder(builder: (context) {
                  final supportChatCtrl = Get.isRegistered<SupportChatController>()
                      ? Get.find<SupportChatController>()
                      : null;
                  if (supportChatCtrl == null) {
                    return _navItem(
                      7,
                      Icons.support_agent_outlined,
                      Icons.support_agent,
                      'Customer Support',
                    );
                  }
                  return Obx(() {
                    return _navItem(
                      7,
                      Icons.support_agent_outlined,
                      Icons.support_agent,
                      'Customer Support',
                      badge: supportChatCtrl.totalAdminUnreadCount,
                    );
                  });
                }),
                _navItem(8, Icons.settings_outlined, Icons.settings, 'Settings'),
              ],
            ),
          ),

          const Divider(color: Colors.white10, height: 1),

          // Logged in Super Admin Card & Logout
          Obx(() {
            final user = authCtrl.currentUser;
            final name = (user?.name != null && user!.name.trim().isNotEmpty) ? user.name.trim() : 'Super Admin';
            final email = (user?.email != null && user!.email.trim().isNotEmpty) ? user.email.trim() : 'admin@shophub.com';
            final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';

            return Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF1E293B),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: ShopColors.primary,
                    child: Text(
                      initial,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          email,
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Logout',
                    icon: const Icon(Icons.logout, color: Colors.white60, size: 20),
                    onPressed: () async {
                      await authCtrl.logout();
                      if (!mounted) return;
                      Navigator.pushReplacementNamed(context, AppRoutes.home);
                    },
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _navItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label, {
    int badge = 0,
  }) {
    final isSelected = _selectedTab == index;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          dense: true,
          selected: isSelected,
          selectedTileColor: ShopColors.primary.withValues(alpha: 0.15),
          leading: Icon(
            isSelected ? activeIcon : icon,
            color: isSelected ? ShopColors.primary : Colors.white60,
            size: 20,
          ),
          title: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13.5,
            ),
          ),
          trailing: badge > 0
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : null,
          onTap: () {
            setState(() => _selectedTab = index);
            if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
              Navigator.pop(context);
            }
          },
        ),
      ),
    );
  }

  // ==========================================
  // TOP APP HEADER
  // ==========================================
  Widget _buildHeader(BuildContext context, bool isDesktop) {
    final titles = [
      'Dashboard & Analytics',
      'Orders Management',
      'Products & Inventory',
      'Category Management',
      'Coupons & Discount Codes',
      'Customers & User Data',
      'Payments & Subscriptions',
      'Customer Support & Chats',
      'Store Settings',
    ];

    final isSmall = MediaQuery.of(context).size.width < 600;

    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: isSmall ? 10 : 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          if (!isDesktop) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.black87),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                titles[_selectedTab],
                style: TextStyle(
                  fontSize: isSmall ? 16 : 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // System Live Status Chip
          if (isDesktop) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _kEmerald.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 3.5, backgroundColor: Colors.green),
                  SizedBox(width: 6),
                  Text(
                    'Store Live',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ],

          // Live Data Refresh Button
          IconButton(
            tooltip: 'Refresh Data',
            visualDensity: isSmall ? VisualDensity.compact : null,
            icon: const Icon(Icons.refresh, color: ShopColors.primary, size: 20),
            onPressed: () {
              if (Get.isRegistered<OrderController>()) {
                Get.find<OrderController>().refreshOrders();
              }
              if (Get.isRegistered<ProductController>()) {
                Get.find<ProductController>().init();
              }
            },
          ),
          SizedBox(width: isSmall ? 4 : 8),

          // Visit Storefront Button
          if (isSmall)
            IconButton(
              tooltip: 'Storefront',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.storefront, color: ShopColors.primary, size: 20),
              onPressed: () => Navigator.pushNamed(context, AppRoutes.home),
            )
          else
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: ShopColors.primary,
                side: const BorderSide(color: ShopColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () => Navigator.pushNamed(context, AppRoutes.home),
              icon: const Icon(Icons.storefront, size: 16),
              label: const Text('Storefront', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: 📊 DASHBOARD & FINANCIAL ANALYTICS
  // ==========================================
  Widget _buildDashboardTab() {
    final orderCtrl = Get.find<OrderController>();
    final productCtrl = Get.find<ProductController>();

    return Obx(() {
      final allOrders = orderCtrl.orders;

      // Filter orders by dashboard period
      final now = DateTime.now();
      final filteredOrders = allOrders.where((o) {
        if (_dashboardPeriod == 'today') {
          return o.createdAt.year == now.year &&
              o.createdAt.month == now.month &&
              o.createdAt.day == now.day;
        } else if (_dashboardPeriod == 'week') {
          return now.difference(o.createdAt).inDays <= 7;
        } else if (_dashboardPeriod == 'month') {
          return now.difference(o.createdAt).inDays <= 30;
        }
        return true;
      }).toList();

      final totalEarnings =
          filteredOrders.fold<double>(0, (sum, o) => sum + o.total);
      final totalOrdersCount = filteredOrders.length;
      final avgOrderValue = totalOrdersCount > 0 ? totalEarnings / totalOrdersCount : 0.0;

      // Weekly & Monthly calculations for comparison
      final weeklyOrders =
          allOrders.where((o) => now.difference(o.createdAt).inDays <= 7).toList();
      final weeklyEarnings =
          weeklyOrders.fold<double>(0, (sum, o) => sum + o.total);

      final monthlyOrders =
          allOrders.where((o) => now.difference(o.createdAt).inDays <= 30).toList();
      final monthlyEarnings =
          monthlyOrders.fold<double>(0, (sum, o) => sum + o.total);

      // Payment method breakdown
      final stripeOrders =
          filteredOrders.where((o) => o.paymentMethod.toLowerCase().contains('stripe') || o.paymentMethod.toLowerCase().contains('card')).toList();
      final stripeEarnings =
          stripeOrders.fold<double>(0, (sum, o) => sum + o.total);

      final codOrders =
          filteredOrders.where((o) => o.paymentMethod.toLowerCase().contains('delivery') || o.paymentMethod.toLowerCase().contains('cod')).toList();
      final codEarnings =
          codOrders.fold<double>(0, (sum, o) => sum + o.total);

      final lowStockProducts =
          productCtrl.products.where((p) => p.stock <= 5).toList();

      return LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < 650;
          return RefreshIndicator(
            onRefresh: () => orderCtrl.refreshOrders(),
            child: ListView(
              padding: EdgeInsets.all(isSmall ? 14 : 24),
              children: [
                // Period Selector Bar
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Executive Store Overview',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Real-time metrics, earnings, and operational health.',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        ),
                      ],
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _periodButton('All Time', 'all'),
                            _periodButton('This Month', 'month'),
                            _periodButton('This Week', 'week'),
                            _periodButton('Today', 'today'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 4 Major KPI Cards
                LayoutBuilder(
                  builder: (context, gridConstraints) {
                    final isWide = gridConstraints.maxWidth >= 900;
                    final crossAxisCount = isWide ? 4 : 2;
                    final childAspectRatio = isWide
                        ? 1.25
                        : (gridConstraints.maxWidth < 380 ? 1.1 : 1.25);
                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: isSmall ? 10 : 16,
                      mainAxisSpacing: isSmall ? 10 : 16,
                      childAspectRatio: childAspectRatio,
                      children: [
                        _kpiCard(
                          title: 'Total Earnings',
                          value: pkr.format(totalEarnings),
                          subtitle: '+18.4% vs last period',
                          icon: Icons.payments_outlined,
                          color: _kEmerald,
                        ),
                        _kpiCard(
                          title: 'Total Orders',
                          value: '$totalOrdersCount',
                          subtitle: '${weeklyOrders.length} placed this week',
                          icon: Icons.shopping_bag_outlined,
                          color: Colors.blue,
                        ),
                        _kpiCard(
                          title: 'Average Order Value',
                          value: pkr.format(avgOrderValue),
                          subtitle: 'Per completed order',
                          icon: Icons.trending_up,
                          color: Colors.deepPurple,
                        ),
                        _kpiCard(
                          title: 'Catalog Inventory',
                          value: '${productCtrl.products.length} Products',
                          subtitle: '${lowStockProducts.length} low stock items',
                          icon: Icons.inventory_2_outlined,
                          color: Colors.orange,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Financial Breakdown & Payment Methods Split
                LayoutBuilder(
                  builder: (context, flexConstraints) {
                    final isWide = flexConstraints.maxWidth >= 900;

                    final weeklyMonthlyCard = Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.calendar_month, color: ShopColors.primary, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Weekly & Monthly Earnings Summary',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _revenueComparisonRow(
                            label: 'This Week Earnings (Last 7 Days)',
                            ordersCount: weeklyOrders.length,
                            amount: weeklyEarnings,
                            color: Colors.blue,
                            percentage: monthlyEarnings > 0
                                ? (weeklyEarnings / monthlyEarnings).clamp(0.0, 1.0)
                                : 0.5,
                          ),
                          const SizedBox(height: 18),
                          _revenueComparisonRow(
                            label: 'This Month Earnings (Last 30 Days)',
                            ordersCount: monthlyOrders.length,
                            amount: monthlyEarnings,
                            color: _kEmerald,
                            percentage: 1.0,
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: ShopColors.muted, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Average weekly growth is tracking +14% above projected baseline across Pakistani metropolitan areas.',
                                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );

                    final paymentBreakdownCard = Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.pie_chart_outline, color: ShopColors.primary, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Payment Methods Breakdown',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              height: 12,
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: (stripeEarnings > 0 ? stripeEarnings : 1).toInt(),
                                    child: Container(color: const Color(0xFF6366F1)), // Stripe Indigo
                                  ),
                                  Expanded(
                                    flex: (codEarnings > 0 ? codEarnings : 1).toInt(),
                                    child: Container(color: const Color(0xFF10B981)), // COD Green
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          _paymentMethodTile(
                            title: 'Online Stripe Card Payments',
                            orders: stripeOrders.length,
                            amount: stripeEarnings,
                            color: const Color(0xFF6366F1),
                            icon: Icons.credit_card,
                          ),
                          const SizedBox(height: 14),
                          _paymentMethodTile(
                            title: 'Cash on Delivery (COD)',
                            orders: codOrders.length,
                            amount: codEarnings,
                            color: const Color(0xFF10B981),
                            icon: Icons.local_shipping_outlined,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: ShopColors.primary.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: ShopColors.primary.withValues(alpha: 0.2)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.card_membership, color: ShopColors.primary, size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'ShopHub VIP Club Subscriptions',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12.5,
                                          color: ShopColors.primaryDark,
                                        ),
                                      ),
                                      Text(
                                        '42 Active members (Monthly recurring perks & free delivery)',
                                        style: TextStyle(fontSize: 11, color: ShopColors.muted),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6, child: weeklyMonthlyCard),
                          const SizedBox(width: 20),
                          Expanded(flex: 5, child: paymentBreakdownCard),
                        ],
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          weeklyMonthlyCard,
                          const SizedBox(height: 16),
                          paymentBreakdownCard,
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 24),

                // Low Stock Alert (if any)
                if (lowStockProducts.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                    ),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Inventory Warning: ${lowStockProducts.length} product(s) low on stock (<= 5 units remaining)',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                  ),
                                  Text(
                                    lowStockProducts.map((p) => '${p.name} (${p.stock} left)').take(3).join(', '),
                                    style: TextStyle(color: Colors.grey.shade800, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade700,
                            foregroundColor: Colors.white,
                            elevation: 0,
                          ),
                          onPressed: () => setState(() => _selectedTab = 2), // Go to products
                          child: const Text('Restock Now'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Recent Orders Mini Table
                Container(
                  padding: EdgeInsets.all(isSmall ? 14 : 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Recent Orders Summary',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _selectedTab = 1),
                            child: const Text('View All Orders ➔'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildOrdersTable(filteredOrders.take(5).toList()),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }

  Widget _periodButton(String label, String value) {
    final isSelected = _dashboardPeriod == value;
    return InkWell(
      onTap: () => setState(() => _dashboardPeriod = value),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? ShopColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _revenueComparisonRow({
    required String label,
    required int ordersCount,
    required double amount,
    required Color color,
    required double percentage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              pkr.format(amount),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$ordersCount orders recorded',
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: 8,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _paymentMethodTile({
    required String title,
    required int orders,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              Text(
                '$orders transactions',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
              ),
            ],
          ),
        ),
        Text(
          pkr.format(amount),
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 2: 📦 ORDERS & ORDER DETAILS
  // ==========================================
  Widget _buildOrdersTab() {
    final orderCtrl = Get.find<OrderController>();

    return Obx(() {
      final all = orderCtrl.orders;

      final filtered = all.where((o) {
        final matchesQuery = _orderSearchQuery.isEmpty ||
            o.id.toLowerCase().contains(_orderSearchQuery.toLowerCase()) ||
            o.customerName.toLowerCase().contains(_orderSearchQuery.toLowerCase()) ||
            o.phone.contains(_orderSearchQuery);

        final matchesStatus = _orderStatusFilter == 'all' ||
            o.status.name.toLowerCase() == _orderStatusFilter.toLowerCase();

        final matchesPayment = _orderPaymentFilter == 'all' ||
            (_orderPaymentFilter == 'stripe' && o.paymentMethod.toLowerCase().contains('stripe')) ||
            (_orderPaymentFilter == 'cod' && (o.paymentMethod.toLowerCase().contains('delivery') || o.paymentMethod.toLowerCase().contains('cod')));

        return matchesQuery && matchesStatus && matchesPayment;
      }).toList();

      return LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < 650;
          return RefreshIndicator(
            onRefresh: () => orderCtrl.refreshOrders(),
            child: ListView(
              padding: EdgeInsets.all(isSmall ? 14 : 24),
              children: [
                // Filter Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Search Input
                      SizedBox(
                        width: isSmall ? double.infinity : 260,
                        height: 40,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search Order ID or Customer...',
                            hintStyle: const TextStyle(fontSize: 12.5),
                            prefixIcon: const Icon(Icons.search, size: 18),
                            contentPadding: EdgeInsets.zero,
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                          onChanged: (v) => setState(() => _orderSearchQuery = v),
                        ),
                      ),

                      // Status Filter
                      SizedBox(
                        width: isSmall ? double.infinity : null,
                        child: DropdownButton<String>(
                          isExpanded: isSmall,
                          value: _orderStatusFilter,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                            DropdownMenuItem(value: 'placed', child: Text('Placed')),
                            DropdownMenuItem(value: 'processing', child: Text('Processing')),
                            DropdownMenuItem(value: 'shipped', child: Text('Shipped')),
                            DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
                            DropdownMenuItem(value: 'completed', child: Text('Completed')),
                          ],
                          onChanged: (v) => setState(() => _orderStatusFilter = v ?? 'all'),
                        ),
                      ),

                      // Payment Filter
                      SizedBox(
                        width: isSmall ? double.infinity : null,
                        child: DropdownButton<String>(
                          isExpanded: isSmall,
                          value: _orderPaymentFilter,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All Payment Methods')),
                            DropdownMenuItem(value: 'stripe', child: Text('Stripe (Card)')),
                            DropdownMenuItem(value: 'cod', child: Text('Cash on Delivery')),
                          ],
                          onChanged: (v) => setState(() => _orderPaymentFilter = v ?? 'all'),
                        ),
                      ),

                      IconButton(
                        tooltip: 'Refresh Orders',
                        icon: const Icon(Icons.refresh, color: ShopColors.primary),
                        onPressed: () => orderCtrl.refreshOrders(),
                      ),

                      Text(
                        '${filtered.length} Orders matching',
                        style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Orders Table
                Container(
                  padding: EdgeInsets.all(isSmall ? 14 : 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: _buildOrdersTable(filtered),
                ),
              ],
            ),
          );
        },
      );
    });
  }

  DataColumn _tableHeader(
    String label, {
    bool numeric = false,
    String? tooltip,
    void Function(int, bool)? onSort,
  }) {
    return DataColumn(
      numeric: numeric,
      tooltip: tooltip,
      onSort: onSort,
      label: Flexible(
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
      ),
    );
  }

  Widget _buildOrderCard(ShopOrder o, OrderController orderCtrl) {
    final isStripe = o.paymentMethod.toLowerCase().contains('stripe') ||
        o.paymentMethod.toLowerCase().contains('card');
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(o.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                o.id,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: ShopColors.primary,
                ),
              ),
              PopupMenuButton<OrderStatus>(
                tooltip: 'Update Status',
                onSelected: (s) => orderCtrl.updateOrderStatus(o.id, s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor(o.status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _statusColor(o.status).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(radius: 3, backgroundColor: _statusColor(o.status)),
                      const SizedBox(width: 5),
                      Text(
                        o.status.label,
                        style: TextStyle(
                          color: _statusColor(o.status),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_drop_down, color: _statusColor(o.status), size: 16),
                    ],
                  ),
                ),
                itemBuilder: (_) => OrderStatus.values
                    .map((s) => PopupMenuItem(value: s, child: Text(s.label)))
                    .toList(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 15, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  o.customerName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isStripe ? Colors.indigo.withValues(alpha: 0.12) : _kEmerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isStripe ? 'Stripe Card' : 'Cash on Delivery',
                  style: TextStyle(
                    color: isStripe ? Colors.indigo : _kEmeraldDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (o.phone.isNotEmpty) ...[
                const Icon(Icons.phone_outlined, size: 13, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  o.phone,
                  style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  dateStr,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                pkr.format(o.total),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: Color(0xFF0F172A),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _showOrderDetailsDialog(context, o),
                icon: const Icon(Icons.visibility_outlined, size: 14),
                label: const Text('View Details', style: TextStyle(fontSize: 11.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersTable(List<ShopOrder> orders) {
    final orderCtrl = Get.find<OrderController>();

    if (orders.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text('No orders found matching the filter.', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;
        if (isMobile) {
          return Column(
            children: orders.map((o) => _buildOrderCard(o, orderCtrl)).toList(),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            horizontalMargin: 16,
            columnSpacing: 24,
            columns: [
              _tableHeader('Order ID'),
              _tableHeader('Customer'),
              _tableHeader('Date'),
              _tableHeader('Payment'),
              _tableHeader('Total'),
              _tableHeader('Status'),
              _tableHeader('Actions'),
            ],
        rows: orders.map((o) {
          final isStripe = o.paymentMethod.toLowerCase().contains('stripe') ||
              o.paymentMethod.toLowerCase().contains('card');
          final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(o.createdAt);

          return DataRow(
            cells: [
              DataCell(
                Text(
                  o.id,
                  style: const TextStyle(fontWeight: FontWeight.w800, color: ShopColors.primary),
                ),
              ),
              DataCell(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      o.customerName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      o.phone,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              DataCell(Text(dateStr, style: const TextStyle(fontSize: 12))),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isStripe ? Colors.indigo.withValues(alpha: 0.12) : _kEmerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isStripe ? 'Stripe Card' : 'Cash on Delivery',
                    style: TextStyle(
                      color: isStripe ? Colors.indigo : _kEmeraldDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              DataCell(
                Text(
                  pkr.format(o.total),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              // Status Badge with Live Dropdown Update
              DataCell(
                PopupMenuButton<OrderStatus>(
                  tooltip: 'Update Status',
                  onSelected: (s) => orderCtrl.updateOrderStatus(o.id, s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(o.status).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _statusColor(o.status).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(radius: 3, backgroundColor: _statusColor(o.status)),
                        const SizedBox(width: 6),
                        Text(
                          o.status.label,
                          style: TextStyle(
                            color: _statusColor(o.status),
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down, color: _statusColor(o.status), size: 16),
                      ],
                    ),
                  ),
                  itemBuilder: (_) => OrderStatus.values
                      .map((s) => PopupMenuItem(value: s, child: Text(s.label)))
                      .toList(),
                ),
              ),
              // Action Details
              DataCell(
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  onPressed: () => _showOrderDetailsDialog(context, o),
                  child: const Text('View Details', style: TextStyle(fontSize: 11.5)),
                ),
              ),
            ],
          );
        }).toList(),
          ),
        );
      },
    );
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
        return _kEmerald;
      case OrderStatus.completed:
        return const Color(0xFF0D9488);
    }
  }

  void _showOrderDetailsDialog(BuildContext context, ShopOrder order) {
    final orderCtrl = Get.find<OrderController>();

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final current = orderCtrl.getOrderById(order.id) ?? order;
            final isStripe = current.paymentMethod.toLowerCase().contains('stripe') ||
                current.paymentMethod.toLowerCase().contains('card');

            final isMobile = MediaQuery.of(ctx).size.width < 600;

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: 650,
                  maxHeight: MediaQuery.of(ctx).size.height * 0.88,
                ),
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ShopColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.receipt_long, color: ShopColors.primary),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Order Details: ${current.id}',
                                style: TextStyle(
                                  fontSize: isMobile ? 15 : 18,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                DateFormat('dd MMM yyyy, hh:mm a').format(current.createdAt),
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(height: 28),

                    Expanded(
                      child: ListView(
                        children: [
                          // Customer & Delivery Information
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Delivery & Customer Information',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Name: ${current.customerName}',
                                        style: const TextStyle(fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.phone_outlined, size: 16, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Phone: ${current.phone}',
                                        style: const TextStyle(fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text('Address: ${current.address}', style: const TextStyle(fontSize: 13)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(isStripe ? Icons.credit_card : Icons.local_shipping, size: 16, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Payment: ${current.paymentMethod}',
                                        style: const TextStyle(fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Status Timeline & Updater
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Order Status:', style: TextStyle(fontWeight: FontWeight.w700)),
                              DropdownButton<OrderStatus>(
                                value: current.status,
                                items: OrderStatus.values
                                    .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                                    .toList(),
                                onChanged: (newStatus) {
                                  if (newStatus != null) {
                                    orderCtrl.updateOrderStatus(current.id, newStatus);
                                    setDialogState(() {});
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Ordered Items List
                          const Text('Items Purchased:', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          ...current.items.map(
                            (item) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  item.product.imageUrl,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(Icons.image, size: 48),
                                ),
                              ),
                              title: Text(
                                item.product.name,
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text('Qty: ${item.quantity} × ${pkr.format(item.product.price)}'),
                              trailing: Text(
                                pkr.format(item.product.price * item.quantity),
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                              ),
                            ),
                          ),

                          const Divider(height: 24),
                          if (current.couponCode != null && current.couponCode!.isNotEmpty) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(Icons.local_offer, size: 16, color: Colors.green),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Coupon Applied (${current.couponCode}):',
                                          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '-${pkr.format(current.discountAmount ?? 0)}',
                                  style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.green),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Grand Total:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              Text(pkr.format(current.total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: ShopColors.primary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // TAB 3: 🏷️ PRODUCTS & INVENTORY MANAGEMENT
  // ==========================================
  Widget _buildProductsTab() {
    final productCtrl = Get.find<ProductController>();

    return Obx(() {
      final all = productCtrl.products;

      final filtered = all.where((p) {
        final matchesQuery = _productSearchQuery.isEmpty ||
            p.name.toLowerCase().contains(_productSearchQuery.toLowerCase());
        final matchesCat = _productCategoryFilter == null ||
            p.categoryId == _productCategoryFilter;
        return matchesQuery && matchesCat;
      }).toList();

      return LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < 650;
          return ListView(
            padding: EdgeInsets.all(isSmall ? 14 : 24),
            children: [
              // Products Action Bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: isSmall ? double.infinity : 260,
                      height: 40,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search products by name...',
                          hintStyle: const TextStyle(fontSize: 12.5),
                          prefixIcon: const Icon(Icons.search, size: 18),
                          contentPadding: EdgeInsets.zero,
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        onChanged: (v) => setState(() => _productSearchQuery = v),
                      ),
                    ),

                    SizedBox(
                      width: isSmall ? double.infinity : null,
                      child: DropdownButton<String?>(
                        isExpanded: isSmall,
                        value: _productCategoryFilter,
                        underline: const SizedBox(),
                        hint: const Text('All Categories'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Categories')),
                          ...productCtrl.categories.map(
                            (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                          ),
                        ],
                        onChanged: (v) => setState(() => _productCategoryFilter = v),
                      ),
                    ),

                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ShopColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _openProductFormDialog(context, null),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add New Product'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Products Table or Cards
              Container(
                padding: EdgeInsets.all(isSmall ? 14 : 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: isSmall
                    ? Column(
                        children: filtered
                            .map((p) => _buildProductCard(p, productCtrl))
                            .toList(),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                          columnSpacing: 24,
                          columns: [
                            _tableHeader('Item'),
                            _tableHeader('Category'),
                            _tableHeader('Price'),
                            _tableHeader('Discount'),
                            _tableHeader('Stock Status'),
                            _tableHeader('Actions'),
                          ],
                          rows: filtered.map((p) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.network(
                                          p.imageUrl,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => const Icon(Icons.image, size: 40),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 220),
                                        child: Text(
                                          p.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(Text(p.categoryId)),
                                DataCell(Text(pkr.format(p.price), style: const TextStyle(fontWeight: FontWeight.w700))),
                                DataCell(Text(p.discountPercent > 0 ? '${p.discountPercent}% OFF' : '-')),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: p.stock > 10
                                          ? Colors.green.withValues(alpha: 0.12)
                                          : (p.stock > 0 ? Colors.orange.withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.12)),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      p.stock > 10
                                          ? 'In Stock (${p.stock})'
                                          : (p.stock > 0 ? 'Low Stock (${p.stock})' : 'Out of Stock'),
                                      style: TextStyle(
                                        color: p.stock > 10
                                            ? Colors.green.shade800
                                            : (p.stock > 0 ? Colors.orange.shade800 : Colors.red.shade800),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                        tooltip: 'Edit Product',
                                        onPressed: () => _openProductFormDialog(context, p),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                        tooltip: 'Delete Product',
                                        onPressed: () {
                                          Get.defaultDialog(
                                            title: 'Delete Product',
                                            middleText: 'Are you sure you want to remove "${p.name}"?',
                                            textConfirm: 'Delete',
                                            textCancel: 'Cancel',
                                            confirmTextColor: Colors.white,
                                            buttonColor: Colors.red,
                                            onConfirm: () {
                                              productCtrl.deleteProduct(p.id);
                                              Get.back();
                                            },
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
              ),
            ],
          );
        },
      );
    });
  }

  Widget _buildProductCard(Product p, ProductController productCtrl) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              p.imageUrl,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(Icons.image, size: 56),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                const SizedBox(height: 2),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(
                      pkr.format(p.price),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: ShopColors.primary,
                      ),
                    ),
                    if (p.discountPercent > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${p.discountPercent}% OFF',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: p.stock > 10
                        ? Colors.green.withValues(alpha: 0.12)
                        : (p.stock > 0
                            ? Colors.orange.withValues(alpha: 0.12)
                            : Colors.red.withValues(alpha: 0.12)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    p.stock > 10
                        ? 'In Stock (${p.stock})'
                        : (p.stock > 0 ? 'Low Stock (${p.stock})' : 'Out of Stock'),
                    style: TextStyle(
                      color: p.stock > 10
                          ? Colors.green.shade800
                          : (p.stock > 0 ? Colors.orange.shade800 : Colors.red.shade800),
                      fontWeight: FontWeight.w700,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Edit Product',
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            onPressed: () => _openProductFormDialog(context, p),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
            tooltip: 'Delete Product',
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            onPressed: () {
              Get.defaultDialog(
                title: 'Delete Product',
                middleText: 'Are you sure you want to remove "${p.name}"?',
                textConfirm: 'Delete',
                textCancel: 'Cancel',
                confirmTextColor: Colors.white,
                buttonColor: Colors.red,
                onConfirm: () {
                  productCtrl.deleteProduct(p.id);
                  Get.back();
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _openProductFormDialog(BuildContext context, Product? existing) {
    final productCtrl = Get.find<ProductController>();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(text: existing?.price.toString() ?? '');
    final origPriceCtrl = TextEditingController(text: existing?.originalPrice.toString() ?? '');
    final stockCtrl = TextEditingController(text: existing?.stock.toString() ?? '20');
    final imgCtrl = TextEditingController(text: existing?.imageUrl ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    String catId = existing?.categoryId ?? productCtrl.categories.first.id;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(existing == null ? 'Add New Product' : 'Edit Product'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Product Name'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: catId,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: productCtrl.categories
                            .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                            .toList(),
                        onChanged: (v) => setDialogState(() => catId = v!),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: priceCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Price (PKR)'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: origPriceCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Original Price'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: stockCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Stock Units'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: imgCtrl,
                        decoration: const InputDecoration(labelText: 'Image Web URL'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Description'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: ShopColors.primary),
                  onPressed: () {
                    final price = double.tryParse(priceCtrl.text) ?? 1000;
                    final orig = double.tryParse(origPriceCtrl.text) ?? price;
                    final stock = int.tryParse(stockCtrl.text) ?? 10;
                    final id = existing?.id ?? 'p_${DateTime.now().millisecondsSinceEpoch}';

                    final prod = Product(
                      id: id,
                      name: nameCtrl.text.trim(),
                      categoryId: catId,
                      imageUrl: imgCtrl.text.trim().isNotEmpty
                          ? imgCtrl.text.trim()
                          : 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=800',
                      price: price,
                      originalPrice: orig,
                      stock: stock,
                      description: descCtrl.text.trim(),
                      shortDescription: descCtrl.text.trim(),
                      rating: existing?.rating ?? 4.8,
                      reviewCount: existing?.reviewCount ?? 12,
                      featured: existing?.featured ?? true,
                      popular: existing?.popular ?? true,
                    );

                    if (existing == null) {
                      productCtrl.addProduct(prod);
                    } else {
                      productCtrl.updateProduct(prod);
                    }
                    Navigator.pop(ctx);
                  },
                  child: const Text('Save Product'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================
  // TAB 4: 📂 CATEGORY MANAGEMENT
  // ==========================================
  Widget _buildCategoriesTab() {
    final productCtrl = Get.find<ProductController>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 650;
        final isTablet = constraints.maxWidth >= 650 && constraints.maxWidth < 1000;
        final crossAxisCount = isSmall ? 1 : (isTablet ? 2 : 3);
        final childAspectRatio = isSmall ? 3.6 : (isTablet ? 2.8 : 2.5);

        return Obx(() {
          final categories = productCtrl.categories;

          return ListView(
            padding: EdgeInsets.all(isSmall ? 16 : 24),
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  const Text(
                    'Product Categories',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ShopColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _openCategoryDialog(context, null),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Category'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: childAspectRatio,
                ),
                itemCount: categories.length,
                itemBuilder: (_, i) {
                  final cat = categories[i];
                  final count = productCtrl.products.where((p) => p.categoryId == cat.id).length;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ShopColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.category, color: ShopColors.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                cat.name,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$count items in catalog',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Edit Category',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _openCategoryDialog(context, cat),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                          tooltip: 'Delete Category',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => productCtrl.deleteCategory(cat.id),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        });
      },
    );
  }

  void _openCategoryDialog(BuildContext context, ShopCategory? existing) {
    final productCtrl = Get.find<ProductController>();
    final idCtrl = TextEditingController(text: existing?.id ?? '');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(existing == null ? 'Add Category' : 'Edit Category'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: idCtrl,
                  enabled: existing == null,
                  decoration: const InputDecoration(labelText: 'Category ID (slug, e.g. electronics)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Category Name'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ShopColors.primary),
            onPressed: () {
              final cat = ShopCategory(
                id: idCtrl.text.trim().toLowerCase(),
                name: nameCtrl.text.trim(),
                icon: existing?.icon ?? 'category',
                imageUrl: existing?.imageUrl ?? '',
              );
              if (existing == null) {
                productCtrl.addCategory(cat);
              } else {
                productCtrl.updateCategory(cat);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save Category'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 5: 🎟️ COUPONS & PROMOTIONS MANAGEMENT
  // ==========================================
  Widget _buildCouponsTab() {
    final couponCtrl = Get.find<CouponController>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 650;

        return Obx(() {
          final coupons = couponCtrl.coupons;

          return ListView(
            padding: EdgeInsets.all(isSmall ? 16 : 24),
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 550),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Promotions & Coupon Codes',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Create discount codes for marketing campaigns and loyal customers.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ShopColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _openAddCouponDialog(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create New Coupon'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (isSmall)
                if (coupons.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No coupons created yet.', style: TextStyle(color: Colors.grey))),
                  )
                else
                  Column(
                    children: coupons.map((c) => _buildCouponCard(c, couponCtrl)).toList(),
                  )
              else
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                      columnSpacing: 24,
                      columns: [
                        _tableHeader('Coupon Code'),
                        _tableHeader('Discount'),
                        _tableHeader('Min Spend'),
                        _tableHeader('Usage Count'),
                        _tableHeader('Valid Until'),
                        _tableHeader('Active Status'),
                        _tableHeader('Actions'),
                      ],
                      rows: coupons.map((c) {
                        return DataRow(
                          cells: [
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: ShopColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: ShopColors.primary.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  c.code,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: ShopColors.primaryDark,
                                    fontFamily: 'monospace',
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '${c.discountPercent}% OFF',
                                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.green),
                              ),
                            ),
                            DataCell(Text(pkr.format(c.minOrderAmount))),
                            DataCell(Text('${c.usageCount} times redeemed')),
                            DataCell(Text(DateFormat('dd MMM yyyy, hh:mm a').format(c.expiryDate))),
                            DataCell(
                              Switch(
                                value: c.isActive,
                                activeThumbColor: ShopColors.primary,
                                onChanged: (_) => couponCtrl.toggleCouponStatus(c.id),
                              ),
                            ),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                tooltip: 'Delete Coupon',
                                onPressed: () => couponCtrl.deleteCoupon(c.id),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          );
        });
      },
    );
  }

  Widget _buildCouponCard(Coupon c, CouponController couponCtrl) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ShopColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: ShopColors.primary.withValues(alpha: 0.3)),
                ),
                child: Text(
                  c.code,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: ShopColors.primaryDark,
                    fontFamily: 'monospace',
                    letterSpacing: 1.0,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${c.discountPercent}% OFF',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.green,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.shopping_cart_outlined, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                'Min: ${pkr.format(c.minOrderAmount)}',
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
              const Spacer(),
              const Icon(Icons.repeat, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                '${c.usageCount} used',
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.event_outlined, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Valid: ${DateFormat('dd MMM yyyy, hh:mm a').format(c.expiryDate)}',
                  style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Switch.adaptive(
                    value: c.isActive,
                    activeThumbColor: ShopColors.primary,
                    onChanged: (_) => couponCtrl.toggleCouponStatus(c.id),
                  ),
                  Text(
                    c.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.isActive ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                tooltip: 'Delete Coupon',
                visualDensity: VisualDensity.compact,
                onPressed: () => couponCtrl.deleteCoupon(c.id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openAddCouponDialog(BuildContext context) {
    final couponCtrl = Get.find<CouponController>();
    final codeCtrl = TextEditingController();
    final percentCtrl = TextEditingController(text: '30');
    final minSpendCtrl = TextEditingController(text: '500');
    DateTime selectedDate = DateTime.now().add(const Duration(days: 30));
    TimeOfDay selectedTime = const TimeOfDay(hour: 23, minute: 59);

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Create Discount Coupon'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Promo Code (e.g. CUPON15, SHOPHUB30, EIDSALE)',
                      hintText: 'CUPON15',
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: percentCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Discount Percentage (%)',
                      hintText: '30',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: minSpendCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Minimum Order Amount (PKR)',
                      hintText: '500',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Coupon Validity (Date & Time)',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (context, box) {
                            final dateBtn = OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: selectedDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime(2035),
                                );
                                if (picked != null) {
                                  setDialogState(() => selectedDate = picked);
                                }
                              },
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text(
                                DateFormat('dd MMM yyyy').format(selectedDate),
                                style: const TextStyle(fontSize: 12),
                              ),
                            );

                            final timeBtn = OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: ctx,
                                  initialTime: selectedTime,
                                );
                                if (picked != null) {
                                  setDialogState(() => selectedTime = picked);
                                }
                              },
                              icon: const Icon(Icons.access_time, size: 16),
                              label: Text(
                                selectedTime.format(ctx),
                                style: const TextStyle(fontSize: 12),
                              ),
                            );

                            if (box.maxWidth < 320) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  dateBtn,
                                  const SizedBox(height: 8),
                                  timeBtn,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: dateBtn),
                                const SizedBox(width: 8),
                                Expanded(child: timeBtn),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Expires: ${DateFormat('dd MMM yyyy').format(selectedDate)} at ${selectedTime.format(ctx)}',
                          style: const TextStyle(
                            color: ShopColors.primary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: ShopColors.primary),
              onPressed: () {
                if (codeCtrl.text.trim().isNotEmpty) {
                  final combinedExpiry = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    selectedTime.hour,
                    selectedTime.minute,
                  );
                  couponCtrl.addCoupon(
                    code: codeCtrl.text.trim(),
                    discountPercent: int.tryParse(percentCtrl.text) ?? 10,
                    minOrderAmount: double.tryParse(minSpendCtrl.text) ?? 500,
                    expiryDate: combinedExpiry,
                  );
                }
                Navigator.pop(ctx);
              },
              child: const Text('Create Coupon'),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 6: 👥 CUSTOMERS & USERS DATA
  // ==========================================
  Widget _buildUsersTab() {
    final authCtrl = Get.find<AuthController>();
    final orderCtrl = Get.find<OrderController>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 650;

        return Obx(() {
          final users = authCtrl.users;

          return ListView(
            padding: EdgeInsets.all(isSmall ? 16 : 24),
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 550),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Registered Customers & Administrators',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Overview of registered user accounts from Supabase, order volume, and lifetime spend.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh from Supabase'),
                    onPressed: () async {
                      await authCtrl.fetchUsers();
                      Get.snackbar(
                        'Directory Updated',
                        'Loaded registered customer profiles from Supabase database.',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.black87,
                        colorText: Colors.white,
                        duration: const Duration(seconds: 2),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (isSmall)
                Column(
                  children: users.map((u) => _buildUserCard(u, orderCtrl)).toList(),
                )
              else
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                      columnSpacing: 28,
                      columns: [
                        _tableHeader('User / Customer'),
                        _tableHeader('Email Address'),
                        _tableHeader('Phone Number'),
                        _tableHeader('Access Role'),
                        _tableHeader('Orders Placed'),
                        _tableHeader('Total Spend'),
                      ],
                      rows: users.map((u) {
                        final userOrders = orderCtrl.getUserOrders(
                          phone: u.phone,
                          name: u.name,
                          email: u.email,
                          userId: u.id,
                        );
                        final totalSpent = userOrders.fold<double>(0, (s, o) => s + o.total);

                        return DataRow(
                          cells: [
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: u.isAdmin ? Colors.amber.shade700 : ShopColors.primary,
                                    child: Text(
                                      u.name.isNotEmpty ? u.name[0].toUpperCase() : 'U',
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Text(
                                      u.name,
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(Text(u.email)),
                            DataCell(Text(u.phone.isNotEmpty ? u.phone : 'Not provided', maxLines: 1, softWrap: false)),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: u.isAdmin ? Colors.amber.withValues(alpha: 0.15) : Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  u.isAdmin ? 'Super Admin' : 'Customer',
                                  style: TextStyle(
                                    color: u.isAdmin ? Colors.amber.shade900 : Colors.blue.shade800,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(Text('${userOrders.length} orders')),
                            DataCell(
                              Text(
                                pkr.format(totalSpent),
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          );
        });
      },
    );
  }

  Widget _buildUserCard(ShopUser u, OrderController orderCtrl) {
    final userOrders = orderCtrl.getUserOrders(
      phone: u.phone,
      name: u.name,
      email: u.email,
      userId: u.id,
    );
    final totalSpent = userOrders.fold<double>(0, (s, o) => s + o.total);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: u.isAdmin ? Colors.amber.shade700 : ShopColors.primary,
                child: Text(
                  u.name.isNotEmpty ? u.name[0].toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      u.email,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: u.isAdmin ? Colors.amber.withValues(alpha: 0.15) : Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  u.isAdmin ? 'Super Admin' : 'Customer',
                  style: TextStyle(
                    color: u.isAdmin ? Colors.amber.shade900 : Colors.blue.shade800,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          if (u.phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(u.phone, style: const TextStyle(fontSize: 12, color: Colors.black87)),
              ],
            ),
          ],
          const Divider(height: 16),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                '${userOrders.length} orders placed',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                'Spent: ${pkr.format(totalSpent)}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: ShopColors.primaryDark),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 7: 💳 PAYMENTS & SUBSCRIPTIONS
  // ==========================================
  Widget _buildPaymentsTab() {
    final orderCtrl = Get.find<OrderController>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 700;

        return Obx(() {
          final orders = orderCtrl.orders;
          final stripeOrders = orders.where((o) => o.paymentMethod.toLowerCase().contains('stripe') || o.paymentMethod.toLowerCase().contains('card')).toList();
          final codOrders = orders.where((o) => o.paymentMethod.toLowerCase().contains('delivery') || o.paymentMethod.toLowerCase().contains('cod')).toList();

          final stripeTotal = stripeOrders.fold<double>(0, (s, o) => s + o.total);
          final codTotal = codOrders.fold<double>(0, (s, o) => s + o.total);

          final stripeCard = Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    const Text('Stripe Card Payments', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                      child: const Text('Live Connected (Test Mode)', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(pkr.format(stripeTotal), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
                Text('${stripeOrders.length} transactions processed successfully', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          );

          final codCard = Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    const Text('Cash on Delivery (COD)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                      child: const Text('Nationwide Courier', style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(pkr.format(codTotal), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
                Text('${codOrders.length} orders dispatched with COD invoice', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          );

          return ListView(
            padding: EdgeInsets.all(isSmall ? 16 : 24),
            children: [
              const Text(
                'Payment Gateways & Subscription Services',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Payment integration health, gateway processing metrics, and customer subscription clubs.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 20),

              if (isSmall) ...[
                stripeCard,
                const SizedBox(height: 16),
                codCard,
              ] else
                Row(
                  children: [
                    Expanded(child: stripeCard),
                    const SizedBox(width: 20),
                    Expanded(child: codCard),
                  ],
                ),
              const SizedBox(height: 24),

              // Subscriptions & VIP Club Table
              Container(
                padding: EdgeInsets.all(isSmall ? 16 : 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ShopHub VIP Subscriptions Tiers', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 14),
                    if (isSmall) ...[
                      _buildMobileVipCard(
                        title: 'Gold VIP Membership (PKR 1,999 / mo)',
                        subtitle: '15% off all orders, free express shipping, priority 24/7 support.',
                        members: '18 Active Members',
                        badgeColor: Colors.amber,
                      ),
                      const SizedBox(height: 12),
                      _buildMobileVipCard(
                        title: 'Silver VIP Membership (PKR 999 / mo)',
                        subtitle: '10% off all orders, standard free delivery nationwide.',
                        members: '24 Active Members',
                        badgeColor: Colors.blueGrey,
                      ),
                    ] else ...[
                      ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.amber, child: Icon(Icons.star, color: Colors.white)),
                        title: const Text('Gold VIP Membership (PKR 1,999 / month)', style: TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: const Text('15% off all orders, free express shipping, priority 24/7 customer support.'),
                        trailing: const Text('18 Active Members', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      const Divider(),
                      ListTile(
                        leading: CircleAvatar(backgroundColor: Colors.grey.shade400, child: const Icon(Icons.star, color: Colors.white)),
                        title: const Text('Silver VIP Membership (PKR 999 / month)', style: TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: const Text('10% off all orders, standard free delivery nationwide.'),
                        trailing: const Text('24 Active Members', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _buildMobileVipCard({
    required String title,
    required String subtitle,
    required String members,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: badgeColor,
                child: const Icon(Icons.star, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 11.5)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              members,
              style: TextStyle(color: badgeColor.withValues(alpha: 0.9), fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 8: ⚙️ STORE SETTINGS
  // ==========================================
  Widget _buildSettingsTab() {
    final authCtrl = Get.find<AuthController>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 650;

        return ListView(
          padding: EdgeInsets.all(isSmall ? 16 : 24),
          children: [
            const Text(
              'Store Configuration & Super Admin Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),

            Container(
              padding: EdgeInsets.all(isSmall ? 16 : 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('General Store Settings', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Store Name'),
                    subtitle: const Text('ShopHub Pakistan'),
                    trailing: const Icon(Icons.store),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Store Currency'),
                    subtitle: const Text('Pakistani Rupee (PKR - ₨)'),
                    trailing: const Icon(Icons.attach_money),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Default Nationwide Delivery Fee'),
                    subtitle: const Text('PKR 250 (Free on orders above PKR 2,500)'),
                    trailing: const Icon(Icons.local_shipping),
                  ),
                  const Divider(),
                  Obx(() {
                    final user = authCtrl.currentUser;
                    final name = (user?.name != null && user!.name.trim().isNotEmpty) ? user.name.trim() : 'Super Admin';
                    final email = (user?.email != null && user!.email.trim().isNotEmpty) ? user.email.trim() : 'admin@shophub.com';

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Super Admin Account'),
                      subtitle: Text('$name ($email)'),
                      trailing: const Icon(Icons.admin_panel_settings, color: Colors.amber),
                    );
                  }),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
