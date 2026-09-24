import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/coupon.dart';

/// Coupon Controller
/// Manages promotional discount codes, coupon creation, activation, and validation.
class CouponController extends GetxController {
  static const _kCouponsKey = 'shophub.coupons';
  SharedPreferences? _prefs;

  static CouponController get to => Get.find<CouponController>();

  final RxList<Coupon> _coupons = <Coupon>[].obs;
  final RxBool _isInitialized = false.obs;

  List<Coupon> get coupons => List.unmodifiable(_coupons);
  bool get isInitialized => _isInitialized.value;
  int get activeCouponsCount => _coupons.where((c) => c.isValid).length;

  void init([SharedPreferences? prefs]) {
    _prefs = prefs;
    _loadCoupons();
    _isInitialized.value = true;
    update();
    if (prefs == null) {
      SharedPreferences.getInstance().then((p) {
        _prefs = p;
        _loadCoupons();
      });
    }
  }

  void _loadCoupons() {
    final raw = _prefs?.getString(_kCouponsKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List;
        _coupons.assignAll(
          decoded.map((e) => Coupon.fromJson(e as Map<String, dynamic>)),
        );
        return;
      } catch (_) {}
    }

    // Default presets if no coupons exist yet
    _coupons.assignAll([
      Coupon(
        id: 'cp_1',
        code: 'SHOPHUB20',
        discountPercent: 20,
        minOrderAmount: 1500,
        expiryDate: DateTime.now().add(const Duration(days: 60)),
        isActive: true,
        usageCount: 42,
      ),
      Coupon(
        id: 'cp_2',
        code: 'WELCOME10',
        discountPercent: 10,
        minOrderAmount: 500,
        expiryDate: DateTime.now().add(const Duration(days: 90)),
        isActive: true,
        usageCount: 118,
      ),
      Coupon(
        id: 'cp_3',
        code: 'SUPERADMIN50',
        discountPercent: 50,
        minOrderAmount: 2500,
        expiryDate: DateTime.now().add(const Duration(days: 120)),
        isActive: true,
        usageCount: 15,
      ),
      Coupon(
        id: 'cp_4',
        code: 'EIDMEGA',
        discountPercent: 30,
        minOrderAmount: 4000,
        expiryDate: DateTime.now().add(const Duration(days: 45)),
        isActive: true,
        usageCount: 67,
      ),
    ]);
    _saveCoupons();
  }

  Future<void> _saveCoupons() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(
      _kCouponsKey,
      jsonEncode(_coupons.map((c) => c.toJson()).toList()),
    );
  }

  void addCoupon({
    required String code,
    required int discountPercent,
    required double minOrderAmount,
    required DateTime expiryDate,
    bool isActive = true,
  }) {
    final newCoupon = Coupon(
      id: 'cp_${DateTime.now().millisecondsSinceEpoch}',
      code: code.trim().toUpperCase(),
      discountPercent: discountPercent,
      minOrderAmount: minOrderAmount,
      expiryDate: expiryDate,
      isActive: isActive,
      usageCount: 0,
    );
    _coupons.insert(0, newCoupon);
    _saveCoupons();
    update();
  }

  void toggleCouponStatus(String id) {
    final index = _coupons.indexWhere((c) => c.id == id);
    if (index >= 0) {
      final current = _coupons[index];
      _coupons[index] = current.copyWith(isActive: !current.isActive);
      _saveCoupons();
      update();
    }
  }

  void deleteCoupon(String id) {
    _coupons.removeWhere((c) => c.id == id);
    _saveCoupons();
    update();
  }

  /// Validates [code] against [orderTotal].
  /// Returns discount amount in PKR if valid, or null if invalid.
  double? calculateDiscount(String code, double orderTotal) {
    final cleanCode = code.trim().toUpperCase();
    final match = _coupons.firstWhereOrNull((c) => c.code == cleanCode);
    if (match == null || !match.isValid) return null;
    if (orderTotal < match.minOrderAmount) return null;
    return (orderTotal * match.discountPercent) / 100.0;
  }
}
