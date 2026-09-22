import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../controllers/auth_controller.dart';
import '../controllers/cart_controller.dart';
import '../controllers/order_controller.dart';
import '../core/widgets/app_button.dart';
import '../theme/colors.dart';
import '../utils/money.dart';
import '../widgets/stripe_payment_sheet.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  static const route = AppRoutes.checkout;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  String _payment = 'Cash on Delivery';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    final user = Get.find<AuthController>().currentUser;
    _name = TextEditingController(text: user?.name ?? '');
    _phone = TextEditingController(text: user?.phone ?? '');
    _address = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _handleCheckout(CartController cartCtrl, OrderController orderCtrl) async {
    if (!_form.currentState!.validate()) return;
    final authCtrl = Get.find<AuthController>();
    final tempOrderId = 'SH${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    if (_payment == 'Stripe') {
      // Open Stripe In-App Card Payment Sheet
      final stripeResult = await StripePaymentSheet.show(
        context: context,
        totalAmount: cartCtrl.cartTotal,
        customerName: _name.text.trim(),
        customerEmail: authCtrl.currentUser?.email ?? 'customer@shophub.com',
        orderId: tempOrderId,
      );

      if (stripeResult == null || !stripeResult.success) {
        // Dismissed or failed
        return;
      }

      setState(() => _isProcessing = true);

      final order = orderCtrl.placeOrder(
        userId: authCtrl.currentUser?.id,
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        paymentMethod: stripeResult.last4 != null && stripeResult.last4!.isNotEmpty
            ? 'Stripe (Card: **** ${stripeResult.last4})'
            : 'Stripe (Credit / Debit Card)',
        items: cartCtrl.cart,
        total: cartCtrl.cartTotal,
      );
      cartCtrl.clearCart();

      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.orderConfirmation,
        arguments: order.id,
      );
    } else {
      // Cash on Delivery
      setState(() => _isProcessing = true);

      final order = orderCtrl.placeOrder(
        userId: authCtrl.currentUser?.id,
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        paymentMethod: _payment,
        items: cartCtrl.cart,
        total: cartCtrl.cartTotal,
      );
      cartCtrl.clearCart();

      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.orderConfirmation,
        arguments: order.id,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartCtrl = Get.find<CartController>();
    final orderCtrl = Get.find<OrderController>();

    return Obx(() {
      if (cartCtrl.isEmpty && !_isProcessing) {
        return Scaffold(
          appBar: AppBar(title: const Text('Checkout')),
          body: const Center(child: Text('Your cart is empty')),
        );
      }

      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Shipping details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Phone number'),
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    (v == null || v.trim().length < 10) ? 'Enter a valid phone' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _address,
                decoration:
                    const InputDecoration(labelText: 'Complete delivery address'),
                maxLines: 2,
                validator: (v) =>
                    (v == null || v.trim().length < 8) ? 'Enter your address' : null,
              ),
              const SizedBox(height: 24),
              const Text('Order summary',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ...cartCtrl.cart.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      item.product.imageUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text(item.product.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('Qty ${item.quantity}'),
                  trailing: Text(
                    pkr.format(item.lineTotal),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const Divider(),
              Row(
                children: [
                  const Text('Total amount',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text(
                    pkr.format(cartCtrl.cartTotal),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: ShopColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Payment method',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),

              // Option 1: Cash on Delivery
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _payment == 'Cash on Delivery'
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: ShopColors.primary,
                ),
                title: const Text('Cash on Delivery (COD)'),
                subtitle: const Text('Pay with cash when your order arrives'),
                onTap: () => setState(() => _payment = 'Cash on Delivery'),
              ),

              const Divider(height: 1),

              // Option 2: Stripe Card Payment
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _payment == 'Stripe'
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: ShopColors.primary,
                ),
                title: Row(
                  children: [
                    const Text('Stripe (Card Payment)'),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF635BFF).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF635BFF).withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        'STRIPE',
                        style: TextStyle(
                          color: Color(0xFF635BFF),
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: const Text('Pay securely with Visa, Mastercard, or digital cards'),
                trailing: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.credit_card, size: 20, color: ShopColors.muted),
                    SizedBox(width: 4),
                    Icon(Icons.lock_outline, size: 16, color: ShopColors.muted),
                  ],
                ),
                onTap: () => setState(() => _payment = 'Stripe'),
              ),

              const SizedBox(height: 20),
              AppButton(
                text: _payment == 'Stripe'
                    ? 'Proceed to Pay with Stripe'
                    : 'Place Order (Cash on Delivery)',
                isLoading: _isProcessing,
                onPressed: _isProcessing ? null : () => _handleCheckout(cartCtrl, orderCtrl),
              ),
            ],
          ),
        ),
      );
    });
  }
}
