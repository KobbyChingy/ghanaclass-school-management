import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'finance_providers.dart';
// import removed: unused

class CashFlowForecastCard extends ConsumerWidget {
  final int year;
  const CashFlowForecastCard({super.key, required this.year});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomeAsync = ref.watch(monthlyIncomeProvider(year));
    final expenseAsync = ref.watch(monthlyExpensesProvider(year));
    return incomeAsync.when(
      data: (income) => expenseAsync.when(
        data: (expense) {
          double lastBalance = 0;
          final forecast = List.generate(12, (i) {
            final month = i + 1;
            final inc = income[month] ?? 0;
            final exp = expense[month] ?? 0;
            final bal = lastBalance + inc - exp;
            lastBalance = bal;
            return bal;
          });
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 16),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cash Flow Forecast', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: Row(
                      children: [
                        Expanded(
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: 12,
                            separatorBuilder: (context, index) => const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              final bal = forecast[i];
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    width: 18,
                                    height: (bal / 1000).clamp(0, 120),
                                    color: bal >= 0 ? Colors.green : Colors.red,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(bal.toStringAsFixed(0), style: const TextStyle(fontSize: 10)),
                                  Text(['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][i], style: const TextStyle(fontSize: 10)),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
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
