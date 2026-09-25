import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/coupon.dart';
import '../services/coupon_service.dart';

/// Coupon Controller
/// Manages promotional discount codes, coupon creation, activation, validation,
/// and bidirectional synchronization with Supabase Postgres.
class CouponController extends GetxController {
  final CouponService _couponService;

  CouponController({CouponService? couponService})
      : _couponService = couponService ?? CouponService();

  static CouponController get to => Get.find<CouponController>();

  final RxList<Coupon> _coupons = <Coupon>[].obs;
  final RxBool _isInitialized = false.obs;

  List<Coupon> get coupons => List.unmodifiable(_coupons);
  bool get isInitialized => _isInitialized.value;
  int get activeCouponsCount => _coupons.where((c) => c.isValid).length;

  void init([SharedPreferences? prefs]) {
    _couponService.init(prefs).then((_) {
      _loadCoupons();
      _isInitialized.value = true;
      update();

      // Fetch from Supabase Postgres if available
      _couponService.fetchCouponsFromSupabase().then((remote) {
        if (remote.isNotEmpty) {
          _coupons.assignAll(remote);
          update();
        }
      });
    });

    // Synchronous immediate load for fast UI rendering
    final loaded = _couponService.loadCoupons();
    if (loaded.isNotEmpty) {
      _coupons.assignAll(loaded);
    } else {
      _loadPresets();
    }
    _isInitialized.value = true;
    update();
  }

  void _loadCoupons() {
    final loaded = _couponService.loadCoupons();
    if (loaded.isNotEmpty) {
      _coupons.assignAll(loaded);
    } else {
      _loadPresets();
    }
  }

  void _loadPresets() {
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
      Coupon(
        id: 'cp_5',
        code: 'CUPON15',
        discountPercent: 30,
        minOrderAmount: 500,
        expiryDate: DateTime.now().add(const Duration(days: 90)),
        isActive: true,
        usageCount: 23,
      ),
    ]);
    _couponService.saveCoupons(_coupons);
    for (final c in _coupons) {
      _couponService.syncAddCoupon(c);
    }
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
    _couponService.saveCoupons(_coupons);
    _couponService.syncAddCoupon(newCoupon);
    update();
  }

  void toggleCouponStatus(String id) {
    final index = _coupons.indexWhere((c) => c.id == id);
    if (index >= 0) {
      final current = _coupons[index];
      final updated = current.copyWith(isActive: !current.isActive);
      _coupons[index] = updated;
      _couponService.saveCoupons(_coupons);
      _couponService.syncUpdateCoupon(updated);
      update();
    }
  }

  void deleteCoupon(String id) {
    _coupons.removeWhere((c) => c.id == id);
    _couponService.saveCoupons(_coupons);
    _couponService.syncDeleteCoupon(id);
    update();
  }

  void incrementUsageCount(String code) {
    final cleanCode = code.trim().toUpperCase();
    final index = _coupons.indexWhere((c) => c.code == cleanCode);
    if (index >= 0) {
      final current = _coupons[index];
      final updated = current.copyWith(usageCount: current.usageCount + 1);
      _coupons[index] = updated;
      _couponService.saveCoupons(_coupons);
      _couponService.syncIncrementUsage(cleanCode);
      update();
    }
  }

  Coupon? findCoupon(String code) {
    final cleanCode = code.trim().toUpperCase();
    return _coupons.firstWhereOrNull((c) => c.code == cleanCode);
  }

  /// Validates [code] against [orderTotal].
  /// Returns discount amount in PKR if valid, or null if invalid.
  double? calculateDiscount(String code, double orderTotal) {
    final cleanCode = code.trim().toUpperCase();
    final match = findCoupon(cleanCode);
    if (match == null || !match.isValid) return null;
    if (orderTotal < match.minOrderAmount) return null;
    return (orderTotal * match.discountPercent) / 100.0;
  }
}
