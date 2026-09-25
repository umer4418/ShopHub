/// Coupon Model
/// Represents a promotional discount code in ShopHub.
class Coupon {
  final String id;
  final String code;
  final int discountPercent;
  final double minOrderAmount;
  final DateTime expiryDate;
  final bool isActive;
  final int usageCount;

  const Coupon({
    required this.id,
    required this.code,
    required this.discountPercent,
    required this.minOrderAmount,
    required this.expiryDate,
    this.isActive = true,
    this.usageCount = 0,
  });

  bool get isExpired => DateTime.now().isAfter(expiryDate);
  bool get isValid => isActive && !isExpired;

  Coupon copyWith({
    String? id,
    String? code,
    int? discountPercent,
    double? minOrderAmount,
    DateTime? expiryDate,
    bool? isActive,
    int? usageCount,
  }) =>
      Coupon(
        id: id ?? this.id,
        code: code ?? this.code,
        discountPercent: discountPercent ?? this.discountPercent,
        minOrderAmount: minOrderAmount ?? this.minOrderAmount,
        expiryDate: expiryDate ?? this.expiryDate,
        isActive: isActive ?? this.isActive,
        usageCount: usageCount ?? this.usageCount,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'discountPercent': discountPercent,
        'discount_percent': discountPercent,
        'minOrderAmount': minOrderAmount,
        'min_order_amount': minOrderAmount,
        'expiryDate': expiryDate.toIso8601String(),
        'expiry_date': expiryDate.toIso8601String(),
        'isActive': isActive,
        'is_active': isActive,
        'usageCount': usageCount,
        'usage_count': usageCount,
      };

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'code': code,
        'discount_percent': discountPercent,
        'min_order_amount': minOrderAmount,
        'expiry_date': expiryDate.toIso8601String(),
        'is_active': isActive,
        'usage_count': usageCount,
      };

  factory Coupon.fromJson(Map<String, dynamic> json) => Coupon(
        id: json['id']?.toString() ?? '',
        code: (json['code'] as String? ?? '').toUpperCase(),
        discountPercent: (json['discountPercent'] ?? json['discount_percent'] as num?)?.toInt() ?? 0,
        minOrderAmount: (json['minOrderAmount'] ?? json['min_order_amount'] as num?)?.toDouble() ?? 0.0,
        expiryDate: DateTime.tryParse((json['expiryDate'] ?? json['expiry_date']) as String? ?? '') ??
            DateTime.now().add(const Duration(days: 30)),
        isActive: (json['isActive'] ?? json['is_active']) as bool? ?? true,
        usageCount: (json['usageCount'] ?? json['usage_count'] as num?)?.toInt() ?? 0,
      );
}
