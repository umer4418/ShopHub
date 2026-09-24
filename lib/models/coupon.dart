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
        'minOrderAmount': minOrderAmount,
        'expiryDate': expiryDate.toIso8601String(),
        'isActive': isActive,
        'usageCount': usageCount,
      };

  factory Coupon.fromJson(Map<String, dynamic> json) => Coupon(
        id: json['id'] as String,
        code: (json['code'] as String).toUpperCase(),
        discountPercent: (json['discountPercent'] as num).toInt(),
        minOrderAmount: (json['minOrderAmount'] as num?)?.toDouble() ?? 0.0,
        expiryDate: DateTime.tryParse(json['expiryDate'] as String? ?? '') ??
            DateTime.now().add(const Duration(days: 30)),
        isActive: json['isActive'] as bool? ?? true,
        usageCount: (json['usageCount'] as num?)?.toInt() ?? 0,
      );
}
