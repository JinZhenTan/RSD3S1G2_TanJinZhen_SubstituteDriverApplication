import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tr.dart';
import '../../../models/receipt.dart';
import '../services/receipt_exporter.dart';
import '../providers/account_provider.dart';

class ReceiptsScreen extends StatelessWidget {
  const ReceiptsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountProvider>();
    final receipts = account.receipts;

    return Scaffold(
      body: Column(
        children: [
          const ScreenHeader(eyebrow: 'ACCOUNT', title: 'Activity & receipts'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: account.refreshReceipts,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.navy,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Tr(
                              'Spent this month',
                              style: TextStyle(
                                color: Color(0xFF9AACC9),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'RM ${account.spentThisMonth.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppColors.heroAccent,
                                fontWeight: FontWeight.w700,
                                fontSize: 22,
                              ),
                            ),
                          ],
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            final messenger = ScaffoldMessenger.of(context);
                            if (receipts.isEmpty) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('No receipts to export yet.'),
                                ),
                              );
                              return;
                            }
                            if (value == 'csv') {
                              await ReceiptExporter.exportCsv(receipts);
                            } else {
                              await ReceiptExporter.exportPdf(receipts);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'csv',
                              child: Tr('Export as CSV'),
                            ),
                            PopupMenuItem(
                              value: 'pdf',
                              child: Tr('Export as PDF'),
                            ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.blue600,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Tr(
                              'Export ⤓',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
                    child: Tr(
                      'RECENT RECEIPTS',
                      style: AppStyles.mono.copyWith(fontSize: 9.5),
                    ),
                  ),
                  if (receipts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Tr(
                        'No receipts yet — they appear here after each paid '
                        'booking or car service.',
                        style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                      ),
                    ),
                  ...receipts.map((r) => _ReceiptRow(receipt: r)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.receipt});

  final Receipt receipt;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppStyles.card,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  receipt.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('d MMM, h:mm a').format(receipt.createdAt)} · '
                  'Receipt ${receipt.reference}',
                  style: const TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Text(
            'RM ${receipt.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
