import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'finance_analytics_service.dart';

class AlertThreshold {
  final String message;
  final String suggestion;
  final bool isCritical;
  AlertThreshold({required this.message, required this.suggestion, this.isCritical = false});
}

final alertsThresholdsProvider = FutureProvider<List<AlertThreshold>>((ref) async {
  final service = ref.watch(financeAnalyticsServiceProvider);
  final now = DateTime.now();
  final year = now.year;
  final income = await service.getMonthlyIncome(year);
  final expenses = await service.getMonthlyExpenses(year);
  final alerts = <AlertThreshold>[];

  // Example thresholds
  const double minBalanceThreshold = 1000.0;
  const double maxExpenseGrowth = 0.25; // 25% month-over-month

  // 1. Low Net Balance
  final totalIncome = income.values.fold(0.0, (a, b) => a + b);
  final totalExpense = expenses.values.fold(0.0, (a, b) => a + b);
  final netBalance = totalIncome - totalExpense;
  if (netBalance < minBalanceThreshold) {
    alerts.add(AlertThreshold(
      message: 'Net balance is low (GH₵${netBalance.toStringAsFixed(2)})',
      suggestion: 'Review expenses and increase income.',
      isCritical: netBalance < 0,
    ));
  }

  // 2. Expense Growth
  double? lastMonth;
  for (int i = 1; i <= 12; i++) {
    final current = expenses[i] ?? 0.0;
    if (lastMonth != null && lastMonth > 0) {
      final growth = (current - lastMonth) / lastMonth;
      if (growth > maxExpenseGrowth) {
        alerts.add(AlertThreshold(
          message: 'Expenses grew by ${(growth * 100).toStringAsFixed(1)}% in ${_monthShortName(i)}',
          suggestion: 'Investigate unusual expense increases.',
          isCritical: growth > 0.5,
        ));
      }
    }
    lastMonth = current;
  }

  return alerts;
});
final financeAnalyticsServiceProvider = Provider<FinanceAnalyticsService>((ref) {
  final db = ref.watch(databaseProvider);
  return FinanceAnalyticsService(db);
});

final monthlyIncomeProvider = FutureProvider.family<Map<int, double>, int>((ref, year) async {
  return ref.watch(financeAnalyticsServiceProvider).getMonthlyIncome(year);
});

final monthlyExpensesProvider = FutureProvider.family<Map<int, double>, int>((ref, year) async {
  return ref.watch(financeAnalyticsServiceProvider).getMonthlyExpenses(year);
});


final expenseCategoryTotalsProvider = FutureProvider.family<Map<String, double>, int>((ref, year) async {
  return ref.watch(financeAnalyticsServiceProvider).getExpenseCategoryTotals(year);
});

class PayrollTrendPoint {
  final String label;
  final double amount;
  PayrollTrendPoint(this.label, this.amount);
}

final staffPayrollTrendsProvider = FutureProvider<List<PayrollTrendPoint>>((ref) async {
  final service = ref.watch(financeAnalyticsServiceProvider);
  final now = DateTime.now();
  final year = now.year;
  final db = service.database;
  final payrolls = await (db.select(db.payrollRecords)
    ..where((p) => p.year.equals(year))).get();
  // Group by month
  final Map<int, double> monthly = {for (var i = 1; i <= 12; i++) i: 0.0};
  for (var p in payrolls) {
    monthly[p.month] = (monthly[p.month] ?? 0) + p.netSalary;
  }
  return [
    for (var i = 1; i <= 12; i++)
      PayrollTrendPoint(
        _monthShortName(i),
        monthly[i] ?? 0.0,
      ),
  ];
});

String _monthShortName(int month) {
  const names = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return names[month];
}
