import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shophub/data/mock_catalog.dart';
import 'package:shophub/models/cart_item.dart';
import 'package:shophub/models/order.dart';
import 'package:shophub/services/receipt_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReceiptService PDF Generation Tests', () {
    late ShopOrder sampleStripeOrder;

    setUp(() {
      sampleStripeOrder = ShopOrder(
        id: 'SH-9901',
        userId: 'test-user-123',
        customerName: 'Ayesha Khan',
        customerEmail: 'ayesha.khan@example.com',
        phone: '03219876543',
        address: 'House 42, Street 8, F-7/2, Islamabad',
        paymentMethod: 'Stripe (Card: **** 4242)',
        items: [
          CartItem(
            product: MockCatalog.products[0], // Pro Series Smart Watch AMOLED, 4999
            quantity: 2,
          ),
          CartItem(
            product: MockCatalog.products[1], // Mechanical RGB Gaming Keyboard, 5000
            quantity: 1,
          ),
        ],
        total: 14498,
        createdAt: DateTime(2026, 9, 30, 14, 30),
        status: OrderStatus.placed,
        couponCode: 'SAVE500',
        discountAmount: 500,
        stripePaymentId: 'pi_3PtestStripePaymentIntentId9901',
        paymentStatus: 'Paid',
        deliveryFee: 0,
      );
    });

    test('generates non-empty valid PDF byte array for Stripe order', () async {
      final bytes = await ReceiptService.to.generateReceiptPdf(sampleStripeOrder);

      expect(bytes, isNotNull);
      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);

      // PDF files always begin with '%PDF-' magic bytes (0x25, 0x50, 0x44, 0x46, 0x2D)
      final header = String.fromCharCodes(bytes.take(5));
      expect(header, equals('%PDF-'));
    });

    test('buildReceiptDocument constructs valid pw.Document with pages', () {
      final doc = ReceiptService.to.buildReceiptDocument(sampleStripeOrder);

      expect(doc, isNotNull);
      expect(doc.document.pdfPageList.pages.isNotEmpty, isTrue);
    });

    test('ShopOrder helper getters correctly identify paid Stripe orders', () {
      expect(sampleStripeOrder.isStripePayment, isTrue);
      expect(sampleStripeOrder.isPaid, isTrue);
      expect(sampleStripeOrder.canGenerateReceipt, isTrue);

      final codOrder = sampleStripeOrder.copyWith(
        paymentMethod: 'Cash on Delivery',
        stripePaymentId: null,
        paymentStatus: 'Pending',
      );
      expect(codOrder.isStripePayment, isFalse);
      expect(codOrder.canGenerateReceipt, isFalse);

      final failedStripeOrder = sampleStripeOrder.copyWith(
        paymentStatus: 'Failed',
      );
      expect(failedStripeOrder.isPaid, isFalse);
      expect(failedStripeOrder.canGenerateReceipt, isFalse);
    });
  });
}
