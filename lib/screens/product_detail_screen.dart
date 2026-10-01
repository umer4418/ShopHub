import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../controllers/cart_controller.dart';
import '../controllers/product_controller.dart';
import '../controllers/wishlist_controller.dart';
import '../theme/colors.dart';
import '../utils/money.dart';
import '../utils/responsive.dart';
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

      final isSmall = Responsive.isSmallMobile(context);

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
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Responsive.maxTabletContentWidth),
            child: ListView(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: Responsive.value<double>(
                      context,
                      smallMobile: 280,
                      mobile: 360,
                      tablet: 420,
                      desktop: 460,
                    ),
                  ),
                  child: AspectRatio(
                    aspectRatio: Responsive.value<double>(
                      context,
                      smallMobile: 1.15,
                      mobile: 1.05,
                      tablet: 1.3,
                      desktop: 1.5,
                    ),
                    child: ShopProductImage(
                      imageUrl: product.imageUrl,
                      categoryId: product.categoryId,
                      productName: product.name,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Padding(
                  padding: Responsive.screenPadding(context, horizontal: 16, vertical: 16),
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
                        style: TextStyle(
                            fontSize: isSmall ? 19 : 22, fontWeight: FontWeight.w800, height: 1.2),
                      ),
                      const SizedBox(height: 8),
                      StarRating(
                          rating: product.rating, count: product.reviewCount, size: isSmall ? 16 : 18),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            pkr.format(product.price),
                            style: TextStyle(
                              fontSize: isSmall ? 22 : 26,
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
                          style: TextStyle(
                              fontSize: isSmall ? 13.5 : 15, fontWeight: FontWeight.w600)),
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
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Responsive.maxTabletContentWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isSmall ? 10 : 16,
                  8,
                  isSmall ? 10 : 16,
                  12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: isSmall
                            ? OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                              )
                            : null,
                        onPressed: () {
                          cartCtrl.addToCart(product, qty: qty);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Added to cart')),
                          );
                        },
                        icon: Icon(Icons.add_shopping_cart, size: isSmall ? 18 : 20),
                        label: Text('Add to Cart', style: TextStyle(fontSize: isSmall ? 12 : 14)),
                      ),
                    ),
                    SizedBox(width: isSmall ? 6 : 10),
                    Expanded(
                      child: ElevatedButton(
                        style: isSmall
                            ? ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                              )
                            : null,
                        onPressed: () {
                          cartCtrl.addToCart(product, qty: qty);
                          Navigator.pushNamed(context, AppRoutes.checkout);
                        },
                        child: Text('Buy Now', style: TextStyle(fontSize: isSmall ? 12 : 14)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
