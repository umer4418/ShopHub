import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/stripe_config.dart';
import '../core/widgets/app_button.dart';
import '../services/stripe_service.dart';
import '../theme/colors.dart';
import '../utils/money.dart';

/// Modal bottom sheet for entering and processing Stripe card payments
class StripePaymentSheet extends StatefulWidget {
  final double totalAmount;
  final String customerName;
  final String customerEmail;
  final String orderId;

  const StripePaymentSheet({
    super.key,
    required this.totalAmount,
    required this.customerName,
    required this.customerEmail,
    required this.orderId,
  });

  /// Static helper to show the payment sheet
  static Future<StripePaymentResult?> show({
    required BuildContext context,
    required double totalAmount,
    required String customerName,
    required String customerEmail,
    required String orderId,
  }) {
    return showModalBottomSheet<StripePaymentResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StripePaymentSheet(
        totalAmount: totalAmount,
        customerName: customerName,
        customerEmail: customerEmail,
        orderId: orderId,
      ),
    );
  }

  @override
  State<StripePaymentSheet> createState() => _StripePaymentSheetState();
}

class _StripePaymentSheetState extends State<StripePaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumber = TextEditingController();
  final _expiry = TextEditingController();
  final _cvc = TextEditingController();
  late final TextEditingController _cardholder;

  final StripeService _stripeService = StripeService();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _cardholder = TextEditingController(text: widget.customerName.isNotEmpty ? widget.customerName : StripeConfig.testCardholder);
  }

  @override
  void dispose() {
    _cardNumber.dispose();
    _expiry.dispose();
    _cvc.dispose();
    _cardholder.dispose();
    super.dispose();
  }

  void _fillTestCard() {
    setState(() {
      _cardNumber.text = StripeConfig.testCardNumber;
      _expiry.text = StripeConfig.testCardExpiry;
      _cvc.text = StripeConfig.testCardCvc;
      _errorMessage = null;
    });
  }

  IconData _getCardBrandIcon(String number) {
    final clean = number.replaceAll(RegExp(r'\s+'), '');
    if (clean.startsWith('4')) return Icons.credit_card;
    if (clean.startsWith('5')) return Icons.credit_card;
    if (clean.startsWith('3')) return Icons.credit_card;
    return Icons.payment;
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final expParts = _expiry.text.split('/');
    final expMonth = int.tryParse(expParts[0].trim()) ?? 12;
    var expYear = int.tryParse(expParts.length > 1 ? expParts[1].trim() : '30') ?? 30;
    if (expYear < 100) expYear += 2000;

    final cardInput = StripeCardInput(
      cardNumber: _cardNumber.text,
      expMonth: expMonth,
      expYear: expYear,
      cvc: _cvc.text.trim(),
      cardholderName: _cardholder.text.trim(),
    );

    final result = await _stripeService.processOrderPayment(
      amount: widget.totalAmount,
      card: cardInput,
      customerName: widget.customerName,
      customerEmail: widget.customerEmail,
      orderId: widget.orderId,
    );

    if (!mounted) return;

    if (result.success) {
      Navigator.of(context).pop(result);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result.errorMessage ?? 'Payment failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF635BFF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'stripe',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Secure Card Payment',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total to Pay:', style: TextStyle(color: ShopColors.muted)),
                  Text(
                    pkr.format(widget.totalAmount),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: ShopColors.primary,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Test card quick button
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _fillTestCard,
                icon: const Icon(Icons.flash_on, size: 16, color: ShopColors.primary),
                label: const Text(
                  'Auto-Fill Stripe Test Card (4242...)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: ShopColors.primary,
                  side: const BorderSide(color: ShopColors.primary),
                ),
              ),
              const SizedBox(height: 14),

              // Card Number
              TextFormField(
                controller: _cardNumber,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(16),
                  _CardNumberInputFormatter(),
                ],
                decoration: InputDecoration(
                  labelText: 'Card Number',
                  hintText: '4242 4242 4242 4242',
                  prefixIcon: Icon(_getCardBrandIcon(_cardNumber.text)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) {
                  if (v == null || v.replaceAll(' ', '').length < 15) {
                    return 'Enter a valid 16-digit card number';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),

              // Expiry & CVC Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _expiry,
                      keyboardType: TextInputType.datetime,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                        _CardExpiryInputFormatter(),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Expires (MM/YY)',
                        hintText: '12/34',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (v) {
                        if (v == null || !v.contains('/') || v.length < 5) {
                          return 'MM/YY required';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _cvc,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration: InputDecoration(
                        labelText: 'CVC / CVV',
                        hintText: '123',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (v) {
                        if (v == null || v.length < 3) return '3-4 digits';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Cardholder Name
              TextFormField(
                controller: _cardholder,
                decoration: InputDecoration(
                  labelText: 'Cardholder Name',
                  hintText: 'John Doe',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter cardholder name' : null,
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),

              // Pay Button
              AppButton(
                text: 'Pay ${pkr.format(widget.totalAmount)}',
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _submitPayment,
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Payments are encrypted and processed by Stripe.',
                  style: TextStyle(color: ShopColors.muted, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Formatter to insert space every 4 digits: 1234 5678 9012 3456
class _CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i + 1) % 4 == 0 && i + 1 != text.length) {
        buffer.write(' ');
      }
    }
    final formatted = buffer.toString();
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Formatter for MM/YY expiry input
class _CardExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll('/', '');
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if (i == 1 && text.length > 2) {
        buffer.write('/');
      }
    }
    final formatted = buffer.toString();
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
