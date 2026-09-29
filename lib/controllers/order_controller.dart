import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/mock_catalog.dart';
import '../models/cart_item.dart';
import '../models/order.dart';
import '../models/user.dart';
import '../services/order_service.dart';

/// Order Controller
/// Manages checkout processing, order placement, order tracking, and status updates.
class OrderController extends GetxController {
  final OrderService _orderService;

  OrderController({OrderService? orderService})
      : _orderService = orderService ?? OrderService();

  static OrderController get to => Get.find<OrderController>();

  final RxList<ShopOrder> _orders = <ShopOrder>[].obs;
  final RxList<ShopOrder> _userOrders = <ShopOrder>[].obs;
  final RxBool _isInitialized = false.obs;
  final RxBool _isLoadingUserOrders = false.obs;
  RealtimeChannel? _ordersSubscription;

  List<ShopOrder> get orders => List.unmodifiable(_orders);
  List<ShopOrder> get userOrders => List.unmodifiable(_userOrders);
  bool get isInitialized => _isInitialized.value;
  bool get isLoadingUserOrders => _isLoadingUserOrders.value;

  void init() {
    final loaded = _orderService.loadOrders();
    if (loaded.isNotEmpty) {
      _orders.assignAll(loaded);
    } else {
      _seedDefaultOrders();
    }
    _isInitialized.value = true;
    update();

    if (_orderService.hasSupabase) {
      _orderService.fetchOrdersFromSupabase().then((remote) {
        if (remote.isNotEmpty) {
          _orders.assignAll(remote);
          update();
        }
      });
    }
  }

  void _seedDefaultOrders() {
    if (_orders.isNotEmpty) return;
    final now = DateTime.now();
    _orders.assignAll([
      ShopOrder(
        id: 'SH-8821',
        customerName: 'Ayesha Khan',
        phone: '03219876543',
        address: 'House 42, Street 8, F-7/2, Islamabad',
        paymentMethod: 'Stripe (Card)',
        items: [
          CartItem(
            product: MockCatalog.products[0],
            quantity: 1,
          ),
          CartItem(
            product: MockCatalog.products[2],
            quantity: 2,
          ),
        ],
        total: 14999,
        createdAt: now.subtract(const Duration(hours: 3)),
        status: OrderStatus.processing,
      ),
      ShopOrder(
        id: 'SH-8820',
        customerName: 'Bilal Ahmed',
        phone: '03001239876',
        address: 'Apartment 5B, Askari 10, Lahore',
        paymentMethod: 'Cash on Delivery',
        items: [
          CartItem(
            product: MockCatalog.products[1],
            quantity: 1,
          ),
        ],
        total: 8499,
        createdAt: now.subtract(const Duration(hours: 7)),
        status: OrderStatus.placed,
      ),
      ShopOrder(
        id: 'SH-8819',
        customerName: 'Fatima Tariq',
        phone: '03335551234',
        address: 'B-12 Clifton Block 4, Karachi',
        paymentMethod: 'Stripe (Card)',
        items: [
          CartItem(
            product: MockCatalog.products[3],
            quantity: 1,
          ),
        ],
        total: 21500,
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
        status: OrderStatus.shipped,
      ),
      ShopOrder(
        id: 'SH-8818',
        customerName: 'Zain Malik',
        phone: '03124449988',
        address: 'Plot 77, Phase 5 DHA, Lahore',
        paymentMethod: 'Stripe (Card)',
        items: [
          CartItem(
            product: MockCatalog.products[4],
            quantity: 3,
          ),
        ],
        total: 11997,
        createdAt: now.subtract(const Duration(days: 3)),
        status: OrderStatus.delivered,
      ),
      ShopOrder(
        id: 'SH-8817',
        customerName: 'Usman Raza',
        phone: '03451112233',
        address: 'Villa 19, Bahria Town Phase 7, Rawalpindi',
        paymentMethod: 'Cash on Delivery',
        items: [
          CartItem(
            product: MockCatalog.products[5],
            quantity: 1,
          ),
        ],
        total: 5499,
        createdAt: now.subtract(const Duration(days: 5)),
        status: OrderStatus.delivered,
      ),
      ShopOrder(
        id: 'SH-8816',
        customerName: 'Sara Siddiqui',
        phone: '03027778899',
        address: 'Flat 302, Gulshan-e-Iqbal Block 13, Karachi',
        paymentMethod: 'Stripe (Card)',
        items: [
          CartItem(
            product: MockCatalog.products[6],
            quantity: 2,
          ),
        ],
        total: 18400,
        createdAt: now.subtract(const Duration(days: 12)),
        status: OrderStatus.delivered,
      ),
      ShopOrder(
        id: 'SH-8815',
        customerName: 'Hamza Farooq',
        phone: '03223334455',
        address: 'Sector G-11/3, Islamabad',
        paymentMethod: 'Cash on Delivery',
        items: [
          CartItem(
            product: MockCatalog.products[7],
            quantity: 1,
          ),
        ],
        total: 3999,
        createdAt: now.subtract(const Duration(days: 18)),
        status: OrderStatus.delivered,
      ),
    ]);
    _orderService.saveOrders(_orders);
  }

