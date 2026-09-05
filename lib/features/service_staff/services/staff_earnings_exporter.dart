import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../models/car_service_request.dart';

// Real CSV / PDF export of a service partner's completed-job earnings log -
// same approach as the driver role's EarningsExporter, just for car-service
// jobs instead of substitute-driver bookings.
class StaffEarningsExporter {
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  static final NumberFormat _money =
      NumberFormat.currency(symbol: 'RM ', decimalDigits: 2);

  static Future<void> exportCsv(
    List<CarServiceRequest> jobs,
    DateTime month,
  ) async {
    final rows = <List<String>>[
      ['Date', 'Service', 'Pick-up address', 'Earnings (RM)'],
      for (final r in jobs)
        [
          _dateFormat.format(r.createdAt),
          r.serviceTypesLabel,
          r.pickupAddress,
          _amountOf(r).toStringAsFixed(2),
        ],
      ['', '', 'TOTAL', _total(jobs).toStringAsFixed(2)],
    ];

    final csv = rows
        .map((row) => row.map((f) => '"${f.replaceAll('"', '""')}"').join(','))
        .join('\r\n');

    try {
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/ganti_staff_earnings_'
        '${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsString(csv);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject:
              'Ganti service partner earnings — ${DateFormat('MMMM yyyy').format(month)}',
        ),
      );
    } catch (e) {
      print('StaffEarningsExporter.exportCsv error: $e');
    }
  }

  static Future<void> exportPdf(
    List<CarServiceRequest> jobs,
    DateTime month,
  ) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Ganti — Service Partner Earnings Log',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Text(DateFormat('MMMM yyyy').format(month)),
          pw.Text('Generated ${_dateFormat.format(DateTime.now())}'),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Service', 'Pick-up address', 'Earnings'],
            cellAlignments: {3: pw.Alignment.centerRight},
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
            data: [
              for (final r in jobs)
                [
                  _dateFormat.format(r.createdAt),
                  r.serviceTypesLabel,
                  r.pickupAddress,
                  _money.format(_amountOf(r)),
                ],
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Total: ${_money.format(_total(jobs))}',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    try {
      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: 'ganti_staff_earnings_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      print('StaffEarningsExporter.exportPdf error: $e');
    }
  }

  static double _amountOf(CarServiceRequest r) =>
      r.finalCost ?? r.costEstimateMin.toDouble();

  static double _total(List<CarServiceRequest> jobs) {
    double total = 0;
    for (final r in jobs) {
      total += _amountOf(r);
    }
    return total;
  }
}
