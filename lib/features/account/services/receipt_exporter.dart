import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../models/receipt.dart';

class ReceiptExporter {
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  static final NumberFormat _money =
      NumberFormat.currency(symbol: 'RM ', decimalDigits: 2);

  static Future<void> exportCsv(List<Receipt> receipts) async {
    final rows = <List<String>>[
      ['Reference', 'Date', 'Description', 'Amount (RM)'],
      for (final r in receipts)
        [
          r.reference,
          _dateFormat.format(r.createdAt),
          r.description,
          r.amount.toStringAsFixed(2),
        ],
      ['', '', 'TOTAL', _total(receipts).toStringAsFixed(2)],
    ];

    final csv = rows
        .map((row) =>
            row.map((f) => '"${f.replaceAll('"', '""')}"').join(','))
        .join('\r\n');

    try {
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/ganti_receipts_'
        '${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsString(csv);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: 'Ganti receipts export',
        ),
      );
    } catch (e) {
      print('exportCsv error: $e');
    }
  }

  static Future<void> exportPdf(List<Receipt> receipts) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Ganti — Receipts & Expense Summary',
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Text('Generated ${_dateFormat.format(DateTime.now())}'),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ['Reference', 'Date', 'Description', 'Amount'],
            cellAlignments: {3: pw.Alignment.centerRight},
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.blueGrey100),
            data: [
              for (final r in receipts)
                [
                  r.reference,
                  _dateFormat.format(r.createdAt),
                  r.description,
                  _money.format(r.amount),
                ],
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Total: ${_money.format(_total(receipts))}',
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    try {
      await Printing.sharePdf(
        bytes: await doc.save(),
        filename:
            'ganti_receipts_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      print('exportPdf error: $e');
    }
  }

  static double _total(List<Receipt> receipts) {
    double total = 0;
    for (final r in receipts) {
      total += r.amount;
    }
    return total;
  }
}
