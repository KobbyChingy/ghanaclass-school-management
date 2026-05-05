import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'finance_service.dart';
import 'finance_providers.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';

class TopDebtorsCard extends ConsumerWidget {
  const TopDebtorsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerAsync = ref.watch(feesLedgerProvider);
    return ledgerAsync.when(
      data: (ledger) {
        final byStudent = <int, StudentFeesLedgerRow>{};
        final balances = <int, double>{};

        for (final row in ledger) {
          if (row.balance <= 0.01) continue;
          byStudent.putIfAbsent(row.studentId, () => row);
          balances.update(row.studentId, (value) => value + row.balance, ifAbsent: () => row.balance);
        }

        final top = byStudent.values.toList()
          ..sort((a, b) => (balances[b.studentId] ?? 0).compareTo(balances[a.studentId] ?? 0));
        final limitedTop = top.take(10).toList(growable: false);
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 16),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Top Debtors', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                ...limitedTop.map((row) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text('${row.firstName} ${row.lastName} (${row.className ?? '-'})', style: const TextStyle(fontWeight: FontWeight.w600))),
                      Text('GH₵ ${(balances[row.studentId] ?? 0).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    ],
                  ),
                )),
                if (top.isEmpty)
                  const Text('No outstanding balances.', style: TextStyle(color: AppTheme.textMuted)),
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
