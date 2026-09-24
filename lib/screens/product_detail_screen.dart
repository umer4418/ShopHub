import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../controllers/cart_controller.dart';
import '../controllers/product_controller.dart';
import '../controllers/wishlist_controller.dart';
import '../theme/colors.dart';
import '../utils/money.dart';
import '../widgets/quantity_stepper.dart';
import '../widgets/shop_product_image.dart';
import '../widgets/star_rating.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key});

  static const route = AppRoutes.productDetail;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int qty = 1;

  @override
  Widget build(BuildContext context) {
    final id = (ModalRoute.of(context)?.settings.arguments ?? Get.arguments) as String;
    final productCtrl = Get.find<ProductController>();
    final cartCtrl = Get.find<CartController>();
    final wishlistCtrl = Get.find<WishlistController>();

    return Obx(() {
      final product = productCtrl.products.firstWhere((p) => p.id == id);
      final wished = wishlistCtrl.inWishlist(product.id);
      final category = productCtrl.categoryById(product.categoryId);

      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Product details'),
          actions: [
            IconButton(
              tooltip: wished ? 'Remove from wishlist' : 'Add to wishlist',
              onPressed: () {
                wishlistCtrl.toggleWishlist(product.id);
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 1),
                    content: Text(
                      wishlistCtrl.inWishlist(product.id)
                          ? 'Added to wishlist'
                          : 'Removed from wishlist',
                    ),
                  ),
                );
              },
              icon: Icon(
                wished ? Icons.favorite : Icons.favorite_border,
                color: wished ? Colors.red : null,
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.cart),
              icon: Badge(
                isLabelVisible: cartCtrl.cartCount > 0,
                label: Text('${cartCtrl.cartCount}'),
                child: const Icon(Icons.shopping_cart_outlined),
              ),
            ),
          ],
        ),
        body: ListView(
          children: [
            AspectRatio(
              aspectRatio: 1.05,
              child: ShopProductImage(
                imageUrl: product.imageUrl,
                categoryId: product.categoryId,
                productName: product.name,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (category != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: ShopColors.primarySoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        category.name,
                        style: const TextStyle(
                          color: ShopColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    product.name,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800, height: 1.2),
                  ),
                  const SizedBox(height: 8),
                  StarRating(
                      rating: product.rating, count: product.reviewCount, size: 18),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        pkr.format(product.price),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: ShopColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (product.discountPercent > 0)
                        Text(
                          pkr.format(product.originalPrice),
                          style: const TextStyle(
                            color: ShopColors.muted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      const SizedBox(width: 10),
                      if (product.discountPercent > 0)
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: ShopColors.primarySoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '-${product.discountPercent}%',
                            style: const TextStyle(
                                color: ShopColors.primaryDark,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(product.shortDescription,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(product.description,
                      style: const TextStyle(
                          height: 1.45, color: ShopColors.muted)),
                  const SizedBox(height: 16),
                  Text('In stock: ${product.stock}',
                      style: const TextStyle(color: ShopColors.success)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Quantity', style: TextStyle(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      QuantityStepper(
                        value: qty,
                        max: product.stock,
                        onChanged: (v) => setState(() => qty = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      cartCtrl.addToCart(product, qty: qty);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Added to cart')),
                      );
                    },
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Add to Cart'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      cartCtrl.addToCart(product, qty: qty);
                      Navigator.pushNamed(context, AppRoutes.checkout);
                    },
                    child: const Text('Buy Now'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
