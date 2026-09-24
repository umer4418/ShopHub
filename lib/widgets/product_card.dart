import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/wishlist_controller.dart';
import '../models/product.dart';
import '../theme/colors.dart';
import '../utils/money.dart';
import 'shop_product_image.dart';
import 'star_rating.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.wished,
    this.onWish,
  });

  final Product product;
  final VoidCallback onTap;
  final bool? wished;
  final VoidCallback? onWish;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: SizedBox.expand(
                      child: ShopProductImage(
                        imageUrl: product.imageUrl,
                        categoryId: product.categoryId,
                        productName: product.name,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  if (product.discountPercent > 0)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: ShopColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '-${product.discountPercent}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: _buildWishButton(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, height: 1.2, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pkr.format(product.price),
                    style: const TextStyle(
                      color: ShopColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  if (product.discountPercent > 0)
                    Text(
                      pkr.format(product.originalPrice),
                      style: const TextStyle(
                        color: ShopColors.muted,
                        fontSize: 11,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  const SizedBox(height: 4),
                  StarRating(rating: product.rating, size: 12, count: product.reviewCount),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWishButton() {
    if (Get.isRegistered<WishlistController>()) {
      final wishlistCtrl = Get.find<WishlistController>();
      return Obx(() {
        final isWished = wishlistCtrl.inWishlist(product.id);
        return IconButton.filledTonal(
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: isWished ? Colors.red : ShopColors.muted,
            visualDensity: VisualDensity.compact,
          ),
          onPressed: () {
            if (onWish != null) {
              onWish!();
            } else {
              wishlistCtrl.toggleWishlist(product.id);
            }
          },
          icon: Icon(
            isWished ? Icons.favorite : Icons.favorite_border,
            color: isWished ? Colors.red : ShopColors.muted,
          ),
        );
      });
    }

    final isWished = wished ?? false;
    return IconButton.filledTonal(
      style: IconButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: isWished ? Colors.red : ShopColors.muted,
        visualDensity: VisualDensity.compact,
      ),
      onPressed: onWish,
      icon: Icon(
        isWished ? Icons.favorite : Icons.favorite_border,
        color: isWished ? Colors.red : ShopColors.muted,
      ),
    );
  }
}
