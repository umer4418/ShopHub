import 'cart_item.dart';

enum OrderStatus { placed, processing, shipped, delivered, completed }

extension OrderStatusLabel on OrderStatus {
  String get label => switch (this) {
        OrderStatus.placed => 'Order Placed',
        OrderStatus.processing => 'Processing',
        OrderStatus.shipped => 'Shipped',
        OrderStatus.delivered => 'Delivered',
        OrderStatus.completed => 'Completed',
      };

  int get step => index;
}

class ShopOrder {
  final String id;
  final String? userId;
  final String? customerEmail;
  final String customerName;
  final String phone;
  final String address;
  final String paymentMethod;
  final List<CartItem> items;
  final double total;
  final DateTime createdAt;
  final OrderStatus status;
  final String? couponCode;
  final double? discountAmount;
  final String? stripePaymentId;
  final String? paymentStatus;
  final double? deliveryFee;

  const ShopOrder({
    required this.id,
    this.userId,
    this.customerEmail,
    required this.customerName,
    required this.phone,
    required this.address,
    required this.paymentMethod,
    required this.items,
    required this.total,
    required this.createdAt,
    required this.status,
    this.couponCode,
    this.discountAmount,
    this.stripePaymentId,
    this.paymentStatus,
    this.deliveryFee,
  });

  bool get isStripePayment => paymentMethod.toLowerCase().contains('stripe');

  bool get isPaid {
    final status = paymentStatus?.toLowerCase().trim();
    if (status == 'paid') return true;
    if (status == 'pending' ||
        status == 'failed' ||
        status == 'cancelled' ||
        status == 'unpaid') {
      return false;
    }
    return isStripePayment &&
        stripePaymentId != null &&
        stripePaymentId!.isNotEmpty;
  }

  bool get canGenerateReceipt => isStripePayment && isPaid;

  ShopOrder copyWith({
    String? id,
    String? userId,
    String? customerEmail,
    String? customerName,
    String? phone,
    String? address,
    String? paymentMethod,
    List<CartItem>? items,
    double? total,
    DateTime? createdAt,
    OrderStatus? status,
    String? couponCode,
    double? discountAmount,
    String? stripePaymentId,
    String? paymentStatus,
    double? deliveryFee,
  }) =>
      ShopOrder(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        customerEmail: customerEmail ?? this.customerEmail,
        customerName: customerName ?? this.customerName,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        items: items ?? this.items,
        total: total ?? this.total,
        createdAt: createdAt ?? this.createdAt,
        status: status ?? this.status,
        couponCode: couponCode ?? this.couponCode,
        discountAmount: discountAmount ?? this.discountAmount,
        stripePaymentId: stripePaymentId ?? this.stripePaymentId,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        deliveryFee: deliveryFee ?? this.deliveryFee,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        if (userId != null) 'userId': userId,
        if (userId != null) 'user_id': userId,
        if (customerEmail != null) 'customerEmail': customerEmail,
        if (customerEmail != null) 'customer_email': customerEmail,
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
        if (couponCode != null) 'couponCode': couponCode,
        if (couponCode != null) 'coupon_code': couponCode,
        if (discountAmount != null) 'discountAmount': discountAmount,
        if (discountAmount != null) 'discount_amount': discountAmount,
        if (stripePaymentId != null) 'stripePaymentId': stripePaymentId,
        if (stripePaymentId != null) 'stripe_payment_id': stripePaymentId,
        if (paymentStatus != null) 'paymentStatus': paymentStatus,
        if (paymentStatus != null) 'payment_status': paymentStatus,
        if (deliveryFee != null) 'deliveryFee': deliveryFee,
        if (deliveryFee != null) 'delivery_fee': deliveryFee,
      };

  Map<String, dynamic> toSupabaseMap() {
    final bool validUuid = userId != null &&
        RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
            .hasMatch(userId!);

    final rawItems = items.map((e) => e.toJson()).toList();
    // Embed extra metadata seamlessly within the JSONB items payload
    // so Supabase Postgres preserves email, stripe ID, delivery fee, and payment status
    // without requiring DDL alterations on the public.orders table.
    final bool hasExtraMeta = (customerEmail != null && customerEmail!.isNotEmpty) ||
        (stripePaymentId != null && stripePaymentId!.isNotEmpty) ||
        (paymentStatus != null && paymentStatus!.isNotEmpty) ||
        (deliveryFee != null && deliveryFee! > 0);

    if (hasExtraMeta) {
      rawItems.add({
        '__order_meta__': true,
        if (customerEmail != null && customerEmail!.isNotEmpty) 'customer_email': customerEmail,
        if (stripePaymentId != null && stripePaymentId!.isNotEmpty) 'stripe_payment_id': stripePaymentId,
        if (paymentStatus != null && paymentStatus!.isNotEmpty) 'payment_status': paymentStatus,
        if (deliveryFee != null) 'delivery_fee': deliveryFee,
      });
    }

    return {
      'id': id,
      if (validUuid) 'user_id': userId,
      'customer_name': customerName,
      'phone': phone,
      'address': address,
      'payment_method': paymentMethod,
      'items': rawItems,
      'total': total,
      'created_at': createdAt.toIso8601String(),
      'status': status.name,
      if (couponCode != null) 'coupon_code': couponCode,
      if (discountAmount != null) 'discount_amount': discountAmount,
    };
  }

  factory ShopOrder.fromJson(Map<String, dynamic> json) {
    final rawList = (json['items'] as List?) ?? [];
    Map<String, dynamic>? meta;
    final List<CartItem> parsedItems = [];

    for (final item in rawList) {
      if (item is Map) {
        final itemMap = Map<String, dynamic>.from(item);
        if (itemMap['__order_meta__'] == true) {
          meta = itemMap;
          continue;
        }
        parsedItems.add(CartItem.fromJson(itemMap));
      }
    }

    final rawEmail = json['customerEmail'] ?? json['customer_email'] ?? meta?['customer_email'];
    final rawStripeId = json['stripePaymentId'] ?? json['stripe_payment_id'] ?? meta?['stripe_payment_id'];
    final rawPaymentStatus = json['paymentStatus'] ?? json['payment_status'] ?? meta?['payment_status'];
    final rawDeliveryFee = json['deliveryFee'] ?? json['delivery_fee'] ?? meta?['delivery_fee'];

    return ShopOrder(
      id: json['id'] as String,
      userId: (json['userId'] ?? json['user_id']) as String?,
      customerEmail: rawEmail as String?,
      customerName: (json['customerName'] ?? json['customer_name'] ?? '') as String,
      phone: (json['phone'] as String?) ?? '',
      address: (json['address'] as String?) ?? '',
      paymentMethod: (json['paymentMethod'] ?? json['payment_method'] ?? 'Cash on Delivery') as String,
      items: parsedItems,
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
      couponCode: (json['couponCode'] ?? json['coupon_code']) as String?,
      discountAmount: ((json['discountAmount'] ?? json['discount_amount']) as num?)?.toDouble(),
      stripePaymentId: rawStripeId as String?,
      paymentStatus: rawPaymentStatus as String?,
      deliveryFee: (rawDeliveryFee as num?)?.toDouble(),
    );
  }
}
