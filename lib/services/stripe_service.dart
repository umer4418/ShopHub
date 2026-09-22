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

  /// Creates a PaymentIntent via Supabase Edge Function (with resilient fallback to Stripe API)
  Future<Map<String, dynamic>> createPaymentIntent({
    required double amount,
    String currency = StripeConfig.defaultCurrency,
    String customerName = '',
    String customerEmail = '',
    String orderId = '',
    Map<String, dynamic>? metadata,
  }) async {
    // 1. Attempt using Supabase Edge Function 'create-payment-intent'
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
          'metadata': ?metadata,
        },
      );

      if (response.status == 200 && response.data != null) {
        final data = response.data is String
            ? jsonDecode(response.data as String)
            : response.data as Map<String, dynamic>;
        if (data['clientSecret'] != null) {
          return data;
        }
      }
    } catch (e) {
      debugPrint('Supabase Edge Function unavailable, using direct Stripe API: $e');
    }

    // 2. Direct Stripe API Fallback (for instant offline/test mode without deployment hurdles)
    return await _createPaymentIntentDirect(
      amount: amount,
      currency: currency,
      customerName: customerName,
      customerEmail: customerEmail,
      orderId: orderId,
      metadata: metadata,
    );
  }

  /// Direct Stripe REST API PaymentIntent creation
  Future<Map<String, dynamic>> _createPaymentIntentDirect({
    required double amount,
    required String currency,
    required String customerName,
    required String customerEmail,
    required String orderId,
    Map<String, dynamic>? metadata,
  }) async {
    final amountSmallestUnit = (amount * 100).round();

    final body = {
      'amount': amountSmallestUnit.toString(),
      'currency': currency.toLowerCase(),
      'payment_method_types[]': 'card',
      'description': 'ShopHub Order $orderId'.trim(),
      if (customerEmail.isNotEmpty) 'receipt_email': customerEmail,
      'metadata[order_id]': orderId,
      'metadata[customer_name]': customerName,
    };

    if (metadata != null) {
      metadata.forEach((k, v) => body['metadata[$k]'] = v.toString());
    }

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
      return {
        'clientSecret': data['client_secret'],
        'paymentIntentId': data['id'],
        'amount': data['amount'],
        'currency': data['currency'],
        'status': data['status'],
      };
    } else {
      final errorMsg = data['error']?['message'] ?? 'Failed to create payment intent';
      throw Exception(errorMsg);
    }
  }

  /// Confirms payment by creating a PaymentMethod and confirming the PaymentIntent
  Future<StripePaymentResult> confirmPayment({
    required String clientSecret,
    required StripeCardInput card,
  }) async {
    try {
      // Step 1: Create PaymentMethod using Publishable Key
      final pmBody = {
        'type': 'card',
        'card[number]': card.cleanCardNumber,
        'card[exp_month]': card.expMonth.toString(),
        'card[exp_year]': card.expYear.toString(),
        'card[cvc]': card.cvc,
        if (card.cardholderName.isNotEmpty)
          'billing_details[name]': card.cardholderName,
      };

      final pmRes = await http.post(
        Uri.parse('$_stripeApiBase/payment_methods'),
        headers: {
          'Authorization': 'Bearer ${StripeConfig.publishableKey}',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: pmBody,
      );

      final pmData = jsonDecode(pmRes.body) as Map<String, dynamic>;
      if (pmRes.statusCode != 200 && pmRes.statusCode != 201) {
        final err = pmData['error']?['message'] ?? 'Invalid card details';
        return StripePaymentResult.failed(err.toString());
      }

      final paymentMethodId = pmData['id'] as String;
      final cardInfo = pmData['card'] as Map<String, dynamic>?;
      final last4 = cardInfo?['last4']?.toString() ?? '';
      final brand = cardInfo?['brand']?.toString() ?? 'card';

      // Step 2: Extract PaymentIntent ID from client_secret (e.g. pi_12345_secret_abc -> pi_12345)
      final piId = clientSecret.split('_secret_').first;

      // Step 3: Confirm PaymentIntent
      final confirmRes = await http.post(
        Uri.parse('$_stripeApiBase/payment_intents/$piId/confirm'),
        headers: {
          'Authorization': 'Bearer ${StripeConfig.publishableKey}',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'payment_method': paymentMethodId,
        },
      );

      final confirmData = jsonDecode(confirmRes.body) as Map<String, dynamic>;

      if (confirmRes.statusCode == 200 || confirmRes.statusCode == 201) {
        final status = confirmData['status'] as String?;
        if (status == 'succeeded' || status == 'requires_capture') {
          return StripePaymentResult.success(
            paymentIntentId: piId,
            last4: last4,
            brand: brand,
          );
        } else if (status == 'requires_action') {
          // 3DS Authentication required
          return StripePaymentResult.failed(
            '3D Secure verification is required. Please use standard test card.',
          );
        } else {
          return StripePaymentResult.failed('Payment status: $status');
        }
      } else {
        final err = confirmData['error']?['message'] ?? 'Payment failed to confirm';
        return StripePaymentResult.failed(err.toString());
      }
    } catch (e) {
      return StripePaymentResult.failed('Payment processing error: $e');
    }
  }

  /// Full-service convenience method to process an order payment in one call
  Future<StripePaymentResult> processOrderPayment({
    required double amount,
    required StripeCardInput card,
    String currency = StripeConfig.defaultCurrency,
    String customerName = '',
    String customerEmail = '',
    String orderId = '',
  }) async {
    try {
      final pi = await createPaymentIntent(
        amount: amount,
        currency: currency,
        customerName: customerName,
        customerEmail: customerEmail,
        orderId: orderId,
      );

      final clientSecret = pi['clientSecret'] as String?;
      if (clientSecret == null) {
        return StripePaymentResult.failed('Could not generate Stripe payment intent.');
      }

      return await confirmPayment(
        clientSecret: clientSecret,
        card: card,
      );
    } catch (e) {
      return StripePaymentResult.failed(e.toString().replaceFirst('Exception: ', ''));
    }
  }
}
