import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/routes/app_routes.dart';
import '../controllers/auth_controller.dart';
import '../controllers/cart_controller.dart';
import '../controllers/order_controller.dart';
import '../theme/colors.dart';
import '../utils/money.dart';

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

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthController>().currentUser;
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

  @override
  Widget build(BuildContext context) {
    final cartCtrl = context.watch<CartController>();
    final orderCtrl = context.read<OrderController>();

    if (cartCtrl.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: const Center(child: Text('Your cart is empty.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Delivery details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Customer name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number'),
              validator: (v) =>
                  (v == null || v.trim().length < 10) ? 'Enter a valid phone' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _address,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Delivery address'),
              validator: (v) =>
                  (v == null || v.trim().length < 8) ? 'Enter a full address' : null,
            ),
            const SizedBox(height: 20),
            const Text('Selected products',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...cartCtrl.cart.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _payment == 'Cash on Delivery'
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: ShopColors.primary,
              ),
              title: const Text('Cash on Delivery'),
              subtitle: const Text('Pay when your order arrives'),
              onTap: () => setState(() => _payment = 'Cash on Delivery'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (!_form.currentState!.validate()) return;
                  final order = orderCtrl.placeOrder(
                    name: _name.text.trim(),
                    phone: _phone.text.trim(),
                    address: _address.text.trim(),
                    paymentMethod: _payment,
                    items: cartCtrl.cart,
                    total: cartCtrl.cartTotal,
                  );
                  cartCtrl.clearCart();
                  Navigator.pushReplacementNamed(
                    context,
                    AppRoutes.orderConfirmation,
                    arguments: order.id,
                  );
                },
                child: const Text('Place Order'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
