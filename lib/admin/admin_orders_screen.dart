import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../controllers/order_controller.dart';
import '../models/order.dart';
import '../utils/money.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  static const route = AppRoutes.adminOrders;

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isRegistered<OrderController>()) {
        Get.find<OrderController>().refreshOrders();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final orderCtrl = Get.find<OrderController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Orders',
            onPressed: () => orderCtrl.refreshOrders(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => orderCtrl.refreshOrders(),
        child: Obx(
          () => orderCtrl.orders.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
                    Center(child: Text('No orders yet')),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
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
        ),
      ),
    );
  }
}
