import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'finance_providers.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';

class FeeCollectionRateCard extends ConsumerWidget {
  final int year;
  const FeeCollectionRateCard({super.key, required this.year});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerAsync = ref.watch(feesLedgerProvider);
    return ledgerAsync.when(
      data: (ledger) {
        final byClass = <String, List<double>>{};
        for (final row in ledger) {
          if (row.className == null) continue;
          if (!byClass.containsKey(row.className!)) {
            byClass[row.className!] = [0, 0]; // [paid, total]
          }
          byClass[row.className!]![0] += row.totalPaid;
          byClass[row.className!]![1] += row.totalFees;
        }
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 16),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Fee Collection Rate by Class', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                ...byClass.entries.map((e) {
                  final rate = e.value[1] > 0 ? (e.value[0] / e.value[1]) * 100 : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600))),
                        Text('${rate.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, color: rate >= 90 ? Colors.green : (rate >= 70 ? Colors.orange : Colors.red))),
                        const SizedBox(width: 12),
                        Text('GH₵ ${e.value[0].toStringAsFixed(2)} / ${e.value[1].toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.textMuted)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (e, s) => Text('Error: $e'),
    );
  }
}
