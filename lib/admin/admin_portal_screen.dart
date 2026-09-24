import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../app/routes/app_routes.dart';
import '../controllers/auth_controller.dart';
import '../controllers/coupon_controller.dart';
import '../controllers/order_controller.dart';
import '../controllers/product_controller.dart';
import '../models/category.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../theme/colors.dart';
import '../utils/money.dart';
import 'admin_login_screen.dart';

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
  int _selectedTab = 0; // 0: Dashboard, 1: Orders, 2: Products, 3: Categories, 4: Coupons, 5: Users, 6: Payments, 7: Settings
  String _orderSearchQuery = '';
  String _orderStatusFilter = 'all';
  String _orderPaymentFilter = 'all';
  String _dashboardPeriod = 'all'; // 'all', 'month', 'week', 'today'
  String _productSearchQuery = '';
  String? _productCategoryFilter;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
                _navItem(7, Icons.settings_outlined, Icons.settings, 'Settings'),
              ],
            ),
          ),

          const Divider(color: Colors.white10, height: 1),

          // Logged in Super Admin Card & Logout
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: ShopColors.primary,
                  child: Text(
                    'A',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Super Admin',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'admin@shophub.com',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
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
          ),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, IconData activeIcon, String label) {
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
      'Store Settings',
    ];

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              titles[_selectedTab],
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
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

          // Visit Storefront Button
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

      return ListView(
        padding: const EdgeInsets.all(24),
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
              Container(
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
            ],
          ),
          const SizedBox(height: 20),

          // 4 Major KPI Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              return GridView.count(
                crossAxisCount: isWide ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: isWide ? 1.25 : 1.35,
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
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              return Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Weekly vs Monthly Earnings Card
                  Expanded(
                    flex: isWide ? 6 : 0,
                    child: Container(
                      padding: const EdgeInsets.all(20),
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
                    ),
                  ),

                  SizedBox(width: isWide ? 20 : 0, height: isWide ? 0 : 20),

                  // Payment Breakdown: Stripe vs Cash on Delivery
                  Expanded(
                    flex: isWide ? 5 : 0,
                    child: Container(
                      padding: const EdgeInsets.all(20),
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

                          // Visual Split Bar
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

                          // Stripe Stats
                          _paymentMethodTile(
                            title: 'Online Stripe Card Payments',
                            orders: stripeOrders.length,
                            amount: stripeEarnings,
                            color: const Color(0xFF6366F1),
                            icon: Icons.credit_card,
                          ),
                          const SizedBox(height: 14),

                          // COD Stats
                          _paymentMethodTile(
                            title: 'Cash on Delivery (COD)',
                            orders: codOrders.length,
                            amount: codEarnings,
                            color: const Color(0xFF10B981),
                            icon: Icons.local_shipping_outlined,
                          ),
                          const SizedBox(height: 16),

                          // Subscriptions / Recurring preview
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
                    ),
                  ),
                ],
              );
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
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
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
            padding: const EdgeInsets.all(20),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 11,
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

      return ListView(
        padding: const EdgeInsets.all(24),
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
                  width: 260,
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
                DropdownButton<String>(
                  value: _orderStatusFilter,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                    DropdownMenuItem(value: 'placed', child: Text('Placed')),
                    DropdownMenuItem(value: 'processing', child: Text('Processing')),
                    DropdownMenuItem(value: 'shipped', child: Text('Shipped')),
                    DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
                  ],
                  onChanged: (v) => setState(() => _orderStatusFilter = v ?? 'all'),
                ),

                // Payment Filter
                DropdownButton<String>(
                  value: _orderPaymentFilter,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Payment Methods')),
                    DropdownMenuItem(value: 'stripe', child: Text('Stripe (Card)')),
                    DropdownMenuItem(value: 'cod', child: Text('Cash on Delivery')),
                  ],
                  onChanged: (v) => setState(() => _orderPaymentFilter = v ?? 'all'),
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: _buildOrdersTable(filtered),
          ),
        ],
      );
    });
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

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
        horizontalMargin: 16,
        columnSpacing: 24,
        columns: const [
          DataColumn(label: Text('Order ID', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Payment', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
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
                  children: [
                    Text(o.customerName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(o.phone, style: const TextStyle(fontSize: 11, color: Colors.grey)),
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

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 650, maxHeight: 750),
                padding: const EdgeInsets.all(28),
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
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
                                    Text('Name: ${current.customerName}', style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.phone_outlined, size: 16, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Text('Phone: ${current.phone}', style: const TextStyle(fontSize: 13)),
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
                                    Text('Payment: ${current.paymentMethod}', style: const TextStyle(fontSize: 13)),
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
                              title: Text(item.product.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                              subtitle: Text('Qty: ${item.quantity} × ${pkr.format(item.product.price)}'),
                              trailing: Text(
                                pkr.format(item.product.price * item.quantity),
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                              ),
                            ),
                          ),

                          const Divider(height: 24),
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

      return ListView(
        padding: const EdgeInsets.all(24),
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
                  width: 260,
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

                DropdownButton<String?>(
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

          // Products Table
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
                columns: const [
                  DataColumn(label: Text('Item', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Price', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Discount', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Stock Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: filtered.map((p) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
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
    });
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
              content: SizedBox(
                width: 500,
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

    return Obx(() {
      final categories = productCtrl.categories;

      return ListView(
        padding: const EdgeInsets.all(24),
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
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.5,
            ),
            itemCount: categories.length,
            itemBuilder: (_, i) {
              final cat = categories[i];
              final count = productCtrl.products.where((p) => p.categoryId == cat.id).length;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ShopColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.category, color: ShopColors.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          Text('$count items in catalog', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => _openCategoryDialog(context, cat),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
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
  }

  void _openCategoryDialog(BuildContext context, ShopCategory? existing) {
    final productCtrl = Get.find<ProductController>();
    final idCtrl = TextEditingController(text: existing?.id ?? '');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Category' : 'Edit Category'),
        content: Column(
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

    return Obx(() {
      final coupons = couponCtrl.coupons;

      return ListView(
        padding: const EdgeInsets.all(24),
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
                columns: const [
                  DataColumn(label: Text('Coupon Code', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Discount', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Min Spend', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Usage Count', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Valid Until', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Active Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
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
                      DataCell(Text(DateFormat('dd MMM yyyy').format(c.expiryDate))),
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
  }

  void _openAddCouponDialog(BuildContext context) {
    final couponCtrl = Get.find<CouponController>();
    final codeCtrl = TextEditingController();
    final percentCtrl = TextEditingController(text: '20');
    final minSpendCtrl = TextEditingController(text: '1500');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Create Discount Coupon'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(
                labelText: 'Promo Code (e.g. SHOPHUB25, EIDSALE)',
                hintText: 'PROMO2026',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: percentCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Discount Percentage (%)',
                hintText: '20',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: minSpendCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minimum Order Amount (PKR)',
                hintText: '1000',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ShopColors.primary),
            onPressed: () {
              if (codeCtrl.text.trim().isNotEmpty) {
                couponCtrl.addCoupon(
                  code: codeCtrl.text.trim(),
                  discountPercent: int.tryParse(percentCtrl.text) ?? 10,
                  minOrderAmount: double.tryParse(minSpendCtrl.text) ?? 500,
                  expiryDate: DateTime.now().add(const Duration(days: 60)),
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Create Coupon'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 6: 👥 CUSTOMERS & USERS DATA
  // ==========================================
  Widget _buildUsersTab() {
    final authCtrl = Get.find<AuthController>();
    final orderCtrl = Get.find<OrderController>();

    return Obx(() {
      final users = authCtrl.users;

      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Registered Customers & Administrators',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Overview of registered user accounts, order volume, and customer lifetime spending.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 20),

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
                columns: const [
                  DataColumn(label: Text('User / Customer', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Email Address', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Phone Number', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Access Role', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Orders Placed', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Total Spend', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: users.map((u) {
                  final userOrders = orderCtrl.getUserOrders(phone: u.phone, name: u.name);
                  final totalSpent = userOrders.fold<double>(0, (s, o) => s + o.total);

                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
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
                            Text(u.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      DataCell(Text(u.email)),
                      DataCell(Text(u.phone.isNotEmpty ? u.phone : 'Not provided')),
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
  }

  // ==========================================
  // TAB 7: 💳 PAYMENTS & SUBSCRIPTIONS
  // ==========================================
  Widget _buildPaymentsTab() {
    final orderCtrl = Get.find<OrderController>();

    return Obx(() {
      final orders = orderCtrl.orders;
      final stripeOrders = orders.where((o) => o.paymentMethod.toLowerCase().contains('stripe') || o.paymentMethod.toLowerCase().contains('card')).toList();
      final codOrders = orders.where((o) => o.paymentMethod.toLowerCase().contains('delivery') || o.paymentMethod.toLowerCase().contains('cod')).toList();

      final stripeTotal = stripeOrders.fold<double>(0, (s, o) => s + o.total);
      final codTotal = codOrders.fold<double>(0, (s, o) => s + o.total);

      return ListView(
        padding: const EdgeInsets.all(24),
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

          Row(
            children: [
              Expanded(
                child: Container(
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
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Container(
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
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Subscriptions & VIP Club Table
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ShopHub VIP Subscriptions Tiers', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 12),
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
            ),
          ),
        ],
      );
    });
  }

  // ==========================================
  // TAB 8: ⚙️ STORE SETTINGS
  // ==========================================
  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Store Configuration & Super Admin Settings',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(20),
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
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Super Admin Account'),
                subtitle: const Text('ShopHub Admin (admin@shophub.com)'),
                trailing: const Icon(Icons.admin_panel_settings, color: Colors.amber),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
