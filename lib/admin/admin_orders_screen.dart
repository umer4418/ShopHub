import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/routes/app_routes.dart';
import '../controllers/order_controller.dart';
import '../models/order.dart';
import '../utils/money.dart';

class AdminOrdersScreen extends StatelessWidget {
  const AdminOrdersScreen({super.key});

  static const route = AppRoutes.adminOrders;

  @override
  Widget build(BuildContext context) {
    final orderCtrl = context.watch<OrderController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: orderCtrl.orders.isEmpty
          ? const Center(child: Text('No orders yet'))
          : ListView.builder(
              itemCount: orderCtrl.orders.length,
              itemBuilder: (_, i) {
                final o = orderCtrl.orders[i];
                return Card(
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: ListTile(
                    title: Text(o.id),
                    subtitle: Text(
                      '${o.customerName}  •  ${o.status.label}\n${pkr.format(o.total)}',
                    ),
                    isThreeLine: true,
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.orderConfirmation,
                      arguments: o.id,
                    ),
                    trailing: PopupMenuButton<OrderStatus>(
                      onSelected: (s) => orderCtrl.updateOrderStatus(o.id, s),
                      itemBuilder: (_) => OrderStatus.values
                          .map(
                            (s) => PopupMenuItem(value: s, child: Text(s.label)),
                          )
                          .toList(),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
