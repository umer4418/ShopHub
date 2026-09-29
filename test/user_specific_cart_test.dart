import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shophub/controllers/auth_controller.dart';
import 'package:shophub/controllers/cart_controller.dart';
import 'package:shophub/models/product.dart';
import 'package:shophub/models/user.dart';
import 'package:shophub/services/auth_service.dart';
import 'package:shophub/services/cart_service.dart';
import 'package:shophub/state/shop_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const userA = ShopUser(
    id: 'user-a-uuid-1111',
    name: 'User A',
    email: 'usera@example.com',
    password: 'password123',
    role: 'customer',
  );

  const userB = ShopUser(
    id: 'user-b-uuid-2222',
    name: 'User B',
    email: 'userb@example.com',
    password: 'password123',
    role: 'customer',
  );

  const adminUser = ShopUser(
    id: 'admin-uuid-9999',
    name: 'Super Admin',
    email: 'admin@example.com',
    password: 'adminpassword',
    isAdmin: true,
    role: 'admin',
  );

  const iphone = Product(
    id: 'prod-iphone',
    name: 'Apple iPhone 15 Pro',
    categoryId: 'mobiles',
    imageUrl: 'https://example.com/iphone.jpg',
    price: 350000.0,
    originalPrice: 380000.0,
    rating: 4.9,
    reviewCount: 420,
    shortDescription: 'Titanium design, A17 Pro chip',
    description: 'The latest iPhone',
    stock: 15,
  );

  const laptop = Product(
    id: 'prod-laptop',
    name: 'Dell XPS 15',
    categoryId: 'electronics',
    imageUrl: 'https://example.com/laptop.jpg',
    price: 450000.0,
    originalPrice: 480000.0,
    rating: 4.7,
    reviewCount: 150,
    shortDescription: 'Intel Core i9, OLED display',
    description: 'High performance laptop',
    stock: 8,
  );

  const earbuds = Product(
    id: 'prod-earbuds',
    name: 'Pro Wireless Earbuds',
    categoryId: 'electronics',
    imageUrl: 'https://example.com/earbuds.jpg',
    price: 15000.0,
    originalPrice: 20000.0,
    rating: 4.5,
    reviewCount: 89,
    shortDescription: 'Active Noise Cancelling',
    description: 'Studio sound quality',
    stock: 50,
  );

  group('User-Specific Cart Isolation (MVC Controllers)', () {
    late SharedPreferences prefs;
    late AuthService authService;
    late CartService cartService;
    late AuthController authCtrl;
    late CartController cartCtrl;

    setUp(() async {
      Get.reset();
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      authService = AuthService();
      await authService.init(prefs);

      cartService = CartService();
      await cartService.init(prefs);

      authCtrl = AuthController(authService: authService);
      cartCtrl = CartController(cartService: cartService);

      Get.put<AuthService>(authService);
      Get.put<CartService>(cartService);
      Get.put<AuthController>(authCtrl);
      Get.put<CartController>(cartCtrl);

      // Register mock users
      await authService.saveUsers([userA, userB, adminUser]);
      authCtrl.init();
      cartCtrl.init();
    });

    tearDown(() {
      Get.reset();
    });

    test('Full User A -> User B -> User A -> Admin cart isolation flow', () async {
      // 1. Initial state: No user logged in, cart must be empty
      expect(authCtrl.isLoggedIn, isFalse);
      expect(cartCtrl.isEmpty, isTrue);
      expect(cartCtrl.cartCount, 0);

      // 2. User A logs in
      authCtrl.setCurrentUser(userA);
      expect(authCtrl.currentUser?.id, userA.id);
      expect(cartCtrl.isEmpty, isTrue);

      // 3. User A adds iPhone to cart
      cartCtrl.addToCart(iphone, qty: 1);
      expect(cartCtrl.cartCount, 1);
      expect(cartCtrl.cart.first.product.id, 'prod-iphone');
      expect(cartCtrl.cart.first.userId, userA.id);

      // 4. Verify User A's cart is stored under userA's key in SharedPreferences
      final userACache = prefs.getString('shophub.cart.${userA.id}');
      expect(userACache, isNotNull);
      expect(userACache!.contains('prod-iphone'), isTrue);

      // Verify no shared global cart key was written
      expect(prefs.containsKey('shophub.cart'), isFalse);

      // 5. User A logs out
      authCtrl.setCurrentUser(null);
      expect(authCtrl.isLoggedIn, isFalse);
      // Local cart state must be cleared immediately upon logout
      expect(cartCtrl.isEmpty, isTrue);
      expect(cartCtrl.cartCount, 0);

      // 6. User B logs in
      authCtrl.setCurrentUser(userB);
      expect(authCtrl.currentUser?.id, userB.id);
      // User B must NOT see User A's iPhone!
      expect(cartCtrl.isEmpty, isTrue);
      expect(cartCtrl.cartCount, 0);

      // 7. User B adds Laptop to cart
      cartCtrl.addToCart(laptop, qty: 2);
      expect(cartCtrl.cartCount, 2);
      expect(cartCtrl.cart.first.product.id, 'prod-laptop');
      expect(cartCtrl.cart.first.userId, userB.id);

      // Verify User B's cart is stored under userB's key
      final userBCache = prefs.getString('shophub.cart.${userB.id}');
      expect(userBCache, isNotNull);
      expect(userBCache!.contains('prod-laptop'), isTrue);
      expect(userBCache.contains('prod-iphone'), isFalse);

      // 8. User B logs out
      authCtrl.setCurrentUser(null);
      expect(cartCtrl.isEmpty, isTrue);

      // 9. User A logs in again -> Cart should show only the iPhone previously added by User A
      authCtrl.setCurrentUser(userA);
      expect(authCtrl.currentUser?.id, userA.id);
      expect(cartCtrl.cartCount, 1);
      expect(cartCtrl.cart.first.product.id, 'prod-iphone');
      expect(cartCtrl.cart.any((i) => i.product.id == 'prod-laptop'), isFalse);

      // 10. Admin logs in -> Admin should have their own separate cart
      authCtrl.setCurrentUser(adminUser);
      expect(authCtrl.isAdmin, isTrue);
      // Admin's cart should be empty (no items yet)
      expect(cartCtrl.isEmpty, isTrue);

      // Admin adds Earbuds
      cartCtrl.addToCart(earbuds, qty: 3);
      expect(cartCtrl.cartCount, 3);
      expect(cartCtrl.cart.first.product.id, 'prod-earbuds');
      expect(cartCtrl.cart.first.userId, adminUser.id);

      // 11. Switch back to User B -> should see Laptop only
      authCtrl.setCurrentUser(userB);
      expect(cartCtrl.cartCount, 2);
      expect(cartCtrl.cart.first.product.id, 'prod-laptop');
      expect(cartCtrl.cart.any((i) => i.product.id == 'prod-earbuds'), isFalse);
      expect(cartCtrl.cart.any((i) => i.product.id == 'prod-iphone'), isFalse);

      // 12. Switch back to Admin -> should see Earbuds only
      authCtrl.setCurrentUser(adminUser);
      expect(cartCtrl.cartCount, 3);
      expect(cartCtrl.cart.first.product.id, 'prod-earbuds');
    });

    test('clearCart only wipes the current user cart without affecting other users', () async {
      // User A adds iPhone
      authCtrl.setCurrentUser(userA);
      cartCtrl.addToCart(iphone);
      expect(cartCtrl.cartCount, 1);

      // User B adds Laptop
      authCtrl.setCurrentUser(userB);
      expect(cartCtrl.cartCount, 0);
      cartCtrl.addToCart(laptop);
      expect(cartCtrl.cartCount, 1);

      // User B clears cart
      cartCtrl.clearCart();
      expect(cartCtrl.isEmpty, isTrue);
      expect(prefs.containsKey('shophub.cart.${userB.id}'), isFalse);

      // Switch back to User A -> User A's iPhone should still be completely intact
      authCtrl.setCurrentUser(userA);
      expect(cartCtrl.cartCount, 1);
      expect(cartCtrl.cart.first.product.id, 'prod-iphone');
      expect(prefs.containsKey('shophub.cart.${userA.id}'), isTrue);
    });
  });

  group('User-Specific Cart Isolation in ShopStore (Standalone / Unified Facade)', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('ShopStore in standalone mode isolates cart per user', () async {
      final store = ShopStore();
      await store.init();

      // No user initially
      expect(store.currentUser, isNull);
      expect(store.cart.isEmpty, isTrue);

      // User A logs in
      store.currentUser = userA;
      expect(store.cart.isEmpty, isTrue);

      // User A adds iPhone
      store.addToCart(iphone, qty: 1);
      expect(store.cartCount, 1);
      expect(store.cart.first.product.id, 'prod-iphone');
      expect(store.cart.first.userId, userA.id);

      // User A logs out
      store.logout();
      expect(store.currentUser, isNull);
      expect(store.cart.isEmpty, isTrue);

      // User B logs in
      store.currentUser = userB;
      expect(store.cart.isEmpty, isTrue);

      // User B adds Laptop
      store.addToCart(laptop, qty: 1);
      expect(store.cartCount, 1);
      expect(store.cart.first.product.id, 'prod-laptop');
      expect(store.cart.first.userId, userB.id);

      // User B logs out
      store.logout();
      expect(store.cart.isEmpty, isTrue);

      // User A logs in again -> sees iPhone
      store.currentUser = userA;
      expect(store.cartCount, 1);
      expect(store.cart.first.product.id, 'prod-iphone');
    });
  });
}
