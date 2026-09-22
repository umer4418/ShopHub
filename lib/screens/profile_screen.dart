import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../controllers/auth_controller.dart';
import '../controllers/order_controller.dart';
import '../models/order.dart';
import '../theme/colors.dart';
import '../utils/money.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authCtrl = Get.find<AuthController>();
    final orderCtrl = Get.find<OrderController>();

    return Obx(() {
      final user = authCtrl.currentUser;

      if (user == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Account')),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hello, guest',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text(
                    'Log in to track orders, save a wishlist, and check out faster.'),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
                    child: const Text('Login'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.register),
                    child: const Text('Register'),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      final myOrders = orderCtrl.getUserOrders(
        phone: user.phone,
        name: user.name,
      );

      return Scaffold(
        appBar: AppBar(title: const Text('My profile')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: ShopColors.primary,
                    child: Text(
                      user.name.characters.first.toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800)),
                        Text(user.email,
                            style: const TextStyle(color: ShopColors.muted)),
                        if (user.phone.isNotEmpty)
                          Text(user.phone,
                              style: const TextStyle(color: ShopColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              tileColor: Colors.white,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.favorite_border, color: ShopColors.primary),
              title: const Text('Wishlist'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, AppRoutes.wishlist),
            ),
            if (user.isAdmin) ...[
              const SizedBox(height: 8),
              ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                leading: const Icon(Icons.admin_panel_settings_outlined,
                    color: ShopColors.primary),
                title: const Text('Admin dashboard'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.adminDashboard),
              ),
            ],
            const SizedBox(height: 20),
            const Text('My orders',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (myOrders.isEmpty)
              const Text('No orders yet.',
                  style: TextStyle(color: ShopColors.muted))
            else
              ...myOrders.map(
                (o) => ListTile(
                  tileColor: Colors.white,
                  title: Text(o.id),
                  subtitle: Text('${o.status.label}  •  ${pkr.format(o.total)}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.orderConfirmation,
                    arguments: o.id,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => authCtrl.logout(),
              child: const Text('Logout'),
            ),
          ],
        ),
      );
    });
  }
}