  ShopOrder? getOrderById(String id) {
    try {
      return _orders.firstWhere((o) => o.id == id);
    } catch (_) {
      return null;
    }
  }

  List<ShopOrder> getUserOrders({
    required String phone,
    required String name,
    String? email,
    String? userId,
  }) {
    final lowerName = name.toLowerCase().trim();
    final lowerEmail = email?.toLowerCase().trim();
    return _orders
        .where((o) =>
            (userId != null && o.userId == userId) ||
            (lowerEmail != null && o.customerEmail != null && o.customerEmail!.toLowerCase().trim() == lowerEmail) ||
            (phone.isNotEmpty && o.phone == phone) ||
            (lowerName.isNotEmpty && o.customerName.toLowerCase().trim() == lowerName))
        .toList();
  }

  /// Returns orders that belong strictly to [user].
  /// Super admins can view all orders. Customers can only view their own orders.
  List<ShopOrder> getOrdersForUser(ShopUser? user) {
    if (user == null) return const [];
    if (user.isAdmin) return List.unmodifiable(_orders);

    final email = user.email.toLowerCase().trim();
    final id = user.id;

    return _orders.where((o) {
      if (id != null && o.userId != null) {
        return o.userId == id;
      }
      if (id != null && o.userId == id) return true;
      if (o.customerEmail != null && o.customerEmail!.toLowerCase().trim() == email) return true;
      return false;
    }).toList();
  }

  /// Fetches latest user orders from Supabase Postgres.
  Future<void> refreshOrders([String? userId]) async {
    final effectiveUserId = userId ?? () {
      try {
        return Supabase.instance.client.auth.currentUser?.id;
      } catch (_) {
        return null;
      }
    }();

    if (effectiveUserId != null && effectiveUserId.isNotEmpty) {
      _isLoadingUserOrders.value = true;
      update();
      try {
        final remote = await _orderService.fetchOrdersForUser(effectiveUserId);
        _userOrders.assignAll(remote);
        // Merge into _orders for consistency with admin/global views
        for (final o in remote) {
          final idx = _orders.indexWhere((existing) => existing.id == o.id);
          if (idx >= 0) {
            _orders[idx] = o;
          } else {
            _orders.insert(0, o);
          }
        }
        await _orderService.saveOrders(_orders);
      } finally {
        _isLoadingUserOrders.value = false;
        update();
      }
    } else {
      final remote = await _orderService.fetchOrdersFromSupabase();
      if (remote.isNotEmpty) {
        _orders.assignAll(remote);
        await _orderService.saveOrders(_orders);
        update();
      }
    }
  }

