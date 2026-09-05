import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../models/booking.dart';

// Real CSV / PDF export of a driver's completed-trip earnings log, mirroring
// ReceiptExporter's approach for the passenger side (CLAUDE.md's requested
// "real CSV or PDF export, not just a placeholder button", applied to the
// driver role's own numbers instead of a passenger's spend).
class EarningsExporter {
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  static final NumberFormat _money =
      NumberFormat.currency(symbol: 'RM ', decimalDigits: 2);

  static Future<void> exportCsv(List<Booking> trips, DateTime month) async {
    final rows = <List<String>>[
      ['Date', 'Route', 'Service tier', 'Fare (RM)'],
      for (final b in trips)
        [
          _dateFormat.format(b.createdAt),
          b.routeLabel,
          b.serviceTier.label,
          (b.fareFinal ?? b.fareEstimate).toStringAsFixed(2),
        ],
      ['', '', 'TOTAL', _total(trips).toStringAsFixed(2)],
    ];

    final csv = rows
        .map((row) => row.map((f) => '"${f.replaceAll('"', '""')}"').join(','))
        .join('\r\n');

    try {
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/ganti_earnings_'
        '${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsString(csv);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: 'Ganti earnings log — ${DateFormat('MMMM yyyy').format(month)}',
        ),
      );
    } catch (e) {
      print('EarningsExporter.exportCsv error: $e');
    }
  }

  static Future<void> exportPdf(List<Booking> trips, DateTime month) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Ganti — Driver Earnings Log',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Text(DateFormat('MMMM yyyy').format(month)),
          pw.Text('Generated ${_dateFormat.format(DateTime.now())}'),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Route', 'Tier', 'Fare'],
            cellAlignments: {3: pw.Alignment.centerRight},
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
            data: [
              for (final b in trips)
                [
                  _dateFormat.format(b.createdAt),
                  b.routeLabel,
                  b.serviceTier.label,
                  _money.format(b.fareFinal ?? b.fareEstimate),
                ],
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Total: ${_money.format(_total(trips))}',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    try {
      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: 'ganti_earnings_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      print('EarningsExporter.exportPdf error: $e');
    }
  }

  static double _total(List<Booking> trips) {
    double total = 0;
    for (final b in trips) {
      total += b.fareFinal ?? b.fareEstimate;
    }
    return total;
  }
}
