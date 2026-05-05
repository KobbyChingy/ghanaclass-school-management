
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'finance_service.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';

class FinanceExpenseEntry {
  final String category;
  final String? description;
  final double amount;
  final DateTime expenseDate;
  final bool isInstitutional;

  const FinanceExpenseEntry({
    required this.category,
    required this.description,
    required this.amount,
    required this.expenseDate,
    required this.isInstitutional,
  });
}

final financeServiceProvider = Provider<FinanceService>((ref) {
  final db = ref.watch(databaseProvider);
  return FinanceService(db);
});

final monthlyIncomeProvider = FutureProvider.family<Map<int, double>, int>((ref, year) async {
  final payments = await ref.watch(financeServiceProvider).getAllPayments();
  final db = ref.watch(databaseProvider);
  final start = DateTime(year, 1, 1);
  final end = DateTime(year + 1, 1, 1);
  final shopSales = await (db.select(db.shopSales)
        ..where((s) => s.soldAt.isBiggerOrEqualValue(start) & s.soldAt.isSmallerThanValue(end) & s.status.equals('completed')))
      .get();
  final Map<int, double> monthly = {};
  for (final p in payments) {
    if (p.paymentDate.year == year) {
      final m = p.paymentDate.month;
      monthly[m] = (monthly[m] ?? 0) + p.amountPaid;
    }
  }
  for (final sale in shopSales) {
    final m = sale.soldAt.month;
    monthly[m] = (monthly[m] ?? 0) + sale.totalAmount;
  }
  return monthly;
});

final monthlyExpensesProvider = FutureProvider.family<Map<int, double>, int>((ref, year) async {
  final service = ref.watch(financeServiceProvider);
  final expenses = await service.getAllExpenses();
  final institutionalExpenses = await service.getInstitutionalExpenses();
  final Map<int, double> monthly = {};
  for (final e in expenses) {
    if (e.expenseDate.year == year) {
      final m = e.expenseDate.month;
      monthly[m] = (monthly[m] ?? 0) + e.amount;
    }
  }
  for (final e in institutionalExpenses) {
    if (e.expenseDate.year == year) {
      final m = e.expenseDate.month;
      monthly[m] = (monthly[m] ?? 0) + e.amount;
    }
  }
  return monthly;
});

final feePaymentsProvider = FutureProvider<List<Payment>>((ref) async {
  return ref.watch(financeServiceProvider).getAllPayments();
});

final yearlyIncomeProvider = FutureProvider<Map<int, double>>((ref) async {
  final payments = await ref.watch(financeServiceProvider).getAllPayments();
  final db = ref.watch(databaseProvider);
  final shopSales = await (db.select(db.shopSales)..where((s) => s.status.equals('completed'))).get();
  final Map<int, double> yearly = {};
  for (final p in payments) {
    final y = p.paymentDate.year;
    yearly[y] = (yearly[y] ?? 0) + p.amountPaid;
  }
  for (final sale in shopSales) {
    final y = sale.soldAt.year;
    yearly[y] = (yearly[y] ?? 0) + sale.totalAmount;
  }
  return yearly;
});

final yearlyExpenseProvider = FutureProvider<Map<int, double>>((ref) async {
  final service = ref.watch(financeServiceProvider);
  final expenses = await service.getAllExpenses();
  final institutionalExpenses = await service.getInstitutionalExpenses();
  final Map<int, double> yearly = {};
  for (final e in expenses) {
    final y = e.expenseDate.year;
    yearly[y] = (yearly[y] ?? 0) + e.amount;
  }
  for (final e in institutionalExpenses) {
    final y = e.expenseDate.year;
    yearly[y] = (yearly[y] ?? 0) + e.amount;
  }
  return yearly;
});

final feeRevenueProvider = FutureProvider.family<double, int>((ref, year) async {
  final payments = await ref.watch(financeServiceProvider).getAllPayments();
  final db = ref.watch(databaseProvider);
  final start = DateTime(year, 1, 1);
  final end = DateTime(year + 1, 1, 1);
  final shopSales = await (db.select(db.shopSales)
        ..where((s) => s.soldAt.isBiggerOrEqualValue(start) & s.soldAt.isSmallerThanValue(end) & s.status.equals('completed')))
      .get();
  final feeRevenue = payments
      .where((p) => p.paymentDate.year == year)
      .fold<double>(0, (sum, p) => sum + p.amountPaid);
  final shopRevenue = shopSales.fold<double>(0, (sum, sale) => sum + sale.totalAmount);
  return feeRevenue + shopRevenue;
});

