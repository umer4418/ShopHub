import 'package:get/get.dart';

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
    _orders.assignAll(_orderService.loadOrders());
    _isInitialized.value = true;
    update();

    _orderService.fetchOrdersFromSupabase().then((remote) {
      if (remote.isNotEmpty) {
        _orders.assignAll(remote);
        update();
      }
    });
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
