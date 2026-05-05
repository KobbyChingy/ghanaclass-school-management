import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import removed: unused
import 'finance_providers.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';

class RevenueAndProfitCard extends ConsumerWidget {
  final int year;
  const RevenueAndProfitCard({super.key, required this.year});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revenueAsync = ref.watch(feeRevenueProvider(year));
    final expenseAsync = ref.watch(totalExpenseProvider(year));
    return revenueAsync.when(
      data: (revenue) => expenseAsync.when(
        data: (expense) {
          final profit = revenue - expense;
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Wrap(
                    spacing: 32,
                    runSpacing: 20,
                    direction: compact ? Axis.vertical : Axis.horizontal,
                    children: [
                      _stat('Total Revenue', revenue, Colors.green),
                      _stat('Total Expenses', expense, Colors.red),
                      _stat('Profit', profit, AppTheme.actionIndigo),
                    ],
                  ),
                );
              },
            ),
          );
        },
        loading: () => const CircularProgressIndicator(),
        error: (e, s) => Text('Error: $e'),
      ),
      loading: () => const CircularProgressIndicator(),
      error: (e, s) => Text('Error: $e'),
    );
  }

  Widget _stat(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('GH₵ ${value.toStringAsFixed(2)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
