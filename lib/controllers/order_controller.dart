import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/order.dart';
import '../services/order_service.dart';

/// Order Controller
/// Manages checkout processing, order placement, order tracking, and status updates.
class OrderController extends ChangeNotifier {
  final OrderService _orderService;

  OrderController({OrderService? orderService})
      : _orderService = orderService ?? OrderService();

  List<ShopOrder> _orders = [];
  bool _isInitialized = false;

  List<ShopOrder> get orders => List.unmodifiable(_orders);
  bool get isInitialized => _isInitialized;

  void init() {
    _orders = _orderService.loadOrders();
    _isInitialized = true;
    notifyListeners();
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
    required String name,
    required String phone,
    required String address,
    String paymentMethod = 'Cash on Delivery',
    required List<CartItem> items,
    required double total,
  }) {
    final id =
        'SH${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final order = ShopOrder(
      id: id,
      customerName: name,
      phone: phone,
      address: address,
      paymentMethod: paymentMethod,
      items: List.of(items),
      total: total,
      createdAt: DateTime.now(),
      status: OrderStatus.placed,
    );

    _orders.insert(0, order);
    _orderService.saveOrders(_orders);
    notifyListeners();
    return order;
  }

  void updateOrderStatus(String id, OrderStatus status) {
    final i = _orders.indexWhere((o) => o.id == id);
    if (i >= 0) {
      _orders[i] = _orders[i].copyWith(status: status);
      _orderService.saveOrders(_orders);
      notifyListeners();
    }
  }
}
