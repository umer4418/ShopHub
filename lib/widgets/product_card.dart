import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/cart_controller.dart';
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image & Badges Stack
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                    child: SizedBox.expand(
                      child: ShopProductImage(
                        imageUrl: product.imageUrl,
                        categoryId: product.categoryId,
                        productName: product.name,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                  // Discount Badge
                  if (product.discountPercent > 0)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE11D48), Color(0xFFF43F5E)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '-${product.discountPercent}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),

                  // Wishlist Heart Button (Maintains single IconButton for test finder compatibility)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: _buildWishButton(),
                  ),
                ],
              ),
            ),

            // Product Details
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      fontSize: 12.5,
                      color: ShopColors.text,
                    ),
                  ),
                  const SizedBox(height: 5),

                  // Price and Quick Add-to-Cart Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pkr.format(product.price),
                              style: const TextStyle(
                                color: ShopColors.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
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
                          ],
                        ),
                      ),

                      // Quick Add to Cart Action
                      GestureDetector(
                        onTap: () {
                          if (Get.isRegistered<CartController>()) {
                            Get.find<CartController>().addToCart(product);
                            final messenger =
                                ScaffoldMessenger.maybeOf(context);
                            if (messenger != null) {
                              messenger.hideCurrentSnackBar();
                              messenger.showSnackBar(
                                SnackBar(
                                  content:
                                      Text('${product.name} added to cart'),
                                  duration: const Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: ShopColors.navy,
                                ),
                              );
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: ShopColors.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: ShopColors.primary.withValues(alpha: 0.35),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.add_shopping_cart_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),

                  // Ratings & Review Count
                  StarRating(
                    rating: product.rating,
                    size: 11,
                    count: product.reviewCount,
                  ),
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
            backgroundColor: Colors.white.withValues(alpha: 0.95),
            foregroundColor: isWished ? Colors.red : ShopColors.muted,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
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
            size: 18,
          ),
        );
      });
    }

    final isWished = wished ?? false;
    return IconButton.filledTonal(
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.95),
        foregroundColor: isWished ? Colors.red : ShopColors.muted,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(6),
      ),
      onPressed: onWish,
      icon: Icon(
        isWished ? Icons.favorite : Icons.favorite_border,
        color: isWished ? Colors.red : ShopColors.muted,
        size: 18,
      ),
    );
  }
}
