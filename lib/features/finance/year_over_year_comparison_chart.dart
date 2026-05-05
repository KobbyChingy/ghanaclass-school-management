import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'finance_providers.dart';

class YearOverYearComparisonChart extends ConsumerWidget {
  const YearOverYearComparisonChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomeAsync = ref.watch(yearlyIncomeProvider);
    final expenseAsync = ref.watch(yearlyExpenseProvider);
    return incomeAsync.when(
      data: (income) => expenseAsync.when(
        data: (expense) {
          final years = {...income.keys, ...expense.keys}.toList()..sort();
          final incomeSpots = years.map((y) => FlSpot(y.toDouble(), income[y] ?? 0)).toList();
          final expenseSpots = years.map((y) => FlSpot(y.toDouble(), expense[y] ?? 0)).toList();
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 16),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Year-over-Year Income & Expenses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                              getTitlesWidget: (val, meta) => Text(val.toInt().toString()),
                            ),
                          ),
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 60)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: incomeSpots,
                            isCurved: true,
                            color: Colors.green,
                            barWidth: 4,
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(show: true, color: Colors.green.withAlpha(30)),
                          ),
                          LineChartBarData(
                            spots: expenseSpots,
                            isCurved: true,
                            color: Colors.red,
                            barWidth: 4,
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(show: true, color: Colors.red.withAlpha(30)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
}
