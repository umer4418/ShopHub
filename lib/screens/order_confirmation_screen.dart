import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app/routes/app_routes.dart';
import '../controllers/order_controller.dart';
import '../models/order.dart';
import '../theme/colors.dart';
import '../utils/money.dart';

class OrderConfirmationScreen extends StatelessWidget {
  const OrderConfirmationScreen({super.key});

  static const route = AppRoutes.orderConfirmation;

  @override
  Widget build(BuildContext context) {
    final id = ModalRoute.of(context)!.settings.arguments as String;
    final orderCtrl = context.watch<OrderController>();
    final order = orderCtrl.getOrderById(id);

    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order details')),
        body: const Center(child: Text('Order not found')),
      );
    }

    final date = DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt);

    return Scaffold(
      appBar: AppBar(title: const Text('Order confirmation')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ShopColors.primarySoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.check_circle, color: ShopColors.success, size: 56),
                const SizedBox(height: 8),
                const Text(
                  'Thank you! Your order is placed.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text('Order ID  $id',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(date,
                    style: const TextStyle(color: ShopColors.muted, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Status',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _StatusTracker(status: order.status),
          const SizedBox(height: 20),
          const Text('Products',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ...order.items.map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.product.name),
              subtitle: Text('Qty ${item.quantity}'),
              trailing: Text(pkr.format(item.lineTotal)),
            ),
          ),
          const Divider(),
          Row(
            children: [
              const Text('Total amount',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(
                pkr.format(order.total),
                style: const TextStyle(
                    color: ShopColors.primary, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Customer information',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(order.customerName),
          Text(order.phone),
          Text(order.address),
          Text('Payment: ${order.paymentMethod}'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context, AppRoutes.home, (_) => false),
            child: const Text('Continue shopping'),
          ),
        ],
      ),
    );
  }
}

class _StatusTracker extends StatelessWidget {
  const _StatusTracker({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final steps = OrderStatus.values;
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: i <= status.step
                        ? ShopColors.primary
                        : ShopColors.border,
                    child: Icon(
                      i <= status.step ? Icons.check : Icons.circle,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                  if (i < steps.length - 1)
                    Container(
                      width: 2,
                      height: 28,
                      color: i < status.step
                          ? ShopColors.primary
                          : ShopColors.border,
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  steps[i].label,
                  style: TextStyle(
                    fontWeight: i == status.step
                        ? FontWeight.w800
                        : FontWeight.w500,
                    color: i <= status.step ? ShopColors.text : ShopColors.muted,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