final totalExpenseProvider = FutureProvider.family<double, int>((ref, year) async {
  final service = ref.watch(financeServiceProvider);
  final expenses = await service.getAllExpenses();
  final institutionalExpenses = await service.getInstitutionalExpenses();
  final directTotal = expenses
      .where((e) => e.expenseDate.year == year)
      .fold<double>(0, (sum, e) => sum + e.amount);
  final institutionalTotal = institutionalExpenses
      .where((e) => e.expenseDate.year == year)
      .fold<double>(0, (sum, e) => sum + e.amount);
  return directTotal + institutionalTotal;
});

final feeStructuresProvider = FutureProvider<List<FeeStructure>>((ref) async {
  return ref.watch(financeServiceProvider).getAllFeeStructures();
});

final paymentsProvider = FutureProvider<List<Payment>>((ref) async {
  return ref.watch(financeServiceProvider).getAllPayments();
});

final expensesProvider = FutureProvider<List<Expense>>((ref) async {
  return ref.watch(financeServiceProvider).getAllExpenses();
});

final studentBalanceProvider = FutureProvider.family<Map<String, double>, int>((ref, studentId) async {
  return ref.watch(financeServiceProvider).getStudentBalance(studentId);
});

final feesLedgerProvider = FutureProvider<List<StudentFeesLedgerRow>>((ref) async {
  return ref.watch(financeServiceProvider).getStudentsFeesLedger(onlyOwing: true, onlyActive: true);
});

class FeesLedgerFilter {
  final bool onlyOwing;
  final bool onlyActive;
  final int? classId;
  final int? feeStructureId;

  const FeesLedgerFilter({
    this.onlyOwing = true,
    this.onlyActive = true,
    this.classId,
    this.feeStructureId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeesLedgerFilter &&
          runtimeType == other.runtimeType &&
          onlyOwing == other.onlyOwing &&
          onlyActive == other.onlyActive &&
          classId == other.classId &&
          feeStructureId == other.feeStructureId;

  @override
  int get hashCode => Object.hash(onlyOwing, onlyActive, classId, feeStructureId);
}

final feesLedgerFilteredProvider = FutureProvider.family<List<StudentFeesLedgerRow>, FeesLedgerFilter>((ref, filter) async {
  return ref.watch(financeServiceProvider).getStudentsFeesLedger(
        onlyOwing: filter.onlyOwing,
        onlyActive: filter.onlyActive,
        classId: filter.classId,
        feeStructureId: filter.feeStructureId,
      );
});

final institutionalExpensesProvider = FutureProvider<List<InstitutionalExpense>>((ref) async {
  return ref.watch(financeServiceProvider).getInstitutionalExpenses();
});

final combinedExpensesProvider = FutureProvider<List<FinanceExpenseEntry>>((ref) async {
  final service = ref.watch(financeServiceProvider);
  final directExpenses = await service.getAllExpenses();
  final institutionalExpenses = await service.getInstitutionalExpenses();

  final rows = <FinanceExpenseEntry>[
    ...directExpenses.map(
      (e) => FinanceExpenseEntry(
        category: e.category,
        description: e.description,
        amount: e.amount,
        expenseDate: e.expenseDate,
        isInstitutional: false,
      ),
    ),
    ...institutionalExpenses.map(
      (e) => FinanceExpenseEntry(
        category: e.category,
        description: e.description,
        amount: e.amount,
        expenseDate: e.expenseDate,
        isInstitutional: true,
      ),
    ),
  ]..sort((a, b) => b.expenseDate.compareTo(a.expenseDate));

  return rows;
});

typedef PayrollPeriod = ({int month, int year});

final payrollHistoryProvider = FutureProvider.family<List<PayrollHistoryEntry>, PayrollPeriod>((ref, period) async {
  return ref.watch(financeServiceProvider).getPayrollHistory(period.month, period.year);
});

final globalFinancialOverviewProvider = FutureProvider<Map<String, double>>((ref) async {
  return ref.watch(financeServiceProvider).getGlobalFinancialOverview();
});

final staffSalaryProvider = FutureProvider.family<StaffSalary?, int>((ref, staffId) async {
  return ref.watch(financeServiceProvider).getStaffSalary(staffId);
});
