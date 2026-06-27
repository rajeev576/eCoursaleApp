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
              // Line items (one row per product in the order).
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1)},
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _cell('Item', bold: true),
                      _cell('Amount', bold: true, alignRight: true),
                    ],
                  ),
                  ...(_lines(data)).map((ln) {
                    final m = Map<String, dynamic>.from(ln);
                    return pw.TableRow(children: [
                      _cell((m['title'] ?? '').toString()),
                      _cell(_money((m['paid'] ?? '0').toString()), alignRight: true),
                    ]);
                  }),
                ],
              ),

              pw.SizedBox(height: 14),
              row('Subtotal', _money(g('gross_total'))),
              if ((double.tryParse(g('coupon_total')) ?? 0) > 0)
                row('Coupon${g('coupon_code').isNotEmpty ? ' (${g('coupon_code')})' : ''}', '- ${_money(g('coupon_total'))}'),
              if ((double.tryParse(g('coins_total')) ?? 0) > 0)
                row('Coins discount', '- ${_money(g('coins_total'))}'),
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

  static List _lines(Map<String, dynamic> data) {
    final l = data['lines'];
    return l is List ? l : const [];
  }

  static pw.Widget _cell(String text, {bool bold = false, bool alignRight = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(8),
        child: pw.Text(text,
            textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: 11)),
      );

  static String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day}/${d.month}/${d.year}';
  }
}
