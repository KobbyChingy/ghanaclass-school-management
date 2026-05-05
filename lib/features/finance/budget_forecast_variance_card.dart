import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'finance_analytics_providers.dart';

class BudgetForecastVarianceCard extends ConsumerWidget {
  const BudgetForecastVarianceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = DateTime.now().year;
    final incomeAsync = ref.watch(monthlyIncomeProvider(year));
    final expenseAsync = ref.watch(monthlyExpensesProvider(year));
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Budget Forecasting & Variance Analysis',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            incomeAsync.when(
              data: (income) => expenseAsync.when(
                data: (expense) {
                  // Dummy budget values for illustration
                  final budgetedIncome = 60000.0;
                  final budgetedExpense = 40000.0;
                  final actualIncome = income.values.fold(0.0, (a, b) => a + b);
                  final actualExpense = expense.values.fold(0.0, (a, b) => a + b);
                  final incomeVariance = actualIncome - budgetedIncome;
                  final expenseVariance = actualExpense - budgetedExpense;
                  return Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.trending_up, color: Colors.green),
                        title: const Text('Income'),
                        subtitle: Text('Budgeted: GHS $budgetedIncome | Actual: GHS ${actualIncome.toStringAsFixed(2)} | Variance: GHS ${incomeVariance.toStringAsFixed(2)}'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.trending_down, color: Colors.red),
                        title: const Text('Expense'),
                        subtitle: Text('Budgeted: GHS $budgetedExpense | Actual: GHS ${actualExpense.toStringAsFixed(2)} | Variance: GHS ${expenseVariance.toStringAsFixed(2)}'),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Text('Error: $e'),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }
}
