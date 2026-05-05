import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'finance_providers.dart';
// import removed: unused

class ExpenseTrendsChart extends ConsumerWidget {
  final int year;
  const ExpenseTrendsChart({super.key, required this.year});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesProvider);
    return expensesAsync.when(
      data: (expenses) {
        final byMonthCategory = <int, Map<String, double>>{};
        for (final e in expenses.where((e) => e.expenseDate.year == year)) {
          final m = e.expenseDate.month;
          byMonthCategory[m] = byMonthCategory[m] ?? {};
          byMonthCategory[m]![e.category] = (byMonthCategory[m]![e.category] ?? 0) + e.amount;
        }
        final categories = byMonthCategory.values.expand((m) => m.keys).toSet().toList();
        categories.sort();
        final lines = categories.map((cat) {
          final spots = List.generate(12, (i) {
            final month = i + 1;
            return FlSpot(month.toDouble(), byMonthCategory[month]?[cat] ?? 0);
          });
          return LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.primaries[categories.indexOf(cat) % Colors.primaries.length],
            barWidth: 3,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          );
        }).toList();
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 16),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Expense Breakdown Over Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 250,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(show: true, drawVerticalLine: false),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, meta) {
                              const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                              if (val.toInt() >= 1 && val.toInt() <= 12) {
                                return Text(months[val.toInt()], style: const TextStyle(fontSize: 10));
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 60)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: lines,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  children: categories.map((cat) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 12, height: 12, color: Colors.primaries[categories.indexOf(cat) % Colors.primaries.length]),
                      const SizedBox(width: 4),
                      Text(cat, style: const TextStyle(fontSize: 12)),
                    ],
                  )).toList(),
                ),
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
