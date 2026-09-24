import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final RxBool _isLoading = false.obs;

  List<ShopUser> get users => List.unmodifiable(_users);
  ShopUser? get currentUser => _currentUser.value;
  bool get isLoggedIn => _currentUser.value != null;
  bool get isAdmin => _currentUser.value?.isAdmin ?? false;
  bool get isInitialized => _isInitialized.value;
  bool get isLoading => _isLoading.value;

  void init() {
    _users.assignAll(_authService.loadUsers());
    _loadInitialSession();
    _listenToAuthChanges();
    _isInitialized.value = true;
    update();
  }

  Future<void> _loadInitialSession() async {
    try {
      final user = await _authService.loadCurrentSession();
      if (user != null) {
        _currentUser.value = user;
        update();
      }
    } catch (_) {}
  }

  void _listenToAuthChanges() {
    try {
      Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
        final session = data.session;
        if (session != null) {
          final user = await _authService.loadCurrentSession();
          if (user != null) {
            _currentUser.value = user;
            update();
          }
        }
      });
    } catch (_) {
      // Ignored if Supabase client is not initialized in mock/test runs
    }
  }

  /// Attempts to log in with [email] and [password].
  /// Returns null on success, or an error message on failure.
  Future<String?> login(String email, String password) async {
    _isLoading.value = true;
    update();
    try {
      final user = await _authService.signInWithEmail(
        email: email,
        password: password,
      );
      _currentUser.value = user;
      _isLoading.value = false;
      update();
      return null;
    } catch (e) {
      _isLoading.value = false;
      update();
      final msg = e.toString().replaceAll('Exception:', '').trim();
      return msg.isNotEmpty ? msg : 'Invalid email or password';
    }
  }

  /// Registers a new user account (as Customer or Admin).
  /// Returns null on success, or an error message on failure.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    bool isAdmin = false,
  }) async {
    _isLoading.value = true;
    update();
    try {
      final user = await _authService.signUpWithEmail(
        name: name,
        email: email,
        password: password,
        phone: phone,
        isAdmin: isAdmin,
      );
      _users.add(user);
      _currentUser.value = user;
      _isLoading.value = false;
      update();
      return null;
    } catch (e) {
      _isLoading.value = false;
      update();
      final msg = e.toString().replaceAll('Exception:', '').trim();
      return msg.isNotEmpty ? msg : 'Registration failed';
    }
  }

  /// Sign in with Google OAuth via Supabase.
  Future<String?> loginWithGoogle() async {
    _isLoading.value = true;
    update();
    try {
      await _authService.signInWithGoogle();
      _isLoading.value = false;
      update();
      return null;
    } catch (e) {
      _isLoading.value = false;
      update();
      return e.toString();
    }
  }

  /// Logs the current user out.
  Future<void> logout() async {
    await _authService.signOut();
    _currentUser.value = null;
    update();
  }

  /// Sends a password reset email to [email].
  /// Returns null on success or an error message on failure.
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
      return null;
    } catch (e) {
      final msg = e.toString().replaceAll('Exception:', '').trim();
      return msg.isNotEmpty ? msg : 'Failed to send password reset email';
    }
  }

  /// For testing or direct assignment
  void setCurrentUser(ShopUser? user) {
    _currentUser.value = user;
    update();
  }
}
