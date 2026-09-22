import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../controllers/cart_controller.dart';
import '../theme/colors.dart';
import '../utils/money.dart';
import '../widgets/quantity_stepper.dart';

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

      return Scaffold(
        appBar: AppBar(title: Text('My Cart (${cartCtrl.cartCount})')),
        body: Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: cartCtrl.cart.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final item = cartCtrl.cart[i];
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            item.product.imageUrl,
                            width: 78,
                            height: 78,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(
                              width: 78,
                              height: 78,
                              child: ColoredBox(color: ShopColors.primarySoft),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.product.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(pkr.format(item.product.price),
                                  style: const TextStyle(
                                      color: ShopColors.primary,
                                      fontWeight: FontWeight.w800)),
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text('Total',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text(
                        pkr.format(cartCtrl.cartTotal),
                        style: const TextStyle(
                          fontSize: 20,
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
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.checkout),
                      child: const Text('Proceed to Checkout'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}
