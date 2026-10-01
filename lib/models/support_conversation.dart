class SupportConversation {
  final String id;
  final String customerId;
  final String? customerName;
  final String? customerEmail;
  final String? orderId;
  final String? orderStatus;
  final String? subject;
  final String status; // 'open' or 'closed'
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? closedAt;
  final String? lastMessage;
  final int unreadCount;

  const SupportConversation({
    required this.id,
    required this.customerId,
    this.customerName,
    this.customerEmail,
    this.orderId,
    this.orderStatus,
    this.subject,
    this.status = 'open',
    required this.createdAt,
    required this.updatedAt,
    this.closedAt,
    this.lastMessage,
    this.unreadCount = 0,
  });

  bool get isOpen => status.toLowerCase() == 'open';
  bool get isClosed => status.toLowerCase() == 'closed';
  bool get hasOrder => orderId != null && orderId!.isNotEmpty;

  SupportConversation copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? customerEmail,
    String? orderId,
    String? orderStatus,
    String? subject,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? closedAt,
    bool clearClosedAt = false,
    String? lastMessage,
    int? unreadCount,
  }) {
    return SupportConversation(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerEmail: customerEmail ?? this.customerEmail,
      orderId: orderId ?? this.orderId,
      orderStatus: orderStatus ?? this.orderStatus,
      subject: subject ?? this.subject,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      closedAt: clearClosedAt ? null : (closedAt ?? this.closedAt),
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'customer_id': customerId,
        if (customerName != null) 'customer_name': customerName,
        if (customerEmail != null) 'customer_email': customerEmail,
        if (orderId != null) 'order_id': orderId,
        if (orderStatus != null) 'order_status': orderStatus,
        if (subject != null) 'subject': subject,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        if (closedAt != null) 'closed_at': closedAt!.toIso8601String(),
        if (lastMessage != null) 'last_message': lastMessage,
        'unread_count': unreadCount,
      };

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'customer_id': customerId,
        if (customerName != null) 'customer_name': customerName,
        if (customerEmail != null) 'customer_email': customerEmail,
        if (orderId != null) 'order_id': orderId,
        if (subject != null) 'subject': subject,
        'status': status,
        if (lastMessage != null) 'last_message': lastMessage,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        if (closedAt != null) 'closed_at': closedAt!.toIso8601String(),
      };

  factory SupportConversation.fromJson(Map<String, dynamic> json) {
    return SupportConversation(
      id: json['id'] as String? ?? '',
      customerId: (json['customer_id'] ?? json['customerId']) as String? ?? '',
      customerName: (json['customer_name'] ?? json['customerName']) as String?,
      customerEmail: (json['customer_email'] ?? json['customerEmail']) as String?,
      orderId: (json['order_id'] ?? json['orderId']) as String?,
      orderStatus: (json['order_status'] ?? json['orderStatus']) as String?,
      subject: (json['subject']) as String?,
      status: (json['status'] as String?) ?? 'open',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : (json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
              : DateTime.now()),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
          : (json['updated_at'] != null
              ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
              : DateTime.now()),
      closedAt: json['closed_at'] != null
          ? DateTime.tryParse(json['closed_at'] as String)
          : (json['closedAt'] != null
              ? DateTime.tryParse(json['closedAt'] as String)
              : null),
      lastMessage: (json['last_message'] ?? json['lastMessage']) as String?,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
    );
  }
}
