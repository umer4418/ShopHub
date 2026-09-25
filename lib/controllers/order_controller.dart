import 'package:get/get.dart';

import '../data/mock_catalog.dart';
import '../models/cart_item.dart';
import '../models/order.dart';
import '../services/order_service.dart';

/// Order Controller
/// Manages checkout processing, order placement, order tracking, and status updates.
class OrderController extends GetxController {
  final OrderService _orderService;

  OrderController({OrderService? orderService})
      : _orderService = orderService ?? OrderService();

  static OrderController get to => Get.find<OrderController>();

  final RxList<ShopOrder> _orders = <ShopOrder>[].obs;
  final RxBool _isInitialized = false.obs;

  List<ShopOrder> get orders => List.unmodifiable(_orders);
  bool get isInitialized => _isInitialized.value;

  void init() {
    final loaded = _orderService.loadOrders();
    if (loaded.isNotEmpty) {
      _orders.assignAll(loaded);
    } else {
      _seedDefaultOrders();
    }
    _isInitialized.value = true;
    update();

    _orderService.fetchOrdersFromSupabase().then((remote) {
      if (remote.isNotEmpty) {
        _orders.assignAll(remote);
        update();
      }
    });
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
  }) {
    return _orders
        .where((o) =>
            (phone.isNotEmpty && o.phone == phone) ||
            (name.isNotEmpty && o.customerName.toLowerCase() == name.toLowerCase()))
        .toList();
  }

  ShopOrder placeOrder({
    String? userId,
    required String name,
    required String phone,
    required String address,
    String paymentMethod = 'Cash on Delivery',
    required List<CartItem> items,
    required double total,
    String? couponCode,
    double? discountAmount,
  }) {
    final id =
        'SH${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final order = ShopOrder(
      id: id,
      userId: userId,
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
    _orderService.saveOrders(_orders);
    _orderService.syncPlaceOrder(order);
    update();
    return order;
  }

  void updateOrderStatus(String id, OrderStatus status) {
    final i = _orders.indexWhere((o) => o.id == id);
    if (i >= 0) {
      _orders[i] = _orders[i].copyWith(status: status);
      _orderService.saveOrders(_orders);
      _orderService.syncUpdateOrderStatus(id, status);
      update();
    }
  }
}
