import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/order.dart';
import '../utils/money.dart';

/// Receipt Service
/// Generates clean, professional black-and-white PDF payment receipts for confirmed Stripe orders,
/// and handles previewing, saving/downloading to device, printing, and sharing.
class ReceiptService {
  ReceiptService._();
  static final ReceiptService instance = ReceiptService._();
  static ReceiptService get to => instance;

  final Map<String, Uint8List> _pdfCache = {};

  /// Normalizes and cleans text to ASCII-compatible characters to ensure zero font crash on Helvetica
  static String cleanText(String input) {
    return input
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('•', '-')
        .replaceAll('…', '...')
        .replaceAll(RegExp(r'[^\x00-\x7F]'), '');
  }

  /// Pre-clears cached receipt if order details change
  void invalidateCache(String orderId) {
    _pdfCache.remove(orderId);
  }

  /// Generates or retrieves cached PDF bytes for a paid Stripe order
  Future<Uint8List> generateReceiptPdf(ShopOrder order) async {
    if (_pdfCache.containsKey(order.id)) {
      return _pdfCache[order.id]!;
    }
    final doc = buildReceiptDocument(order);
    final bytes = await doc.save();
    _pdfCache[order.id] = bytes;
    return bytes;
  }

  /// Builds a clean, professional black-and-white A4 PDF receipt document
  pw.Document buildReceiptDocument(ShopOrder order) {
    final pdf = pw.Document();

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
        ? cleanText(order.stripePaymentId!.trim())
        : 'Stripe Confirmed (Ref #${order.id})';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
          italic: pw.Font.helveticaOblique(),
          boldItalic: pw.Font.helveticaBoldOblique(),
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Text(
                  'S H O P H U B',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Center(
                child: pw.Text(
                  'Daraz-Style Online Marketplace  |  support@shophub.com  |  www.shophub.com',
                  style: const pw.TextStyle(
                    fontSize: 8.5,
                    color: PdfColors.black,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 1.5, color: PdfColors.black),
              pw.SizedBox(height: 6),

              // ==============================================================
              // 2. RECEIPT TITLE & PAYMENT STATUS BADGE
              // ==============================================================
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'PAYMENT RECEIPT',
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.black, width: 1.2),
                    ),
                    child: pw.Text(
                      'STATUS: PAID',
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 0.8, color: PdfColors.black),
              pw.SizedBox(height: 10),

              // ==============================================================
              // 3. ORDER & PAYMENT INFORMATION GRID
              // ==============================================================
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left Column: Order & Customer Details
                  pw.Expanded(
                    flex: 5,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildLabelValue('Order ID', '#${cleanText(order.id)}', isBold: true),
                        pw.SizedBox(height: 4),
                        _buildLabelValue('Payment Date', formattedDate),
                        pw.SizedBox(height: 4),
                        _buildLabelValue('Customer Name', cleanText(order.customerName),
                            isBold: true),
                        pw.SizedBox(height: 4),
                        _buildLabelValue(
                          'Customer Email',
                          (order.customerEmail != null &&
                                  order.customerEmail!.trim().isNotEmpty)
                              ? cleanText(order.customerEmail!)
                              : 'customer@shophub.com',
                        ),
                        pw.SizedBox(height: 4),
                        _buildLabelValue('Contact Phone', cleanText(order.phone)),
                        pw.SizedBox(height: 4),
                        _buildLabelValue('Shipping Address', cleanText(order.address)),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 24),
                  // Right Column: Payment & Stripe Details
                  pw.Expanded(
                    flex: 5,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildLabelValue('Payment Method', 'Stripe',
                            isBold: true),
                        pw.SizedBox(height: 4),
                        _buildLabelValue('Stripe Reference ID', stripeRef,
                            isMonospace: true),
                        pw.SizedBox(height: 4),
                        _buildLabelValue('Payment Status', 'Paid', isBold: true),
                        pw.SizedBox(height: 4),
                        _buildLabelValue('Currency', 'PKR (Pakistani Rupee)'),
                        pw.SizedBox(height: 4),
                        _buildLabelValue('Order Status', order.status.name.toUpperCase()),
                        pw.SizedBox(height: 4),
                        _buildLabelValue('Receipt Generated', printDate),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 14),

              // ==============================================================
              // 4. PURCHASED PRODUCTS TABLE
              // ==============================================================
              pw.Text(
                'PURCHASED PRODUCTS',
                style: pw.TextStyle(
                  fontSize: 10.5,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                border: const pw.TableBorder(
                  top: pw.BorderSide(color: PdfColors.black, width: 1.0),
                  bottom: pw.BorderSide(color: PdfColors.black, width: 1.0),
                  horizontalInside:
                      pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(5.0), // Product Name
                  1: pw.FlexColumnWidth(1.2), // Quantity
                  2: pw.FlexColumnWidth(2.2), // Unit Price
                  3: pw.FlexColumnWidth(2.4), // Line Subtotal
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.white,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            vertical: 5, horizontal: 4),
                        child: pw.Text(
                          'ITEM DESCRIPTION',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            vertical: 5, horizontal: 4),
                        child: pw.Text(
                          'QTY',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            vertical: 5, horizontal: 4),
                        child: pw.Text(
                          'UNIT PRICE',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            vertical: 5, horizontal: 4),
                        child: pw.Text(
                          'SUBTOTAL',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Table Rows
                  ...order.items.map(
                    (item) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              vertical: 5, horizontal: 4),
                          child: pw.Text(
                            cleanText(item.product.name),
                            style: const pw.TextStyle(fontSize: 8.5),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              vertical: 5, horizontal: 4),
                          child: pw.Text(
                            '${item.quantity}',
                            textAlign: pw.TextAlign.center,
                            style: const pw.TextStyle(fontSize: 8.5),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              vertical: 5, horizontal: 4),
                          child: pw.Text(
                            cleanText(pkr.format(item.product.price)),
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(fontSize: 8.5),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              vertical: 5, horizontal: 4),
                          child: pw.Text(
                            cleanText(pkr.format(item.lineTotal)),
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),

              // ==============================================================
              // 5. FINANCIAL BREAKDOWN & TOTAL
              // ==============================================================
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.SizedBox(
                    width: 250,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        _buildSummaryRow(
                          'Items Subtotal',
                          cleanText(pkr.format(rawSubtotal)),
                        ),
                        if (discount > 0) ...[
                          pw.SizedBox(height: 3),
                          _buildSummaryRow(
                            'Discount${order.couponCode != null ? ' (${cleanText(order.couponCode!)})' : ''}',
                            '- ${cleanText(pkr.format(discount))}',
                          ),
                        ],
                        pw.SizedBox(height: 3),
                        _buildSummaryRow(
                          'Delivery Charges',
                          delivery > 0 ? cleanText(pkr.format(delivery)) : 'FREE (Rs. 0)',
                        ),
                        pw.SizedBox(height: 6),
                        pw.Divider(thickness: 1.2, color: PdfColors.black),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment:
                              pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'TOTAL PAID',
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              cleanText(pkr.format(order.total)),
                              style: pw.TextStyle(
                                fontSize: 12.5,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment:
                              pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Payment Status',
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                            pw.Text(
                              'Paid (Stripe Verified)',
                              style: pw.TextStyle(
                                fontSize: 9.5,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Spacer(),

              // ==============================================================
              // 6. BARCODE & ORDER TRACKING IDENTIFIER
              // ==============================================================
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.code128(),
                      data: cleanText(order.id),
                      width: 140,
                      height: 30,
                      drawText: false,
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '* ${cleanText(order.id)} *',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              // ==============================================================
              // 7. THANK YOU NOTE & FOOTER
              // ==============================================================
              pw.Divider(thickness: 1.0, color: PdfColors.black),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'Thank you for shopping with ShopHub!',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  'This is an official, computer-generated payment receipt for your verified Stripe transaction.',
                  style: const pw.TextStyle(fontSize: 7.5),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'For inquiries or order tracking, visit My Profile > Customer Support or email support@shophub.com.',
                  style: const pw.TextStyle(fontSize: 7.5),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  /// Builds a key-value pair widget for the receipt meta section
  pw.Widget _buildLabelValue(
    String label,
    String value, {
    bool isBold = false,
    bool isMonospace = false,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 95,
          child: pw.Text(
            '$label:',
            style: const pw.TextStyle(
              fontSize: 8.5,
              color: PdfColors.black,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  /// Builds a line row for the financial breakdown section
  pw.Widget _buildSummaryRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.Text(
          value,
          style: const pw.TextStyle(fontSize: 9),
        ),
      ],
    );
  }

  /// Saves the receipt PDF to the device's local file storage (Downloads directory on Windows/Desktop)
  /// Returns the saved absolute file path on desktop/native, or null if shared via web/picker.
  Future<String?> saveReceiptToFile(ShopOrder order) async {
    final bytes = await generateReceiptPdf(order);
    final cleanId = order.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final filename = 'ShopHub_Receipt_$cleanId.pdf';

    if (!kIsWeb) {
      try {
        Directory? targetDir;
        if (Platform.isWindows) {
          final userProfile = Platform.environment['USERPROFILE'];
          if (userProfile != null) {
            final downloads = Directory('$userProfile\\Downloads');
            if (downloads.existsSync()) {
              targetDir = downloads;
            } else {
              final docs = Directory('$userProfile\\Documents');
              if (docs.existsSync()) targetDir = docs;
            }
          }
        }

        targetDir ??= Directory.current;
        final filePath = '${targetDir.path}${Platform.pathSeparator}$filename';
        final file = File(filePath);
        await file.writeAsBytes(bytes, flush: true);
        return filePath;
      } catch (e) {
        debugPrint('File system direct save failed, falling back to share/download dialog: $e');
      }
    }

    // Fallback or Web: trigger native file download / save prompt
    await Printing.sharePdf(
      bytes: bytes,
      filename: filename,
    );
    return null;
  }

  /// Opens the saved file in the OS default viewer (Explorer on Windows, open on macOS, xdg-open on Linux)
  Future<void> openFile(String filePath) async {
    if (!kIsWeb) {
      try {
        if (Platform.isWindows) {
          await Process.run('explorer.exe', [filePath]);
        } else if (Platform.isMacOS) {
          await Process.run('open', [filePath]);
        } else if (Platform.isLinux) {
          await Process.run('xdg-open', [filePath]);
        }
      } catch (e) {
        debugPrint('Could not open file $filePath: $e');
      }
    }
  }

  /// Opens the system native share sheet to share the generated PDF receipt
  Future<void> shareReceipt(ShopOrder order) async {
    final bytes = await generateReceiptPdf(order);
    final cleanId = order.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'ShopHub_Receipt_$cleanId.pdf',
    );
  }

  /// Opens the system print preview or Save-As-PDF dialog
  Future<void> printReceipt(ShopOrder order) async {
    final bytes = await generateReceiptPdf(order);
    final cleanId = order.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: 'ShopHub_Receipt_$cleanId.pdf',
    );
  }
}
