import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/mock_catalog.dart';
import '../models/user.dart';

/// Auth Service
/// Handles Supabase Authentication, Postgres profile storage,
/// and local session caching with offline fallback.
class AuthService {
  static const _kUsers = 'shophub.users';
  static const _kSession = 'shophub.session';

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

  /// Sign up with email & password via Supabase and save profile in Postgres.
  Future<ShopUser> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    required String phone,
    required bool isAdmin,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final role = isAdmin ? 'admin' : 'customer';

    try {
      final res = await _supabase.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {
          'name': name.trim(),
          'phone': phone.trim(),
          'is_admin': isAdmin,
          'role': role,
        },
      );

      final uid = res.user?.id;
      final user = ShopUser(
        id: uid,
        name: name.trim(),
        email: cleanEmail,
        password: password,
        phone: phone.trim(),
        isAdmin: isAdmin,
        role: role,
      );

      if (uid != null) {
        try {
          await _supabase.from('profiles').upsert({
            'id': uid,
            'name': name.trim(),
            'email': cleanEmail,
            'phone': phone.trim(),
            'is_admin': isAdmin,
            'role': role,
          });
        } catch (e) {
          debugPrint('Error creating profile in Postgres: $e');
        }
      }

      await saveSession(cleanEmail);
      return user;
    } on AuthException catch (e) {
      debugPrint('Supabase AuthException on signUp: ${e.message} (status: ${e.statusCode})');
      if (e.message.toLowerCase().contains('failed to fetch')) {
        throw 'Network error: Unable to connect to Supabase server. Please verify your internet connection.';
      }
      if (e.message.toLowerCase().contains('user already registered')) {
        throw 'An account with this email address already exists. Please log in instead.';
      }
      throw e.message;
    } catch (e) {
      debugPrint('General error on signUp: $e');
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup') ||
          e.toString().contains('Permission denied')) {
        throw 'Network error: Cannot reach authentication server. Please check your internet connection.';
      }
      // Local fallback for offline/test environments
      final user = ShopUser(
        name: name.trim(),
        email: cleanEmail,
        password: password,
        phone: phone.trim(),
        isAdmin: isAdmin,
        role: role,
      );
      await saveSession(cleanEmail);
      return user;
    }
  }

  /// Sign in with email & password via Supabase Auth and load profile from Postgres.
  Future<ShopUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    try {
      final res = await _supabase.auth.signInWithPassword(
        email: cleanEmail,
        password: password,
      );

      final authUser = res.user;
      if (authUser == null) {
        throw 'Failed to retrieve authenticated user';
      }

      ShopUser? profileUser;
      try {
        final profile = await _supabase
            .from('profiles')
            .select()
            .eq('id', authUser.id)
            .maybeSingle();

        if (profile != null) {
          profileUser = ShopUser.fromJson(profile);
        }
      } catch (e) {
        debugPrint('Postgres profile fetch error: $e');
      }

      if (profileUser == null) {
        final meta = authUser.userMetadata;
        final isAdmin = (meta?['is_admin'] == true) || (meta?['role'] == 'admin');
        profileUser = ShopUser(
          id: authUser.id,
          name: (meta?['name'] as String?) ?? cleanEmail.split('@').first,
          email: cleanEmail,
          phone: (meta?['phone'] as String?) ?? '',
          isAdmin: isAdmin,
          role: (meta?['role'] as String?) ?? (isAdmin ? 'admin' : 'customer'),
        );
      }

      await saveSession(cleanEmail);
      return profileUser;
    } on AuthException catch (e) {
      debugPrint('Supabase AuthException on signIn: ${e.message} (status: ${e.statusCode})');
      if (e.message.toLowerCase().contains('failed to fetch')) {
        throw 'Network error: Unable to connect to Supabase server. Please verify your internet connection.';
      }
      if (e.message.toLowerCase().contains('email not confirmed')) {
        throw 'Email is not confirmed. Please disable "Confirm email" in Supabase Dashboard (Authentication -> Providers -> Email).';
      }
      if (e.message.toLowerCase().contains('invalid login credentials')) {
        throw 'Invalid email or password. Please verify your credentials and try again.';
      }
      throw e.message;
    } catch (e) {
      debugPrint('General error on signIn: $e');
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup') ||
          e.toString().contains('Permission denied')) {
        throw 'Network error: Cannot reach authentication server. Please check your internet connection.';
      }
      // Check local cache/mock users
      final localUsers = loadUsers();
      final match = localUsers.cast<ShopUser?>().firstWhere(
            (u) =>
                u != null &&
                u.email.toLowerCase() == cleanEmail &&
                u.password == password,
            orElse: () => null,
          );
      if (match != null) {
        await saveSession(match.email);
        return match;
      }
      throw e.toString();
    }
  }

  /// Sign in with Google OAuth via Supabase.
  Future<void> signInWithGoogle() async {
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : 'io.supabase.shophub://login-callback/',
    );
  }

  /// Loads current session from Supabase or local cache.
  Future<ShopUser?> loadCurrentSession() async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser != null) {
        final profile = await _supabase
            .from('profiles')
            .select()
            .eq('id', authUser.id)
            .maybeSingle();

        if (profile != null) {
          return ShopUser.fromJson(profile);
        }

        final meta = authUser.userMetadata;
        final isAdmin = (meta?['is_admin'] == true) || (meta?['role'] == 'admin');
        return ShopUser(
          id: authUser.id,
          name: (meta?['name'] as String?) ?? authUser.email?.split('@').first ?? '',
          email: authUser.email ?? '',
          phone: (meta?['phone'] as String?) ?? '',
          isAdmin: isAdmin,
          role: (meta?['role'] as String?) ?? (isAdmin ? 'admin' : 'customer'),
        );
      }
    } catch (_) {}

    final sessionEmail = loadSessionEmail();
    if (sessionEmail != null) {
      final users = loadUsers();
      return users.cast<ShopUser?>().firstWhere(
            (u) => u?.email.toLowerCase() == sessionEmail.toLowerCase(),
            orElse: () => null,
          );
    }
    return null;
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (_) {}
    await saveSession(null);
  }

  /// Sends a password reset email via Supabase Auth or local mock.
  Future<void> sendPasswordResetEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      await _supabase.auth.resetPasswordForEmail(
        cleanEmail,
        redirectTo: kIsWeb ? null : 'io.supabase.shophub://reset-callback/',
      );
    } on AuthException catch (e) {
      throw e.message;
    } catch (_) {
      // Offline / mock mode succeeds gracefully
    }
  }

  /// Fetches all registered users from the Supabase Postgres 'profiles' table.
  Future<List<ShopUser>> fetchUsersFromSupabase() async {
    if (!hasSupabase) return loadUsers();
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .order('created_at', ascending: false);

      final list = (data as List).map((row) {
        final map = row as Map<String, dynamic>;
        final isAdmin = (map['is_admin'] == true) || (map['role'] == 'admin');
        return ShopUser(
          id: map['id'] as String?,
          name: (map['name'] as String?) ?? '',
          email: (map['email'] as String?) ?? '',
          phone: (map['phone'] as String?) ?? '',
          isAdmin: isAdmin,
          role: (map['role'] as String?) ?? (isAdmin ? 'admin' : 'customer'),
        );
      }).toList();

      if (list.isNotEmpty) {
        // Merge with existing local/mock users without duplicate emails
        final local = loadUsers();
        final Map<String, ShopUser> map = {
          for (final u in local) u.email.toLowerCase(): u,
        };
        for (final u in list) {
          map[u.email.toLowerCase()] = u;
        }
        final merged = map.values.toList();
        await saveUsers(merged);
        return merged;
      }
    } catch (e) {
      debugPrint('Error fetching users from Supabase profiles: $e');
    }
    return loadUsers();
  }

  // --------------------------------------------------------------------------
  // Local storage caching for offline/mock compatibility
  // --------------------------------------------------------------------------

  List<ShopUser> loadUsers() {
    final prefs = _prefs;
    final defaultUsers = [MockCatalog.admin, MockCatalog.demoCustomer];
    if (prefs == null) return defaultUsers;

    final uJson = prefs.getString(_kUsers);
    if (uJson != null) {
      try {
        final decoded = jsonDecode(uJson) as List;
        return decoded
            .map((e) => ShopUser.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return defaultUsers;
      }
    }
    return defaultUsers;
  }

  String? loadSessionEmail() {
    return _prefs?.getString(_kSession);
  }

  Future<void> saveUsers(List<ShopUser> users) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(
      _kUsers,
      jsonEncode(users.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> saveSession(String? email) async {
    final prefs = _prefs;
    if (prefs == null) return;
    if (email == null) {
      await prefs.remove(_kSession);
    } else {
      await prefs.setString(_kSession, email);
    }
  }
}