  /// Listens to real-time changes on Supabase orders table for the current user.
  void subscribeToOrders(String? userId) {
    if (!_orderService.hasSupabase) return;
    try {
      _ordersSubscription?.unsubscribe();
      final client = Supabase.instance.client;
      _ordersSubscription = client
          .channel('public:orders_${userId ?? 'all'}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            callback: (payload) {
              refreshOrders(userId);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Realtime orders subscription error: $e');
    }
  }

  void unsubscribeFromOrders() {
    try {
      _ordersSubscription?.unsubscribe();
      _ordersSubscription = null;
    } catch (_) {}
  }

  /// Called when authentication session changes (login, logout, switch).
  void onUserChanged(String? newUserId) {
    if (newUserId != null && newUserId.isNotEmpty) {
      subscribeToOrders(newUserId);
      refreshOrders(newUserId);
    } else {
      unsubscribeFromOrders();
      _userOrders.clear();
      update();
    }
  }

  /// Returns the orders belonging strictly to the authenticated user.
  /// Does NOT leak any other user's orders.
  List<ShopOrder> getOrdersForAuthenticatedUser({String? userId, ShopUser? user}) {
    final effectiveId = userId ?? user?.id ?? () {
      try {
        return Supabase.instance.client.auth.currentUser?.id;
      } catch (_) {
        return null;
      }
    }();
    final effectiveEmail = user?.email.toLowerCase().trim();

    if (effectiveId == null && effectiveEmail == null) return const [];

    final Map<String, ShopOrder> orderMap = {};
    for (final o in _userOrders) {
      if ((effectiveId != null && o.userId == effectiveId) ||
          (effectiveEmail != null && o.customerEmail?.toLowerCase().trim() == effectiveEmail)) {
        orderMap[o.id] = o;
      }
    }
    for (final o in _orders) {
      if (effectiveId != null && o.userId != null) {
        if (o.userId == effectiveId) {
          orderMap.putIfAbsent(o.id, () => o);
        }
      } else if (effectiveEmail != null &&
          o.customerEmail != null &&
          o.customerEmail!.toLowerCase().trim() == effectiveEmail) {
        orderMap.putIfAbsent(o.id, () => o);
      }
    }

    final list = orderMap.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  ShopOrder placeOrder({
    String? userId,
    String? customerEmail,
    required String name,
    required String phone,
    required String address,
    String paymentMethod = 'Cash on Delivery',
    required List<CartItem> items,
    required double total,
    String? couponCode,
    double? discountAmount,
  }) {
    final effectiveUserId = userId ?? () {
      try {
        return Supabase.instance.client.auth.currentUser?.id;
      } catch (_) {
        return null;
      }
    }();

    final id =
        'SH${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final order = ShopOrder(
      id: id,
      userId: effectiveUserId,
      customerEmail: customerEmail,
      customerName: name,
      phone: phone,
      address: address,
      paymentMethod: paymentMethod,
      items: List.of(items),
      total: total,
      createdAt: DateTime.now(),
      status: OrderStatus.placed,
      couponCode: couponCode,
      discountAmount: discountAmount,
    );

    _orders.insert(0, order);
    if (effectiveUserId != null) {
      _userOrders.insert(0, order);
    }
    _orderService.saveOrders(_orders);
    _orderService.syncPlaceOrder(order);
    update();
    return order;
  }

  void updateOrderStatus(String id, OrderStatus status) {
    final i = _orders.indexWhere((o) => o.id == id);
    if (i >= 0) {
      _orders[i] = _orders[i].copyWith(status: status);
    }
    final userIdx = _userOrders.indexWhere((o) => o.id == id);
    if (userIdx >= 0) {
      _userOrders[userIdx] = _userOrders[userIdx].copyWith(status: status);
    }
    _orderService.saveOrders(_orders);
    _orderService.syncUpdateOrderStatus(id, status);
    update();
  }

  /// Customer marks a delivered order as completed.
  /// 1. Verifies order exists and has status `delivered`.
  /// 2. Verifies order belongs to the currently logged in user.
  /// 3. Updates the order status to `completed` in Supabase & local state.
  /// 4. Immediately notifies listeners.
  Future<bool> markOrderAsCompleted(String orderId, {String? userId}) async {
    final effectiveUserId = userId ?? () {
      try {
        return Supabase.instance.client.auth.currentUser?.id;
      } catch (_) {
        return null;
      }
    }();

    final orderIdx = _orders.indexWhere((o) => o.id == orderId);
    if (orderIdx < 0) return false;
    final order = _orders[orderIdx];

    // Customer can ONLY transition from delivered -> completed
    if (order.status != OrderStatus.delivered) return false;

    // Verify order belongs to the currently logged-in user
    if (effectiveUserId != null &&
        order.userId != null &&
        order.userId != effectiveUserId) {
      return false;
    }

    // Update in memory and notify immediately
    _orders[orderIdx] = order.copyWith(status: OrderStatus.completed);
    final userIdx = _userOrders.indexWhere((o) => o.id == orderId);
    if (userIdx >= 0) {
      _userOrders[userIdx] = _userOrders[userIdx].copyWith(status: OrderStatus.completed);
    }
    _orderService.saveOrders(_orders);
    update();

    // Sync to Supabase
    if (effectiveUserId != null) {
      await _orderService.syncMarkOrderCompleted(orderId, effectiveUserId);
    } else {
      await _orderService.syncUpdateOrderStatus(orderId, OrderStatus.completed);
    }

    return true;
  }

  /// Test helper to supply mock orders in tests.
  void setOrdersForTesting(List<ShopOrder> orders, [String? userId]) {
    _orders.assignAll(orders);
    if (userId != null) {
      _userOrders.assignAll(orders.where((o) => o.userId == userId));
    } else {
      _userOrders.assignAll(orders);
    }
    _orderService.setOrdersForTesting(orders);
    update();
  }
}
