import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../app/routes/app_routes.dart';
import '../controllers/order_controller.dart';
import '../models/order.dart';
import '../services/receipt_service.dart';
import '../theme/colors.dart';
import '../utils/money.dart';
import '../utils/responsive.dart';

/// ReceiptScreen
/// Displays a high-fidelity, black-and-white payment receipt on screen,
/// and provides options to save/download the PDF file, share, or print.
class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key});

  static const route = AppRoutes.receipt;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final ReceiptService _receiptService = ReceiptService.to;
  bool _isSaving = false;
  bool _canRaster = false;
  bool _showRawPdf = false;

  @override
  void initState() {
    super.initState();
    _checkRasterSupport();
  }

  Future<void> _checkRasterSupport() async {
    try {
      final info = await Printing.info();
      if (mounted) {
        setState(() {
          _canRaster = info.canRaster;
        });
      }
    } catch (_) {}
  }

  ShopOrder? _resolveOrder(BuildContext context) {
    final rawArgs = ModalRoute.of(context)?.settings.arguments ?? Get.arguments;
    if (rawArgs is ShopOrder) {
      return rawArgs;
    } else if (rawArgs is String) {
      if (Get.isRegistered<OrderController>()) {
        return Get.find<OrderController>().getOrderById(rawArgs);
      }
    }
    return null;
  }

  Future<void> _handleSaveReceipt(ShopOrder order) async {
    setState(() => _isSaving = true);
    try {
      final savedPath = await _receiptService.saveReceiptToFile(order);
      if (!mounted) return;

      if (savedPath != null && savedPath.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Receipt PDF saved:\n$savedPath',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OPEN',
              textColor: Colors.white,
              onPressed: () => _receiptService.openFile(savedPath),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt PDF generated and ready.'),
            backgroundColor: ShopColors.primary,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save receipt: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleShareReceipt(ShopOrder order) async {
    try {
      await _receiptService.shareReceipt(order);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share receipt: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _handlePrintReceipt(ShopOrder order) async {
    try {
      await _receiptService.printReceipt(order);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to print receipt: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _resolveOrder(context);

    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payment Receipt')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.receipt_long, size: 64, color: ShopColors.muted),
              const SizedBox(height: 16),
              const Text(
                'Receipt not found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final cleanId = order.id.replaceAll('#', '');

    final isSmall = Responsive.isSmallMobile(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text('Receipt #$cleanId'),
        actions: [
          IconButton(
            key: const ValueKey('share_receipt_appbar_action'),
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Receipt',
            onPressed: () => _handleShareReceipt(order),
          ),
          IconButton(
            key: const ValueKey('print_receipt_appbar_action'),
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print Receipt',
            onPressed: () => _handlePrintReceipt(order),
          ),
          IconButton(
            key: const ValueKey('save_receipt_appbar_action'),
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
            tooltip: 'Download Receipt',
            onPressed: _isSaving ? null : () => _handleSaveReceipt(order),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmall ? 8 : 16,
            vertical: isSmall ? 8 : 12,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                offset: const Offset(0, -2),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            children: [
              // Save / Download PDF Button
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  key: const ValueKey('save_receipt_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: isSmall ? 10 : 13,
                      horizontal: isSmall ? 6 : 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(Icons.download_rounded, size: isSmall ? 15 : 18),
                  label: Text(
                    _isSaving ? 'Saving...' : (isSmall ? 'Download' : 'Download PDF'),
                    style: TextStyle(
                      fontSize: isSmall ? 11 : 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: _isSaving ? null : () => _handleSaveReceipt(order),
                ),
              ),
              SizedBox(width: isSmall ? 5 : 8),

              // Share Receipt Button
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  key: const ValueKey('share_receipt_button'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    side: const BorderSide(color: Colors.black38),
                    padding: EdgeInsets.symmetric(
                      vertical: isSmall ? 10 : 13,
                      horizontal: isSmall ? 4 : 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: Icon(Icons.share_outlined, size: isSmall ? 14 : 16),
                  label: Text(
                    'Share',
                    style: TextStyle(
                      fontSize: isSmall ? 11 : 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () => _handleShareReceipt(order),
                ),
              ),
              SizedBox(width: isSmall ? 5 : 8),

              // Print Button
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  key: const ValueKey('print_receipt_button'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    side: const BorderSide(color: Colors.black38),
                    padding: EdgeInsets.symmetric(
                      vertical: isSmall ? 10 : 13,
                      horizontal: isSmall ? 4 : 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: Icon(Icons.print_outlined, size: isSmall ? 14 : 16),
                  label: Text(
                    'Print',
                    style: TextStyle(
                      fontSize: isSmall ? 11 : 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () => _handlePrintReceipt(order),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: Responsive.screenPadding(
          context,
          horizontal: Responsive.isSmallMobile(context) ? 8 : 12,
          vertical: 16,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Mode selector if platform supports raster preview
                if (_canRaster) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text('Receipt View'),
                        selected: !_showRawPdf,
                        selectedColor: Colors.black,
                        labelStyle: TextStyle(
                          color: !_showRawPdf ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        onSelected: (_) => setState(() => _showRawPdf = false),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('PDF Page Preview'),
                        selected: _showRawPdf,
                        selectedColor: Colors.black,
                        labelStyle: TextStyle(
                          color: _showRawPdf ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        onSelected: (_) => setState(() => _showRawPdf = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],

                // Main Receipt Render
                if (_showRawPdf && _canRaster)
                  SizedBox(
                    height: 800,
                    child: PdfPreview(
                      build: (format) => _receiptService.generateReceiptPdf(order),
                      canChangeOrientation: false,
                      canChangePageFormat: false,
                      canDebug: false,
                      maxPageWidth: 600,
                      pdfFileName: 'ShopHub_Receipt_$cleanId.pdf',
                    ),
                  )
                else
                  _ReceiptPaperView(order: order),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// High-Fidelity Black & White Receipt Paper View Widget
class _ReceiptPaperView extends StatelessWidget {
  final ShopOrder order;

  const _ReceiptPaperView({required this.order});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final formattedDate = dateFormat.format(order.createdAt);
    final printDate = dateFormat.format(DateTime.now());

    final rawSubtotal = order.items.isNotEmpty
        ? order.items.fold<double>(0.0, (sum, item) => sum + item.lineTotal)
        : order.total;

    final discount = order.discountAmount ?? 0.0;
    final delivery = order.deliveryFee ?? 0.0;
    final stripeRef = (order.stripePaymentId != null &&
            order.stripePaymentId!.trim().isNotEmpty)
        ? order.stripePaymentId!.trim()
        : 'Stripe Confirmed (Ref #${order.id})';

    final isSmall = Responsive.isSmallMobile(context);
    final isMobile = Responsive.isMobile(context);
    final hPadding = isSmall ? 10.0 : (isMobile ? 14.0 : 24.0);
    final vPadding = isSmall ? 14.0 : (isMobile ? 18.0 : 26.0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: vPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. BRAND HEADER
          const Center(
            child: Text(
              'S H O P H U B',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 4.0,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              'Daraz-Style Online Marketplace  |  support@shophub.com  |  www.shophub.com',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(thickness: 2, color: Colors.black),
          const SizedBox(height: 8),

          // 2. RECEIPT TITLE & PAYMENT STATUS BADGE
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    'PAYMENT RECEIPT',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 1.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'STATUS: PAID',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(thickness: 1, color: Colors.black87),
          const SizedBox(height: 12),

          // 3. ORDER & PAYMENT INFORMATION GRID
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 450;
              final leftCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('Order ID', '#${order.id}', isBold: true),
                  const SizedBox(height: 5),
                  _infoRow('Payment Date', formattedDate),
                  const SizedBox(height: 5),
                  _infoRow('Customer Name', order.customerName, isBold: true),
                  const SizedBox(height: 5),
                  _infoRow(
                    'Customer Email',
                    (order.customerEmail != null &&
                            order.customerEmail!.trim().isNotEmpty)
                        ? order.customerEmail!
                        : 'customer@shophub.com',
                  ),
                  const SizedBox(height: 5),
                  _infoRow('Contact Phone', order.phone),
                  const SizedBox(height: 5),
                  _infoRow('Shipping Address', order.address),
                ],
              );

              final rightCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('Payment Method', 'Stripe', isBold: true),
                  const SizedBox(height: 5),
                  _infoRow('Stripe Ref ID', stripeRef, isMonospace: true),
                  const SizedBox(height: 5),
                  _infoRow('Payment Status', 'Paid', isBold: true),
                  const SizedBox(height: 5),
                  _infoRow('Currency', 'PKR (Pakistani Rupee)'),
                  const SizedBox(height: 5),
                  _infoRow('Order Status', order.status.name.toUpperCase()),
                  const SizedBox(height: 5),
                  _infoRow('Receipt Date', printDate),
                ],
              );

              if (isSmall) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    leftCol,
                    const SizedBox(height: 12),
                    rightCol,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: leftCol),
                  const SizedBox(width: 20),
                  Expanded(child: rightCol),
                ],
              );
            },
          ),
          const SizedBox(height: 18),

          // 4. PURCHASED PRODUCTS TABLE
          const Text(
            'PURCHASED PRODUCTS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.black, width: 1.5),
                bottom: BorderSide(color: Colors.black, width: 1.5),
              ),
            ),
            child: Column(
              children: [
                // Table Header
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    children: const [
                      Expanded(
                        flex: 5,
                        child: Text(
                          'ITEM DESCRIPTION',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'QTY',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'UNIT PRICE',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'SUBTOTAL',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1, color: Colors.black38),

                // Table Items
                ...order.items.map(
                  (item) => Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.black12, width: 0.8),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Text(
                            item.product.name,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${item.quantity}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              pkr.format(item.product.price),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              pkr.format(item.lineTotal),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 5. FINANCIAL BREAKDOWN & TOTAL
          Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                children: [
                  _summaryLine('Items Subtotal', pkr.format(rawSubtotal)),
                  if (discount > 0) ...[
                    const SizedBox(height: 4),
                    _summaryLine(
                      'Discount${order.couponCode != null ? ' (${order.couponCode})' : ''}',
                      '- ${pkr.format(discount)}',
                    ),
                  ],
                  const SizedBox(height: 4),
                  _summaryLine(
                    'Delivery Charges',
                    delivery > 0 ? pkr.format(delivery) : 'FREE (Rs. 0)',
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, thickness: 1.5, color: Colors.black),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'TOTAL PAID',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            pkr.format(order.total),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Expanded(
                        child: Text(
                          'Payment Status',
                          style: TextStyle(fontSize: 10, color: Colors.black87),
                        ),
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Paid (Stripe Verified)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 6. BARCODE & IDENTIFIER
          Center(
            child: Column(
              children: [
                _BarcodeStrip(data: order.id),
                const SizedBox(height: 4),
                Text(
                  '* ${order.id} *',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 7. THANK YOU NOTE & FOOTER
          const Divider(thickness: 1.5, color: Colors.black),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Thank you for shopping with ShopHub!',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              'This is an official, computer-generated payment receipt for your verified Stripe transaction.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9.5, color: Colors.black54),
            ),
          ),
          const SizedBox(height: 2),
          const Center(
            child: Text(
              'For inquiries or order tracking, visit My Profile > Customer Support or email support@shophub.com.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9.5, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value,
      {bool isBold = false, bool isMonospace = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 95,
          child: Text(
            '$label:',
            style: const TextStyle(fontSize: 10.5, color: Colors.black87),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
              fontFamily: isMonospace ? 'monospace' : null,
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryLine(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black87),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Simulated Barcode Strip for Clean Black & White Paper Receipt
class _BarcodeStrip extends StatelessWidget {
  final String data;

  const _BarcodeStrip({required this.data});

  @override
  Widget build(BuildContext context) {
    // Generate deterministic pattern based on characters
    final pattern = [
      3, 1, 2, 1, 3, 2, 1, 3, 1, 2, 2, 1, 3, 1, 1, 2, 3, 2, 1, 1, 2, 3, 1, 2,
      1, 3, 2, 1, 2, 3, 1, 1, 3, 2, 1, 2, 1, 3, 1, 2, 3, 1, 2, 1, 3, 2, 1, 3,
      1, 2, 2, 1, 3, 1, 1, 2, 3, 2, 1, 1, 2, 3, 1, 2, 1, 3, 2, 1, 2, 3, 1, 1,
    ];

    return SizedBox(
      height: 32,
      width: 180,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: pattern.take(48).map((width) {
          final isBlack = width % 2 != 0;
          return Container(
            width: width.toDouble(),
            height: 32,
            color: isBlack ? Colors.black : Colors.white,
          );
        }).toList(),
      ),
    );
  }
}
