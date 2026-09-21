import 'cart_item.dart';

enum OrderStatus { placed, processing, shipped, delivered }

extension OrderStatusLabel on OrderStatus {
  String get label => switch (this) {
        OrderStatus.placed => 'Order Placed',
        OrderStatus.processing => 'Processing',
        OrderStatus.shipped => 'Shipped',
        OrderStatus.delivered => 'Delivered',
      };

  int get step => index;
}

class ShopOrder {
  final String id;
  final String customerName;
  final String phone;
  final String address;
  final String paymentMethod;
  final List<CartItem> items;
  final double total;
  final DateTime createdAt;
  final OrderStatus status;

  const ShopOrder({
    required this.id,
    required this.customerName,
    required this.phone,
    required this.address,
    required this.paymentMethod,
    required this.items,
    required this.total,
    required this.createdAt,
    required this.status,
  });

  ShopOrder copyWith({OrderStatus? status}) => ShopOrder(
        id: id,
        customerName: customerName,
        phone: phone,
        address: address,
        paymentMethod: paymentMethod,
        items: items,
        total: total,
        createdAt: createdAt,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'customerName': customerName,
        'phone': phone,
        'address': address,
        'paymentMethod': paymentMethod,
        'items': items.map((e) => e.toJson()).toList(),
        'total': total,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
      };

  factory ShopOrder.fromJson(Map<String, dynamic> json) => ShopOrder(
        id: json['id'] as String,
        customerName: json['customerName'] as String,
        phone: json['phone'] as String,
        address: json['address'] as String,
        paymentMethod: json['paymentMethod'] as String,
        items: (json['items'] as List)
            .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: (json['total'] as num).toDouble(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        status: OrderStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => OrderStatus.placed,
        ),
      );
}
