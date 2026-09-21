import 'package:flutter/foundation.dart';

import '../data/mock_catalog.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

/// Auth Controller
/// Manages user authentication state, active sessions, and registration.
class AuthController extends ChangeNotifier {
  final AuthService _authService;

  AuthController({AuthService? authService})
      : _authService = authService ?? AuthService();

  List<ShopUser> _users = [MockCatalog.admin, MockCatalog.demoCustomer];
  ShopUser? _currentUser;
  bool _isInitialized = false;

  List<ShopUser> get users => List.unmodifiable(_users);
  ShopUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isInitialized => _isInitialized;

  void init() {
    _users = _authService.loadUsers();
    final sessionEmail = _authService.loadSessionEmail();
    if (sessionEmail != null) {
      try {
        _currentUser = _users.firstWhere(
          (u) => u.email.toLowerCase() == sessionEmail.toLowerCase(),
        );
      } catch (_) {
        _currentUser = null;
      }
    }
    _isInitialized = true;
    notifyListeners();
  }

  /// Attempts to log in with [email] and [password].
  /// Returns null on success, or an error message on failure.
  String? login(String email, String password) {
    try {
      final user = _users.firstWhere(
        (u) =>
            u.email.toLowerCase() == email.trim().toLowerCase() &&
            u.password == password,
      );
      _currentUser = user;
      _authService.saveSession(user.email);
      notifyListeners();
      return null;
    } catch (_) {
      return 'Invalid email or password';
    }
  }

  /// Registers a new user account.
  /// Returns null on success, or an error message on failure.
  String? register({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) {
    final cleanEmail = email.trim().toLowerCase();
    final exists = _users.any((u) => u.email.toLowerCase() == cleanEmail);
    if (exists) {
      return 'An account with this email already exists';
    }

    final user = ShopUser(
      name: name.trim(),
      email: email.trim(),
      password: password,
      phone: phone.trim(),
    );

    _users.add(user);
    _currentUser = user;
    _authService.saveUsers(_users);
    _authService.saveSession(user.email);
    notifyListeners();
    return null;
  }

  /// Logs the current user out.
  void logout() {
    _currentUser = null;
    _authService.saveSession(null);
    notifyListeners();
  }

  /// For testing or direct assignment
  void setCurrentUser(ShopUser? user) {
    _currentUser = user;
    notifyListeners();
  }
}
