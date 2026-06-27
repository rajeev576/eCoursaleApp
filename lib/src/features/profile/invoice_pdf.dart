import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/models.dart';

/// Builds a native invoice PDF that mirrors the web invoice (same invoice number,
/// item, amounts, discounts, transaction details) and opens the system
/// share/save/print sheet — so a student can save the invoice from the app just
/// like downloading it from the web.
class InvoicePdf {
  static String _money(String v) {
    final d = double.tryParse(v) ?? 0;
    return '₹${d.toStringAsFixed(0)}';
  }

  static Future<void> shareForOrder(Order order) async {
    final inv = order.invoice;
    final data = inv?.data ?? <String, dynamic>{};
    String g(String k) => (data[k] ?? '').toString();

    // Use a Unicode font so ₹ renders correctly.
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (ctx) {
          pw.Widget row(String label, String value, {bool bold = false}) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(label, style: pw.TextStyle(color: PdfColors.grey700)),
                    pw.Text(value, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
                  ],
                ),
              );

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text(g('school_name'),
                        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    if (g('school_address').isNotEmpty)
                      pw.Text(g('school_address'), style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    if (g('school_email').isNotEmpty)
                      pw.Text(g('school_email'), style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ]),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    pw.Text('INVOICE', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.Text(g('invoice_no'), style: const pw.TextStyle(fontSize: 11)),
                  ]),
                ],
              ),
              pw.Divider(height: 28),

              // Meta
              row('Date', _fmtDate(g('date'))),
              row('Status', g('status')),
              if (g('order_id').isNotEmpty) row('Order ID', g('order_id')),
              if (g('transaction_id').isNotEmpty) row('Transaction ID', g('transaction_id')),
              if (g('payment_gateway').isNotEmpty) row('Payment via', g('payment_gateway')),

              pw.SizedBox(height: 18),
              pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(g('item_title')),
              ),

              pw.SizedBox(height: 18),
              row('Price', _money(g('gross_amount'))),
              if ((double.tryParse(g('coupon_discount')) ?? 0) > 0)
                row('Coupon${g('coupon_code').isNotEmpty ? ' (${g('coupon_code')})' : ''}', '- ${_money(g('coupon_discount'))}'),
              if ((double.tryParse(g('coins_discount')) ?? 0) > 0)
                row('Coins (${g('coins_used')})', '- ${_money(g('coins_discount'))}'),
              pw.Divider(),
              row('Amount Paid', _money(g('amount_paid')), bold: true),

              pw.Spacer(),
              pw.Center(
                child: pw.Text('This is a computer-generated invoice.',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              ),
            ],
          );
        },
      ),
    );

    final bytes = await doc.save();
    await Printing.sharePdf(bytes: bytes, filename: '${g('invoice_no').isEmpty ? 'invoice' : g('invoice_no')}.pdf');
  }

  static String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day}/${d.month}/${d.year}';
  }
}
