import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../controllers/product_controller.dart';
import '../controllers/wishlist_controller.dart';
import '../theme/colors.dart';
import '../widgets/product_card.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  static const route = AppRoutes.wishlist;

  @override
  Widget build(BuildContext context) {
    final wishlistCtrl = Get.find<WishlistController>();
    final productCtrl = Get.find<ProductController>();

    return Obx(() {
      final items = wishlistCtrl.getWishlistProducts(productCtrl.products);

      return Scaffold(
        appBar: AppBar(title: const Text('Wishlist')),
        body: items.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.favorite_border,
                        size: 72, color: ShopColors.muted),
                    const SizedBox(height: 12),
                    const Text('Save products you love'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.products),
                      child: const Text('Discover products'),
                    ),
                  ],
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.62,
                ),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final p = items[i];
                  return ProductCard(
                    product: p,
                    wished: true,
                    onWish: () => wishlistCtrl.toggleWishlist(p.id),
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.productDetail,
                      arguments: p.id,
                    ),
                  );
                },
              ),
      );
    });
  }
}
