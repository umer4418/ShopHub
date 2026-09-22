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
  final String? userId;
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
    this.userId,
    required this.customerName,
    required this.phone,
    required this.address,
    required this.paymentMethod,
    required this.items,
    required this.total,
    required this.createdAt,
    required this.status,
  });

  ShopOrder copyWith({
    String? id,
    String? userId,
    String? customerName,
    String? phone,
    String? address,
    String? paymentMethod,
    List<CartItem>? items,
    double? total,
    DateTime? createdAt,
    OrderStatus? status,
  }) =>
      ShopOrder(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        customerName: customerName ?? this.customerName,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        items: items ?? this.items,
        total: total ?? this.total,
        createdAt: createdAt ?? this.createdAt,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        if (userId != null) 'userId': userId,
        if (userId != null) 'user_id': userId,
        'customerName': customerName,
        'customer_name': customerName,
        'phone': phone,
        'address': address,
        'paymentMethod': paymentMethod,
        'payment_method': paymentMethod,
        'items': items.map((e) => e.toJson()).toList(),
        'total': total,
        'createdAt': createdAt.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'status': status.name,
      };

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        if (userId != null) 'user_id': userId,
        'customer_name': customerName,
        'phone': phone,
        'address': address,
        'payment_method': paymentMethod,
        'items': items.map((e) => e.toJson()).toList(),
        'total': total,
        'created_at': createdAt.toIso8601String(),
        'status': status.name,
      };

  factory ShopOrder.fromJson(Map<String, dynamic> json) => ShopOrder(
        id: json['id'] as String,
        userId: (json['userId'] ?? json['user_id']) as String?,
        customerName: (json['customerName'] ?? json['customer_name'] ?? '') as String,
        phone: (json['phone'] as String?) ?? '',
        address: (json['address'] as String?) ?? '',
        paymentMethod: (json['paymentMethod'] ?? json['payment_method'] ?? 'Cash on Delivery') as String,
        items: ((json['items'] as List?) ?? [])
            .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: (json['total'] as num?)?.toDouble() ?? 0.0,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : (json['createdAt'] != null
                ? DateTime.parse(json['createdAt'] as String)
                : DateTime.now()),
        status: OrderStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => OrderStatus.placed,
        ),
      );
}
