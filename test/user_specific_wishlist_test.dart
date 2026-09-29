import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shophub/controllers/auth_controller.dart';
import 'package:shophub/controllers/wishlist_controller.dart';
import 'package:shophub/models/product.dart';
import 'package:shophub/models/user.dart';
import 'package:shophub/services/auth_service.dart';
import 'package:shophub/services/wishlist_service.dart';
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

  const productX = Product(
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

  const productY = Product(
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

  const productZ = Product(
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

  group('User-Specific Wishlist Isolation (MVC Controllers)', () {
    late SharedPreferences prefs;
    late AuthService authService;
    late WishlistService wishlistService;
    late AuthController authCtrl;
    late WishlistController wishlistCtrl;

    setUp(() async {
      Get.reset();
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      authService = AuthService();
      await authService.init(prefs);

      wishlistService = WishlistService();
      await wishlistService.init(prefs);

      authCtrl = AuthController(authService: authService);
      wishlistCtrl = WishlistController(wishlistService: wishlistService);

      Get.put(authCtrl);
      Get.put(wishlistCtrl);

      authCtrl.init();
      wishlistCtrl.init();
    });

    test('User A adds Product X, User B logs in and sees empty Wishlist', () async {
      // 1. User A logs in
      authCtrl.setCurrentUser(userA);
      await wishlistCtrl.loadUserWishlist(userA.id);

      expect(wishlistCtrl.isEmpty, isTrue);
      expect(wishlistCtrl.activeUserId, userA.id);

      // 2. User A adds Product X
      wishlistCtrl.toggleWishlist(productX.id);
      expect(wishlistCtrl.count, 1);
      expect(wishlistCtrl.inWishlist(productX.id), isTrue);

      // Verify partitioned local storage
      final userAWishlistStored = prefs.getStringList('shophub.wishlist.${userA.id}');
      expect(userAWishlistStored, [productX.id]);
      expect(prefs.containsKey('shophub.wishlist'), isFalse);

      // 3. User A logs out
      await authCtrl.logout();
      expect(wishlistCtrl.isEmpty, isTrue);
      expect(wishlistCtrl.count, 0);
      expect(wishlistCtrl.activeUserId, isNull);

      // 4. User B logs in
      authCtrl.setCurrentUser(userB);
      await wishlistCtrl.loadUserWishlist(userB.id);

      // User B MUST see an empty wishlist, NOT Product X
      expect(wishlistCtrl.isEmpty, isTrue);
      expect(wishlistCtrl.count, 0);
      expect(wishlistCtrl.inWishlist(productX.id), isFalse);

      // 5. User B adds Product Y
      wishlistCtrl.toggleWishlist(productY.id);
      expect(wishlistCtrl.count, 1);
      expect(wishlistCtrl.inWishlist(productY.id), isTrue);
      expect(wishlistCtrl.inWishlist(productX.id), isFalse);

      // Verify User B's partitioned storage
      final userBWishlistStored = prefs.getStringList('shophub.wishlist.${userB.id}');
      expect(userBWishlistStored, [productY.id]);

      // 6. User B logs out and User A logs back in
      await authCtrl.logout();
      expect(wishlistCtrl.isEmpty, isTrue);

      authCtrl.setCurrentUser(userA);
      await wishlistCtrl.loadUserWishlist(userA.id);

      // User A sees Product X and NOT Product Y
      expect(wishlistCtrl.count, 1);
      expect(wishlistCtrl.inWishlist(productX.id), isTrue);
      expect(wishlistCtrl.inWishlist(productY.id), isFalse);
    });

    test('Same Product Z can independently exist in both User A and User B wishlists', () async {
      // 1. User A logs in and adds Product Z
      authCtrl.setCurrentUser(userA);
      await wishlistCtrl.loadUserWishlist(userA.id);
      wishlistCtrl.addProduct(productZ.id);
      expect(wishlistCtrl.inWishlist(productZ.id), isTrue);

      // 2. User A logs out
      await authCtrl.logout();

      // 3. User B logs in and also adds Product Z
      authCtrl.setCurrentUser(userB);
      await wishlistCtrl.loadUserWishlist(userB.id);
      expect(wishlistCtrl.inWishlist(productZ.id), isFalse); // Initially empty
      wishlistCtrl.addProduct(productZ.id);
      expect(wishlistCtrl.inWishlist(productZ.id), isTrue);

      // 4. User B logs out, User A logs back in, and removes Product Z
      await authCtrl.logout();
      authCtrl.setCurrentUser(userA);
      await wishlistCtrl.loadUserWishlist(userA.id);
      expect(wishlistCtrl.inWishlist(productZ.id), isTrue);

      // User A removes Product Z
      wishlistCtrl.removeProduct(productZ.id);
      expect(wishlistCtrl.inWishlist(productZ.id), isFalse);
      expect(wishlistCtrl.isEmpty, isTrue);

      // 5. User A logs out, User B logs back in
      await authCtrl.logout();
      authCtrl.setCurrentUser(userB);
      await wishlistCtrl.loadUserWishlist(userB.id);

      // User B MUST STILL HAVE Product Z!
      expect(wishlistCtrl.inWishlist(productZ.id), isTrue);
      expect(wishlistCtrl.count, 1);
    });

    test('Adding duplicate products does not create duplicates in wishlist', () async {
      authCtrl.setCurrentUser(userA);
      await wishlistCtrl.loadUserWishlist(userA.id);

      wishlistCtrl.addProduct(productX.id);
      wishlistCtrl.addProduct(productX.id);

      expect(wishlistCtrl.count, 1);
      expect(wishlistCtrl.wishlistIds, [productX.id]);
    });
  });

  group('User-Specific Wishlist Isolation (ShopStore Standalone)', () {
    late ShopStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});

      store = ShopStore();
      await store.init();
    });

    test('ShopStore isolates wishlist per standalone logged in user', () async {
      // 1. Initial: No user logged in
      expect(store.currentUser, isNull);
      expect(store.wishlistIds, isEmpty);

      // 2. Log in as User A
      store.currentUser = userA;
      expect(store.wishlistIds, isEmpty);

      // 3. Add Product X
      store.toggleWishlist(productX.id);
      expect(store.wishlistIds, contains(productX.id));
      expect(store.inWishlist(productX.id), isTrue);

      // 4. Logout
      store.logout();
      expect(store.currentUser, isNull);
      expect(store.wishlistIds, isEmpty);

      // 5. Log in as User B
      store.currentUser = userB;
      expect(store.wishlistIds, isEmpty);
      expect(store.inWishlist(productX.id), isFalse);

      // 6. User B adds Product Y
      store.toggleWishlist(productY.id);
      expect(store.wishlistIds, contains(productY.id));
      expect(store.inWishlist(productX.id), isFalse);

      // 7. Logout and login as User A again
      store.logout();
      expect(store.wishlistIds, isEmpty);

      store.currentUser = userA;
      expect(store.wishlistIds, contains(productX.id));
      expect(store.wishlistIds, isNot(contains(productY.id)));
    });
  });
}
