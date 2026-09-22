import 'package:get/get.dart';

import '../data/mock_catalog.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

/// Auth Controller
/// Manages user authentication state, active sessions, and registration.
class AuthController extends GetxController {
  final AuthService _authService;

  AuthController({AuthService? authService})
      : _authService = authService ?? AuthService();

  static AuthController get to => Get.find<AuthController>();

  final RxList<ShopUser> _users =
      <ShopUser>[MockCatalog.admin, MockCatalog.demoCustomer].obs;
  final Rxn<ShopUser> _currentUser = Rxn<ShopUser>();
  final RxBool _isInitialized = false.obs;

  List<ShopUser> get users => List.unmodifiable(_users);
  ShopUser? get currentUser => _currentUser.value;
  bool get isLoggedIn => _currentUser.value != null;
  bool get isAdmin => _currentUser.value?.isAdmin ?? false;
  bool get isInitialized => _isInitialized.value;

  void init() {
    _users.assignAll(_authService.loadUsers());
    final sessionEmail = _authService.loadSessionEmail();
    if (sessionEmail != null) {
      try {
        _currentUser.value = _users.firstWhere(
          (u) => u.email.toLowerCase() == sessionEmail.toLowerCase(),
        );
      } catch (_) {
        _currentUser.value = null;
      }
    }
    _isInitialized.value = true;
    update();
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
      _currentUser.value = user;
      _authService.saveSession(user.email);
      update();
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
    _currentUser.value = user;
    _authService.saveUsers(_users);
    _authService.saveSession(user.email);
    update();
    return null;
  }

  /// Logs the current user out.
  void logout() {
    _currentUser.value = null;
    _authService.saveSession(null);
    update();
  }

  /// For testing or direct assignment
  void setCurrentUser(ShopUser? user) {
    _currentUser.value = user;
    update();
  }
}
