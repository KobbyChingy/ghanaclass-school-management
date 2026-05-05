import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'finance_analytics_providers.dart';

class CustomExportCard extends ConsumerWidget {
  const CustomExportCard({super.key});

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
              'Custom Export',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Export Finance Data (CSV)'),
              onPressed: () async {
                final snackBar = ScaffoldMessenger.of(context);
                final income = incomeAsync.value;
                final expense = expenseAsync.value;
                final categories = categoriesAsync.value;
                if (income == null || expense == null || categories == null) {
                  snackBar.showSnackBar(const SnackBar(content: Text('Data not ready. Please wait.')));
                  return;
                }
                final csv = _generateCsv(income, expense, categories);
                final dir = await getApplicationDocumentsDirectory();
                final file = File('${dir.path}/finance_export_$year.csv');
                await file.writeAsString(csv);
                snackBar.showSnackBar(SnackBar(content: Text('Exported to ${file.path}')));
              },
            ),
          ],
        ),
      ),
    );
  }

  String _generateCsv(Map<int, double> income, Map<int, double> expense, Map<String, double> categories) {
    final buffer = StringBuffer();
    buffer.writeln('Month,Income,Expense');
    for (int i = 1; i <= 12; i++) {
      buffer.writeln('$i,${income[i] ?? 0},${expense[i] ?? 0}');
    }
    buffer.writeln('\nCategory,Total');
    categories.forEach((k, v) {
      buffer.writeln('$k,$v');
    });
    return buffer.toString();
  }
}
