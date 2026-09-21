import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/mock_catalog.dart';
import '../models/user.dart';

/// Auth Service
/// Handles persistence of user accounts and active sessions.
class AuthService {
  static const _kUsers = 'shophub.users';
  static const _kSession = 'shophub.session';

  SharedPreferences? _prefs;

  Future<void> init([SharedPreferences? prefs]) async {
    _prefs = prefs ?? await SharedPreferences.getInstance();
  }

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
