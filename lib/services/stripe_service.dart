import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/stripe_config.dart';

/// Represents card payment details entered by customer
class StripeCardInput {
  final String cardNumber;
  final int expMonth;
  final int expYear;
  final String cvc;
  final String cardholderName;

  const StripeCardInput({
    required this.cardNumber,
    required this.expMonth,
    required this.expYear,
    required this.cvc,
    required this.cardholderName,
  });

  String get cleanCardNumber => cardNumber.replaceAll(RegExp(r'\s+|-'), '');
}

/// Result of Stripe payment operation
class StripePaymentResult {
  final bool success;
  final String? paymentIntentId;
  final String? errorMessage;
  final String? last4;
  final String? brand;

  const StripePaymentResult._({
    required this.success,
    this.paymentIntentId,
    this.errorMessage,
    this.last4,
    this.brand,
  });

  factory StripePaymentResult.success({
    required String paymentIntentId,
    String? last4,
    String? brand,
  }) =>
      StripePaymentResult._(
        success: true,
        paymentIntentId: paymentIntentId,
        last4: last4,
        brand: brand,
      );

  factory StripePaymentResult.failed(String errorMessage) =>
      StripePaymentResult._(
        success: false,
        errorMessage: errorMessage,
      );
}

/// Service handling Stripe PaymentIntents and Card Confirmations
class StripeService {
  static const String _stripeApiBase = 'https://api.stripe.com/v1';

  /// Maps entered card number to standard Stripe test PaymentMethod identifier
  String _getTestPaymentMethod(String cardNumber) {
    final clean = cardNumber.replaceAll(RegExp(r'\s+|-'), '');
    if (clean.endsWith('0002')) return 'pm_card_chargeDeclined';
    if (clean.endsWith('0999')) return 'pm_card_chargeDeclinedInsufficientFunds';
    if (clean.startsWith('34') || clean.startsWith('37')) return 'pm_card_amex';
    if (clean.startsWith('5')) return 'pm_card_mastercard';
    return 'pm_card_visa';
  }

  /// Detects card brand name from number
  String _detectBrand(String cardNumber) {
    final clean = cardNumber.replaceAll(RegExp(r'\s+|-'), '');
    if (clean.startsWith('4')) return 'Visa';
    if (clean.startsWith('5')) return 'Mastercard';
    if (clean.startsWith('34') || clean.startsWith('37')) return 'American Express';
    return 'Card';
  }

  /// Full-service method to process an order payment with Stripe
  Future<StripePaymentResult> processOrderPayment({
    required double amount,
    required StripeCardInput card,
    String currency = StripeConfig.defaultCurrency,
    String customerName = '',
    String customerEmail = '',
    String orderId = '',
  }) async {
    final cleanCard = card.cleanCardNumber;
    final last4 = cleanCard.length >= 4 ? cleanCard.substring(cleanCard.length - 4) : '4242';
    final brand = _detectBrand(cleanCard);
    final testPaymentMethod = _getTestPaymentMethod(cleanCard);

    // 1. First Attempt: Call Supabase Edge Function 'create-payment-intent'
    try {
      final client = Supabase.instance.client;
      final response = await client.functions.invoke(
        'create-payment-intent',
        body: {
          'amount': amount,
          'currency': currency,
          'customerName': customerName,
          'customerEmail': customerEmail,
          'orderId': orderId,
          'paymentMethod': testPaymentMethod,
          'confirm': true,
        },
      );

      if (response.status == 200 && response.data != null) {
        final data = response.data is String
            ? jsonDecode(response.data as String)
            : response.data as Map<String, dynamic>;

        final status = data['status'] as String?;
        if (status == 'succeeded' || status == 'requires_capture') {
          return StripePaymentResult.success(
            paymentIntentId: data['paymentIntentId']?.toString() ?? '',
            last4: last4,
            brand: brand,
          );
        } else if (data['error'] != null) {
          return StripePaymentResult.failed(data['error'].toString());
        }
      }
    } catch (e) {
      debugPrint('Supabase Edge Function not deployed or unavailable, using direct Stripe API: $e');
    }

    // 2. Direct Stripe API Execution (fallback using test secret key)
    try {
      final amountSmallestUnit = (amount * 100).round();

      final body = {
        'amount': amountSmallestUnit.toString(),
        'currency': currency.toLowerCase(),
        'payment_method': testPaymentMethod,
        'confirm': 'true',
        'return_url': 'https://shophub.com/checkout',
        'description': 'ShopHub Order $orderId'.trim(),
        if (customerEmail.isNotEmpty) 'receipt_email': customerEmail,
        'metadata[order_id]': orderId,
        'metadata[customer_name]': customerName,
        'metadata[card_last4]': last4,
        'metadata[card_brand]': brand,
      };

      final res = await http.post(
        Uri.parse('$_stripeApiBase/payment_intents'),
        headers: {
          'Authorization': 'Bearer ${StripeConfig.secretKey}',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );

      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 || res.statusCode == 201) {
        final status = data['status'] as String?;
        if (status == 'succeeded' || status == 'requires_capture') {
          return StripePaymentResult.success(
            paymentIntentId: data['id']?.toString() ?? '',
            last4: last4,
            brand: brand,
          );
        } else if (status == 'requires_action') {
          return StripePaymentResult.failed(
            '3D Secure verification required. Please test with standard test card.',
          );
        } else {
          return StripePaymentResult.failed('Payment status: $status');
        }
      } else {
        final err = data['error']?['message'] ?? 'Payment failed. Please check card details.';
        return StripePaymentResult.failed(err.toString());
      }
    } catch (e) {
      return StripePaymentResult.failed('Payment error: $e');
    }
  }
}
