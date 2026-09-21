import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/routes/app_routes.dart';
import '../controllers/auth_controller.dart';
import '../controllers/order_controller.dart';
import '../controllers/product_controller.dart';
import '../theme/colors.dart';
import '../utils/money.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  static const route = AppRoutes.adminDashboard;

  @override
  Widget build(BuildContext context) {
    final authCtrl = context.watch<AuthController>();
    final productCtrl = context.watch<ProductController>();
    final orderCtrl = context.watch<OrderController>();

    final user = authCtrl.currentUser;
    if (user == null || !user.isAdmin) {
      return const Scaffold(body: Center(child: Text('Admin access only')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Admin dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Stat(label: 'Products', value: '${productCtrl.products.length}'),
              _Stat(label: 'Categories', value: '${productCtrl.categories.length}'),
              _Stat(label: 'Orders', value: '${orderCtrl.orders.length}'),
              _Stat(
                label: 'Revenue',
                value: pkr.format(
                  orderCtrl.orders.fold<double>(0, (s, o) => s + o.total),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.adminProductForm),
                  icon: const Icon(Icons.add),
                  label: const Text('Add product'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.adminCategories),
                  icon: const Icon(Icons.category_outlined),
                  label: const Text('Categories'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.adminOrders),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('View orders'),
          ),
          const SizedBox(height: 16),
          const Text('Catalog',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...productCtrl.products.map(
            (p) => Card(
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    p.imageUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const SizedBox(width: 48, height: 48),
                  ),
                ),
                title: Text(p.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(pkr.format(p.price)),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.adminProductForm,
                        arguments: p.id,
                      );
                    } else if (v == 'delete') {
                      productCtrl.deleteProduct(p.id);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: ShopColors.muted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        ],
      ),
    );
  }
}