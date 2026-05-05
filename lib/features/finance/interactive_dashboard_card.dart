import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'finance_analytics_providers.dart';

class InteractiveDashboardCard extends ConsumerWidget {
  const InteractiveDashboardCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = DateTime.now().year;
    final incomeAsync = ref.watch(monthlyIncomeProvider(year));
    final expenseAsync = ref.watch(monthlyExpensesProvider(year));
    final categoriesAsync = ref.watch(expenseCategoryTotalsProvider(year));

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Interactive Dashboard',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            incomeAsync.when(
              data: (income) => expenseAsync.when(
                data: (expense) => categoriesAsync.when(
                  data: (categories) {
                    return _buildDashboard(context, income, expense, categories);
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (e, s) => Text('Error: $e'),
                ),
                loading: () => const CircularProgressIndicator(),
                error: (e, s) => Text('Error: $e'),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (e, s) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, Map<int, double> income, Map<int, double> expense, Map<String, double> categories) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _showDetail(context, 'Income', income),
                child: _dashboardTile('Income', income.values.fold(0.0, (a, b) => a + b), Colors.green),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: () => _showDetail(context, 'Expense', expense),
                child: _dashboardTile('Expense', expense.values.fold(0.0, (a, b) => a + b), Colors.red),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => _showCategoryDetail(context, categories),
          child: _dashboardTile('Categories', categories.values.fold(0.0, (a, b) => a + b), Colors.blue),
        ),
      ],
    );
  }

  Widget _dashboardTile(String title, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).toInt()),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('GH₵ ${value.toStringAsFixed(2)}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context, String title, Map<int, double> data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$title Details'),
        content: SizedBox(
          width: 300,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (int i = 1; i <= 12; i++)
                ListTile(
                  title: Text('Month $i'),
                  trailing: Text('GH₵ ${(data[i] ?? 0).toStringAsFixed(2)}'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showCategoryDetail(BuildContext context, Map<String, double> categories) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Category Details'),
        content: SizedBox(
          width: 300,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final entry in categories.entries)
                ListTile(
                  title: Text(entry.key),
                  trailing: Text('GH₵ ${entry.value.toStringAsFixed(2)}'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        ],
      ),
    );
  }
}
