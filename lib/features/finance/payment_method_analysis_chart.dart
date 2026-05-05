import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'finance_providers.dart';
// import removed: unused

class PaymentMethodAnalysisChart extends ConsumerWidget {
  final int year;
  const PaymentMethodAnalysisChart({super.key, required this.year});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(paymentsProvider);
    return paymentsAsync.when(
      data: (payments) {
        final byMethod = <String, double>{};
        for (final p in payments) {
          if (p.paymentDate.year == year) {
            final method = p.paymentMethod.toUpperCase();
            byMethod[method] = (byMethod[method] ?? 0) + p.amountPaid;
          }
        }
        final total = byMethod.values.fold(0.0, (a, b) => a + b);
        final colors = [Colors.green, Colors.blue, Colors.orange, Colors.purple, Colors.red, Colors.teal];
        int i = 0;
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 16),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Payment Method Analysis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 220,
                  child: PieChart(PieChartData(
                    sections: byMethod.entries.map((e) {
                      final color = colors[i++ % colors.length];
                      return PieChartSectionData(
                        value: e.value,
                        title: total <= 0 ? '0%' : '${((e.value / total) * 100).toStringAsFixed(0)}%',
                        color: color,
                        radius: 80,
                        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      );
                    }).toList(),
                  )),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  children: byMethod.keys.map((method) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 12, height: 12, color: colors[byMethod.keys.toList().indexOf(method) % colors.length]),
                      const SizedBox(width: 4),
                      Text(method, style: const TextStyle(fontSize: 12)),
                    ],
                  )).toList(),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }
}
