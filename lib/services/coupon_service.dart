import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/coupon.dart';

/// Coupon Service
/// Handles persistence and retrieval of promo discount codes via Supabase Postgres
/// with local SharedPreferences caching and offline fallback.
class CouponService {
  static const _kCoupons = 'shophub.coupons';

  SharedPreferences? _prefs;

  SupabaseClient get _supabase => Supabase.instance.client;

  bool get hasSupabase {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> init([SharedPreferences? prefs]) async {
    _prefs = prefs ?? await SharedPreferences.getInstance();
  }

  /// Synchronous local load of coupons for instant rendering.
  List<Coupon> loadCoupons() {
    final prefs = _prefs;
    if (prefs == null) return [];

    final raw = prefs.getString(_kCoupons);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List;
        return decoded
            .map((e) => Coupon.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return [];
      }
    }
    return [];
  }

  /// Fetches coupons from Supabase Postgres database and caches locally.
  Future<List<Coupon>> fetchCouponsFromSupabase() async {
    if (!hasSupabase) return loadCoupons();
    try {
      final res = await _supabase
          .from('coupons')
          .select()
          .order('created_at', ascending: false);

      final list = (res as List)
          .map((e) => Coupon.fromJson(e as Map<String, dynamic>))
          .toList();

      if (list.isNotEmpty) {
        await saveCoupons(list);
        return list;
      }
    } catch (e) {
      debugPrint('Supabase coupons fetch error: $e');
    }
    return loadCoupons();
  }

  Future<void> saveCoupons(List<Coupon> coupons) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(
      _kCoupons,
      jsonEncode(coupons.map((c) => c.toJson()).toList()),
    );
  }

  /// Syncs newly created coupon to Supabase Postgres.
  Future<void> syncAddCoupon(Coupon coupon) async {
    if (!hasSupabase) return;
    try {
      await _supabase.from('coupons').upsert(coupon.toSupabaseMap());
    } catch (e) {
      debugPrint('Supabase add coupon error: $e');
    }
  }

  /// Syncs updated coupon (status, discount, etc.) to Supabase Postgres.
  Future<void> syncUpdateCoupon(Coupon coupon) async {
    if (!hasSupabase) return;
    try {
      await _supabase
          .from('coupons')
          .update(coupon.toSupabaseMap())
          .eq('id', coupon.id);
    } catch (e) {
      debugPrint('Supabase update coupon error: $e');
    }
  }

  /// Syncs coupon deletion to Supabase Postgres.
  Future<void> syncDeleteCoupon(String id) async {
    if (!hasSupabase) return;
    try {
      await _supabase.from('coupons').delete().eq('id', id);
    } catch (e) {
      debugPrint('Supabase delete coupon error: $e');
    }
  }

  /// Syncs coupon usage count increment to Supabase Postgres.
  Future<void> syncIncrementUsage(String code) async {
    if (!hasSupabase) return;
    try {
      final res = await _supabase
          .from('coupons')
          .select('usage_count')
          .eq('code', code.trim().toUpperCase())
          .maybeSingle();

      if (res != null) {
        final currentUsage = (res['usage_count'] as num?)?.toInt() ?? 0;
        await _supabase
            .from('coupons')
            .update({'usage_count': currentUsage + 1})
            .eq('code', code.trim().toUpperCase());
      }
    } catch (e) {
      debugPrint('Supabase coupon usage increment error: $e');
    }
  }
}
