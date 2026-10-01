import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../app/routes/app_routes.dart';
import '../controllers/order_controller.dart';
import '../models/order.dart';
import '../services/receipt_service.dart';
import '../theme/colors.dart';
import '../utils/money.dart';
import '../utils/responsive.dart';

class OrderConfirmationScreen extends StatelessWidget {
  const OrderConfirmationScreen({super.key});

  static const route = AppRoutes.orderConfirmation;

  @override
  Widget build(BuildContext context) {
    final rawArgs = ModalRoute.of(context)?.settings.arguments ?? Get.arguments;
    final String id = rawArgs is ShopOrder ? rawArgs.id : (rawArgs is String ? rawArgs : '');
    final orderCtrl = Get.find<OrderController>();

    return Obx(() {
      final order = orderCtrl.getOrderById(id);

      if (order == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Order details')),
          body: const Center(child: Text('Order not found')),
        );
      }

      final date = DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt);

      final isSmall = Responsive.isSmallMobile(context);

      return Scaffold(
        appBar: AppBar(title: const Text('Order confirmation')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Responsive.maxMobileContentWidth),
            child: ListView(
              padding: Responsive.screenPadding(context, horizontal: 16, vertical: 16),
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
            Text('Name: ${order.customerName}'),
            if (order.customerEmail != null && order.customerEmail!.isNotEmpty)
              Text('Email: ${order.customerEmail}'),
            Text('Phone: ${order.phone}'),
            Text('Address: ${order.address}'),
            Text('Payment Method: ${order.paymentMethod}'),
            if (order.stripePaymentId != null &&
                order.stripePaymentId!.isNotEmpty)
              Text('Stripe Ref: ${order.stripePaymentId}'),
            Text(
              'Payment Status: ${order.paymentStatus ?? (order.isPaid ? 'Paid' : 'Pending')}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: order.isPaid ? const Color(0xFF059669) : Colors.orange,
              ),
            ),
            if (order.canGenerateReceipt) ...[
              const SizedBox(height: 20),
              Container(
                key: const ValueKey('receipt_card_section'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12),
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.receipt_long,
                              color: Colors.black87, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Payment Receipt',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                'Confirmed via Stripe • Official Black & White Receipt',
                                style: TextStyle(
                                    fontSize: 12, color: ShopColors.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        key: const ValueKey('view_receipt_button'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text(
                          'View Receipt',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.receipt,
                            arguments: order,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const ValueKey('download_receipt_button'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black87,
                              side: const BorderSide(color: Colors.black26),
                              padding: EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: isSmall ? 4 : 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.download_rounded, size: 16),
                            label: Text(
                              isSmall ? 'Download' : 'Save / Download',
                              style: TextStyle(fontSize: isSmall ? 11 : 12),
                            ),
                            onPressed: () async {
                              final path = await ReceiptService.to
                                  .saveReceiptToFile(order);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(path != null
                                        ? 'Receipt saved to $path'
                                        : 'Receipt saved / downloaded.'),
                                    backgroundColor: const Color(0xFF059669),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        SizedBox(width: isSmall ? 6 : 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const ValueKey('share_receipt_button'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black87,
                              side: const BorderSide(color: Colors.black26),
                              padding: EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: isSmall ? 4 : 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.share_outlined, size: 16),
                            label: Text(
                              isSmall ? 'Share' : 'Share Receipt',
                              style: TextStyle(fontSize: isSmall ? 11 : 12),
                            ),
                            onPressed: () =>
                                ReceiptService.to.shareReceipt(order),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context, AppRoutes.home, (_) => false),
              child: const Text('Continue shopping'),
            ),
          ],
        ),
      ),
    ),
  );
    });
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
