import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../controllers/auth_controller.dart';
import '../controllers/cart_controller.dart';
import '../theme/colors.dart';
import '../utils/money.dart';
import '../utils/responsive.dart';
import '../widgets/quantity_stepper.dart';
import '../widgets/shop_product_image.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  static const route = AppRoutes.cart;

  @override
  Widget build(BuildContext context) {
    final cartCtrl = Get.find<CartController>();

    return Obx(() {
      if (cartCtrl.isEmpty) {
        return Scaffold(
          appBar: AppBar(title: const Text('My Cart')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shopping_cart_outlined,
                    size: 72, color: ShopColors.muted),
                const SizedBox(height: 12),
                const Text('Your cart is empty'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.products),
                  child: const Text('Browse products'),
                ),
              ],
            ),
          ),
        );
      }

      final isSmall = Responsive.isSmallMobile(context);

      return Scaffold(
        appBar: AppBar(title: Text('My Cart (${cartCtrl.cartCount})')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Responsive.maxMobileContentWidth),
            child: Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: Responsive.screenPadding(context, horizontal: 12, vertical: 12),
                    itemCount: cartCtrl.cart.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final item = cartCtrl.cart[i];
                      return Container(
                        padding: EdgeInsets.all(isSmall ? 8 : 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            ShopProductImage(
                              imageUrl: item.product.imageUrl,
                              categoryId: item.product.categoryId,
                              productName: item.product.name,
                              width: isSmall ? 64 : 78,
                              height: isSmall ? 64 : 78,
                              borderRadius: BorderRadius.circular(8),
                              fit: BoxFit.cover,
                            ),
                            SizedBox(width: isSmall ? 8 : 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.product.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: isSmall ? 13 : 14,
                                      )),
                                  const SizedBox(height: 4),
                                  Text(pkr.format(item.product.price),
                                      style: TextStyle(
                                          color: ShopColors.primary,
                                          fontWeight: FontWeight.w800,
                                          fontSize: isSmall ? 13.5 : 14.5)),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      QuantityStepper(
                                        value: item.quantity,
                                        max: item.product.stock,
                                        onChanged: (v) =>
                                            cartCtrl.setCartQty(item.product.id, v),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        onPressed: () =>
                                            cartCtrl.removeFromCart(item.product.id),
                                        icon: const Icon(Icons.delete_outline,
                                            color: ShopColors.muted),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.fromLTRB(
                    isSmall ? 12 : 16,
                    12,
                    isSmall ? 12 : 16,
                    20,
                  ),
                  child: Column(
                    children: [
                      if (cartCtrl.appliedCoupon != null) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Coupon (${cartCtrl.appliedCoupon!.code} - ${cartCtrl.appliedCoupon!.discountPercent}%)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13.5, color: Colors.green, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '-${pkr.format(cartCtrl.discountAmount)}',
                              style: const TextStyle(fontSize: 14, color: Colors.green, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      Row(
                        children: [
                          const Text('Total',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          const Spacer(),
                          Text(
                            pkr.format(cartCtrl.finalTotal),
                            style: TextStyle(
                              fontSize: isSmall ? 18 : 20,
                              fontWeight: FontWeight.w800,
                              color: ShopColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            final authCtrl = Get.find<AuthController>();
                            if (!authCtrl.isLoggedIn) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please log in as a customer to place an order.'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              Navigator.pushNamed(context, AppRoutes.login);
                              return;
                            }
                            Navigator.pushNamed(context, AppRoutes.checkout);
                          },
                          child: const Text('Proceed to Checkout'),
                        ),
                      ),
                    ],
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
