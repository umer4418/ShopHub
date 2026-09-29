import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/mock_catalog.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import 'cart_controller.dart';
import 'chatbot_controller.dart';
import 'order_controller.dart';
import 'product_controller.dart';
import 'support_chat_controller.dart';
import 'wishlist_controller.dart';

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
    fetchUsers();
    _isInitialized.value = true;
    update();
  }

  /// Fetches all registered users from Supabase and updates the live list.
  Future<void> fetchUsers() async {
    try {
      final remote = await _authService.fetchUsersFromSupabase();
      if (remote.isNotEmpty) {
        _users.assignAll(remote);
        update();
      }
    } catch (_) {}
  }

  Future<void> _loadInitialSession() async {
    try {
      final user = await _authService.loadCurrentSession();
      if (user != null) {
        _currentUser.value = user;
        update();
        if (Get.isRegistered<CartController>()) {
          Get.find<CartController>().loadUserCart(user.id ?? user.email);
        }
        if (Get.isRegistered<WishlistController>()) {
          Get.find<WishlistController>().loadUserWishlist(user.id ?? user.email);
        }
        if (Get.isRegistered<ProductController>()) {
          Get.find<ProductController>().onUserChanged(user.id ?? user.email);
        }
        if (Get.isRegistered<ChatbotController>()) {
          Get.find<ChatbotController>().onUserChanged(user.id);
        }
        if (Get.isRegistered<OrderController>()) {
          Get.find<OrderController>().onUserChanged(user.id);
        }
        if (Get.isRegistered<SupportChatController>()) {
          Get.find<SupportChatController>().onUserChanged(user.id);
        }
      } else {
        if (_currentUser.value != null) return;
        if (Get.isRegistered<CartController>()) {
          Get.find<CartController>().clearCartForLogout();
        }
        if (Get.isRegistered<WishlistController>()) {
          Get.find<WishlistController>().clearWishlistForLogout();
        }
        if (Get.isRegistered<ProductController>()) {
          Get.find<ProductController>().clearSearchForLogout();
        }
        if (Get.isRegistered<ChatbotController>()) {
          Get.find<ChatbotController>().onUserChanged(null);
        }
        if (Get.isRegistered<OrderController>()) {
          Get.find<OrderController>().onUserChanged(null);
        }
        if (Get.isRegistered<SupportChatController>()) {
          Get.find<SupportChatController>().onUserChanged(null);
        }
      }
    } catch (_) {}
  }

  void _listenToAuthChanges() {
    try {
      Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
        final session = data.session;
        final event = data.event;
        if (session != null) {
          final user = await _authService.loadCurrentSession();
          if (user != null) {
            _currentUser.value = user;
            update();
            if (Get.isRegistered<CartController>()) {
              Get.find<CartController>().loadUserCart(user.id ?? session.user.id);
            }
            if (Get.isRegistered<WishlistController>()) {
              Get.find<WishlistController>().loadUserWishlist(user.id ?? session.user.id);
            }
            if (Get.isRegistered<ProductController>()) {
              Get.find<ProductController>().onUserChanged(user.id ?? session.user.id);
            }
            if (Get.isRegistered<ChatbotController>()) {
              Get.find<ChatbotController>().onUserChanged(user.id ?? session.user.id);
            }
            if (Get.isRegistered<OrderController>()) {
              Get.find<OrderController>().onUserChanged(user.id ?? session.user.id);
            }
            if (Get.isRegistered<SupportChatController>()) {
              Get.find<SupportChatController>().onUserChanged(user.id ?? session.user.id);
            }
          }
        } else if (event == AuthChangeEvent.signedOut || session == null) {
          _currentUser.value = null;
          update();
          if (Get.isRegistered<CartController>()) {
            Get.find<CartController>().clearCartForLogout();
          }
          if (Get.isRegistered<WishlistController>()) {
            Get.find<WishlistController>().clearWishlistForLogout();
          }
          if (Get.isRegistered<ProductController>()) {
            Get.find<ProductController>().clearSearchForLogout();
          }
          if (Get.isRegistered<ChatbotController>()) {
            Get.find<ChatbotController>().onUserChanged(null);
          }
          if (Get.isRegistered<OrderController>()) {
            Get.find<OrderController>().onUserChanged(null);
          }
          if (Get.isRegistered<SupportChatController>()) {
            Get.find<SupportChatController>().onUserChanged(null);
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

      // Reset and load user-specific cart & wishlist
      if (Get.isRegistered<CartController>()) {
        await Get.find<CartController>().loadUserCart(user.id ?? user.email);
      }
      if (Get.isRegistered<WishlistController>()) {
        await Get.find<WishlistController>().loadUserWishlist(user.id ?? user.email);
      }
      if (Get.isRegistered<ProductController>()) {
        Get.find<ProductController>().onUserChanged(user.id ?? user.email);
      }

      // Refresh chatbot context for newly logged in user
      if (Get.isRegistered<ChatbotController>()) {
        Get.find<ChatbotController>().onUserChanged(user.id);
      }
      if (Get.isRegistered<OrderController>()) {
        Get.find<OrderController>().onUserChanged(user.id);
      }
      if (Get.isRegistered<SupportChatController>()) {
        Get.find<SupportChatController>().onUserChanged(user.id);
      }

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

      // Reset and load user-specific cart & wishlist
      if (Get.isRegistered<CartController>()) {
        await Get.find<CartController>().loadUserCart(user.id ?? user.email);
      }
      if (Get.isRegistered<WishlistController>()) {
        await Get.find<WishlistController>().loadUserWishlist(user.id ?? user.email);
      }
      if (Get.isRegistered<ProductController>()) {
        Get.find<ProductController>().onUserChanged(user.id ?? user.email);
      }

      // Refresh chatbot context for registered user
      if (Get.isRegistered<ChatbotController>()) {
        Get.find<ChatbotController>().onUserChanged(user.id);
      }
      if (Get.isRegistered<OrderController>()) {
        Get.find<OrderController>().onUserChanged(user.id);
      }
      if (Get.isRegistered<SupportChatController>()) {
        Get.find<SupportChatController>().onUserChanged(user.id);
      }

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
      final user = await _authService.loadCurrentSession();
      if (user != null) {
        _currentUser.value = user;
        if (Get.isRegistered<CartController>()) {
          await Get.find<CartController>().loadUserCart(user.id ?? user.email);
        }
        if (Get.isRegistered<WishlistController>()) {
          await Get.find<WishlistController>().loadUserWishlist(user.id ?? user.email);
        }
        if (Get.isRegistered<ProductController>()) {
          Get.find<ProductController>().onUserChanged(user.id ?? user.email);
        }
        if (Get.isRegistered<ChatbotController>()) {
          Get.find<ChatbotController>().onUserChanged(user.id);
        }
        if (Get.isRegistered<OrderController>()) {
          Get.find<OrderController>().onUserChanged(user.id);
        }
        if (Get.isRegistered<SupportChatController>()) {
          Get.find<SupportChatController>().onUserChanged(user.id);
        }
      }
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
    // Clear and reset local cart state
    if (Get.isRegistered<CartController>()) {
      Get.find<CartController>().clearCartForLogout();
    }
    // Clear and reset local wishlist state
    if (Get.isRegistered<WishlistController>()) {
      Get.find<WishlistController>().clearWishlistForLogout();
    }
    // Clear and reset home search state
    if (Get.isRegistered<ProductController>()) {
      Get.find<ProductController>().clearSearchForLogout();
    }
    // Clear and reset chatbot context on logout
    if (Get.isRegistered<ChatbotController>()) {
      Get.find<ChatbotController>().onUserChanged(null);
    }
    if (Get.isRegistered<OrderController>()) {
      Get.find<OrderController>().onUserChanged(null);
    }
    if (Get.isRegistered<SupportChatController>()) {
      Get.find<SupportChatController>().onUserChanged(null);
    }
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
    if (user != null) {
      if (Get.isRegistered<CartController>()) {
        Get.find<CartController>().loadUserCart(user.id ?? user.email);
      }
      if (Get.isRegistered<WishlistController>()) {
        Get.find<WishlistController>().loadUserWishlist(user.id ?? user.email);
      }
      if (Get.isRegistered<ProductController>()) {
        Get.find<ProductController>().onUserChanged(user.id ?? user.email);
      }
      if (Get.isRegistered<ChatbotController>()) {
        Get.find<ChatbotController>().onUserChanged(user.id);
      }
      if (Get.isRegistered<OrderController>()) {
        Get.find<OrderController>().onUserChanged(user.id);
      }
      if (Get.isRegistered<SupportChatController>()) {
        Get.find<SupportChatController>().onUserChanged(user.id);
      }
    } else {
      if (Get.isRegistered<CartController>()) {
        Get.find<CartController>().clearCartForLogout();
      }
      if (Get.isRegistered<WishlistController>()) {
        Get.find<WishlistController>().clearWishlistForLogout();
      }
      if (Get.isRegistered<ProductController>()) {
        Get.find<ProductController>().clearSearchForLogout();
      }
      if (Get.isRegistered<ChatbotController>()) {
        Get.find<ChatbotController>().onUserChanged(null);
      }
      if (Get.isRegistered<OrderController>()) {
        Get.find<OrderController>().onUserChanged(null);
      }
      if (Get.isRegistered<SupportChatController>()) {
        Get.find<SupportChatController>().onUserChanged(null);
      }
    }
    update();
  }
}
