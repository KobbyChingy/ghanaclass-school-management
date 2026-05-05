import 'package:drift/drift.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';


class FinanceAnalyticsService {
  final AppDatabase _database;

  FinanceAnalyticsService(this._database);

  AppDatabase get database => _database;

  Future<Map<int, double>> getMonthlyIncome(int year) async {
    final start = DateTime(year, 1, 1);
    final end = DateTime(year + 1, 1, 1);
    final payments = await (_database.select(_database.payments)
      ..where((p) => p.paymentDate.year.equals(year))).get();
    final shopSales = await (_database.select(_database.shopSales)
      ..where((s) => s.soldAt.isBiggerOrEqualValue(start) & s.soldAt.isSmallerThanValue(end) & s.status.equals('completed'))).get();

    final result = <int, double>{};
    for (var i = 1; i <= 12; i++) {
      result[i] = 0.0;
    }

    for (var p in payments) {
      final month = p.paymentDate.month;
      result[month] = (result[month] ?? 0) + p.amountPaid;
    }
    for (final sale in shopSales) {
      final month = sale.soldAt.month;
      result[month] = (result[month] ?? 0) + sale.totalAmount;
    }
    return result;
  }

  Future<Map<int, double>> getMonthlyExpenses(int year) async {
    // 1. Petty Cash / Misc Expenses
    final expenses = await (_database.select(_database.expenses)
      ..where((e) => e.expenseDate.year.equals(year))).get();

    // 2. Institutional Expenses (New)
    final instExpenses = await (_database.select(_database.institutionalExpenses)
      ..where((e) => e.expenseDate.year.equals(year))).get();

    // 3. Payroll Records (New)
    final payrolls = await (_database.select(_database.payrollRecords)
      ..where((p) => p.year.equals(year))).get();

    final result = <int, double>{};
    for (var i = 1; i <= 12; i++) {
      result[i] = 0.0;
    }

    for (var e in expenses) {
      final month = e.expenseDate.month;
      result[month] = (result[month] ?? 0) + e.amount;
    }
    for (var e in instExpenses) {
      final month = e.expenseDate.month;
      result[month] = (result[month] ?? 0) + e.amount;
    }
    for (var p in payrolls) {
      final month = p.month;
      result[month] = (result[month] ?? 0) + p.netSalary;
    }
    return result;
  }

  Future<Map<String, double>> getExpenseCategoryTotals(int year) async {
    final expenses = await (_database.select(_database.expenses)
      ..where((e) => e.expenseDate.year.equals(year))).get();
    
    final instExpenses = await (_database.select(_database.institutionalExpenses)
      ..where((e) => e.expenseDate.year.equals(year))).get();

    final payrolls = await (_database.select(_database.payrollRecords)
      ..where((p) => p.year.equals(year))).get();

    final result = <String, double>{};
    
    // Aggregate all
    for (var e in expenses) {
      result[e.category] = (result[e.category] ?? 0) + e.amount;
    }
    for (var e in instExpenses) {
      result[e.category] = (result[e.category] ?? 0) + e.amount;
    }
    
    // Add Payroll as a category
    if (payrolls.isNotEmpty) {
      final totalPayroll = payrolls.fold<double>(0, (sum, p) => sum + p.netSalary);
      result['Staff Payroll'] = (result['Staff Payroll'] ?? 0) + totalPayroll;
    }

    return result;
  }
}
