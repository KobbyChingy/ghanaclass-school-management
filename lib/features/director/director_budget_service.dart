import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';

enum DirectorBudgetScope {
  term,
  academicYear,
}

class DirectorBudgetService {
  DirectorBudgetService(this._db);

  final AppDatabase _db;

  static const _termPrefix = 'director_budget_term';
  static const _yearPrefix = 'director_budget_year';
  static const _planPrefix = 'director_budget_plan';
  static const _snapshotHistoryKey = 'director_budget_snapshot_history';

  String _termKey({required int academicYear, required int term}) => '${_termPrefix}_${academicYear}_$term';
  String _yearKey({required int academicYear}) => '${_yearPrefix}_$academicYear';
  String _planKey({required int academicYear, required int term}) => '${_planPrefix}_${academicYear}_$term';

  Future<void> saveBudgetDraft(DirectorBudgetPlan plan) async {
    await _db.setSyncMetadataValue(
      _planKey(academicYear: plan.academicYear, term: plan.term),
      jsonEncode(plan.toJson()),
    );
    await setTermBudget(
      academicYear: plan.academicYear,
      term: plan.term,
      amount: plan.totalExpensesPerTerm,
    );
  }

  Future<DirectorBudgetPlan> getBudgetPlan({required int academicYear, required int term}) async {
    final raw = await _db.getSyncMetadataValue(_planKey(academicYear: academicYear, term: term));
    if (raw == null || raw.trim().isEmpty) {
      return DirectorBudgetPlan.empty(academicYear: academicYear, term: term);
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return DirectorBudgetPlan.fromJson(decoded).normalized(
          academicYear: academicYear,
          term: term,
        );
      }
    } catch (_) {
      // Fall through to an empty plan if existing metadata is invalid.
    }

    return DirectorBudgetPlan.empty(academicYear: academicYear, term: term);
  }

  Future<void> saveBudgetPlan(
    DirectorBudgetPlan plan, {
    bool replaceLatestSnapshot = true,
    String? snapshotNote,
  }) async {
    await saveBudgetDraft(plan);

    final analytics = await getBudgetAnalytics(academicYear: plan.academicYear, term: plan.term);
    final existing = await getBudgetSnapshots();
    final now = DateTime.now();
    final snapshot = DirectorBudgetSnapshot(
      academicYear: plan.academicYear,
      term: plan.term,
      savedAt: now,
      note: snapshotNote?.trim().isEmpty == true ? null : snapshotNote?.trim(),
      plan: plan,
      totalIncomePerTerm: analytics.totalIncomePerTerm,
      totalExpensesPerTerm: analytics.totalExpensesPerTerm,
      projectedBalance: analytics.projectedBalance,
      actualIncomePerTerm: analytics.actualIncomePerTerm,
      actualExpensesPerTerm: analytics.actualExpensesPerTerm,
      balanceVariance: analytics.balanceVariance,
      canteenIncomePerTerm: analytics.canteenIncomePerTerm,
      schoolFeesPerTerm: analytics.schoolFeesPerTerm,
      otherFeesPerTerm: analytics.otherFeesPerTerm,
    );
    final updated = [
      snapshot,
      ...existing.where(
        (row) => !replaceLatestSnapshot || !(row.academicYear == snapshot.academicYear && row.term == snapshot.term),
      ),
    ].take(24).toList(growable: false);
    await _db.setSyncMetadataValue(
      _snapshotHistoryKey,
      jsonEncode(updated.map((row) => row.toJson()).toList(growable: false)),
    );
  }

  Future<DirectorBudgetAnalytics> getBudgetAnalytics({required int academicYear, required int term}) async {
    final plan = await getBudgetPlan(academicYear: academicYear, term: term);
    final otherFeeStructuresExpected = await _sumOtherFeeStructuresExpected(academicYear: academicYear);
    final actualIncomePerTerm = await _sumActualIncomeForTerm(
      academicYear: academicYear,
      term: term,
      monthsInTerm: plan.monthsInTerm,
    );
    final actualExpensesPerTerm = await _sumActualExpensesForTerm(
      academicYear: academicYear,
      term: term,
      monthsInTerm: plan.monthsInTerm,
    );

    return DirectorBudgetAnalytics(
      termBudgetPlan: plan,
      canteenIncomePerTerm: plan.totalCanteenFeesPerTerm,
      schoolFeesPerTerm: plan.totalSchoolFees,
      otherFeesPerTerm: otherFeeStructuresExpected,
      totalIncomePerTerm: plan.totalCanteenFeesPerTerm + plan.totalSchoolFees + otherFeeStructuresExpected,
      totalExpensesPerTerm: plan.totalExpensesPerTerm,
      actualIncomePerTerm: actualIncomePerTerm,
      actualExpensesPerTerm: actualExpensesPerTerm,
      canteenPurchasingPerTerm: plan.totalCanteenExpensesPerTerm,
      salariesPerTerm: plan.salaryBudgetPerTerm,
      taxPerTerm: plan.taxBudgetPerTerm,
      ssnitPerTerm: plan.ssnitBudgetPerTerm,
    );
  }

  Future<double?> getTermBudget({required int academicYear, required int term}) async {
    final plan = await getBudgetPlan(academicYear: academicYear, term: term);
    if (plan.hasEntries) {
      return plan.totalExpensesPerTerm;
    }
    final raw = await _db.getSyncMetadataValue(_termKey(academicYear: academicYear, term: term));
    return _tryParseAmount(raw);
  }

  Future<double?> getAcademicYearBudget({required int academicYear}) async {
    double total = 0;
    bool hasAnyPlan = false;
    for (var term = 1; term <= 3; term++) {
      final plan = await getBudgetPlan(academicYear: academicYear, term: term);
      if (!plan.hasEntries) continue;
      hasAnyPlan = true;
      total += plan.totalExpensesPerTerm;
    }
    if (hasAnyPlan) return total;

    final raw = await _db.getSyncMetadataValue(_yearKey(academicYear: academicYear));
    return _tryParseAmount(raw);
  }

  Future<void> setTermBudget({required int academicYear, required int term, required double amount}) async {
    await _db.setSyncMetadataValue(
      _termKey(academicYear: academicYear, term: term),
      amount.toString(),
    );
  }

  Future<void> setAcademicYearBudget({required int academicYear, required double amount}) async {
    await _db.setSyncMetadataValue(
      _yearKey(academicYear: academicYear),
      amount.toString(),
    );
  }

  double? _tryParseAmount(String? raw) {
    if (raw == null) return null;
    final v = double.tryParse(raw.trim());
    if (v == null) return null;
    if (v.isNaN || v.isInfinite) return null;
    if (v < 0) return null;
    return v;
  }

  Future<double> _sumOtherFeeStructuresExpected({required int academicYear}) async {
    final fees = await (_db.select(_db.feeStructures)
          ..where((f) => f.academicYear.equals(academicYear)))
        .get();
    if (fees.isEmpty) return 0.0;

    final students = await (_db.select(_db.students)
          ..where((s) => s.isActive.equals(true)))
        .get();

    final countByClass = <int, int>{};
    for (final student in students) {
      final classId = student.classId;
      if (classId == null) continue;
      countByClass.update(classId, (value) => value + 1, ifAbsent: () => 1);
    }

    var total = 0.0;
    for (final fee in fees) {
      final category = fee.category.trim().toLowerCase();
      final feeName = fee.feeName.trim().toLowerCase();
      final isHandledByDirectorPlan = category == 'canteen' || feeName.contains('school fee');
      if (isHandledByDirectorPlan) continue;

      final applicableStudents = fee.classId == null
          ? students.length
          : (countByClass[fee.classId!] ?? 0);
      total += applicableStudents * fee.amount;
    }
    return total;
  }

  Future<Map<int, int>> getActiveStudentCountsByClass({required int academicYear}) async {
    final classes = await (_db.select(_db.schoolClasses)
          ..where((c) => c.academicYear.equals(academicYear)))
        .get();
    final validClassIds = classes.where((row) => row.isActive).map((row) => row.id).toSet();
    if (validClassIds.isEmpty) return <int, int>{};

    final students = await (_db.select(_db.students)
          ..where((s) => s.isActive.equals(true)))
        .get();

    final counts = <int, int>{};
    for (final student in students) {
      final classId = student.classId;
      if (classId == null || !validClassIds.contains(classId)) continue;
      counts.update(classId, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  ({DateTime start, DateTime end, int startMonth, int endMonth}) _termRange({
    required int academicYear,
    required int term,
    required int monthsInTerm,
  }) {
    final safeMonths = monthsInTerm.clamp(1, 12);
    final startMonth = (((term - 1) * safeMonths) + 1).clamp(1, 12);
    final endMonth = (startMonth + safeMonths).clamp(1, 13);
    return (
      start: DateTime(academicYear, startMonth, 1),
      end: DateTime(academicYear, endMonth, 1),
      startMonth: startMonth,
      endMonth: endMonth - 1,
    );
  }

  Future<double> _sumActualIncomeForTerm({
    required int academicYear,
    required int term,
    required int monthsInTerm,
  }) async {
    final range = _termRange(academicYear: academicYear, term: term, monthsInTerm: monthsInTerm);
    final payments = await (_db.select(_db.payments)
          ..where((p) => p.paymentDate.isBiggerOrEqualValue(range.start) & p.paymentDate.isSmallerThanValue(range.end)))
        .get();
    final shopSales = await (_db.select(_db.shopSales)
          ..where((s) => s.soldAt.isBiggerOrEqualValue(range.start) & s.soldAt.isSmallerThanValue(range.end) & s.status.equals('completed')))
        .get();
    final paymentTotal = payments.fold<double>(0, (sum, row) => sum + row.amountPaid);
    final shopTotal = shopSales.fold<double>(0, (sum, row) => sum + row.totalAmount);
    return paymentTotal + shopTotal;
  }

  Future<double> _sumActualExpensesForTerm({
    required int academicYear,
    required int term,
    required int monthsInTerm,
  }) async {
    final range = _termRange(academicYear: academicYear, term: term, monthsInTerm: monthsInTerm);

    final expenses = await (_db.select(_db.expenses)
          ..where((e) => e.expenseDate.isBiggerOrEqualValue(range.start) & e.expenseDate.isSmallerThanValue(range.end)))
        .get();

    final institutionalExpenses = await (_db.select(_db.institutionalExpenses)
          ..where((e) => e.expenseDate.isBiggerOrEqualValue(range.start) & e.expenseDate.isSmallerThanValue(range.end)))
        .get();

    final payrollRecords = await (_db.select(_db.payrollRecords)
          ..where((p) => p.year.equals(academicYear) & p.month.isBetweenValues(range.startMonth, range.endMonth)))
        .get();

    final directExpenses = expenses.fold<double>(0, (sum, row) => sum + row.amount);
    final institutionalTotal = institutionalExpenses.fold<double>(0, (sum, row) => sum + row.amount);
    final payrollTotal = payrollRecords.fold<double>(0, (sum, row) => sum + row.netSalary);

    return directExpenses + institutionalTotal + payrollTotal;
  }

  Future<List<DirectorBudgetSnapshot>> getBudgetSnapshots() async {
    final raw = await _db.getSyncMetadataValue(_snapshotHistoryKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((row) => DirectorBudgetSnapshot.fromJson(row.cast<String, dynamic>()))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}

class DirectorBudgetPlan {
  const DirectorBudgetPlan({
    required this.academicYear,
    required this.term,
    required this.monthsInTerm,
    required this.canteenExpenseRows,
    required this.canteenFeeRows,
    required this.schoolFeeRows,
    required this.monthlySalaryBudget,
    required this.monthlyTaxBudget,
    required this.monthlySsnitBudget,
  });

  final int academicYear;
  final int term;
  final int monthsInTerm;
  final List<BudgetExpenseRow> canteenExpenseRows;
  final List<CanteenFeeBudgetRow> canteenFeeRows;
  final List<SchoolFeeBudgetRow> schoolFeeRows;
  final double monthlySalaryBudget;
  final double monthlyTaxBudget;
  final double monthlySsnitBudget;

  factory DirectorBudgetPlan.empty({required int academicYear, required int term}) {
    return DirectorBudgetPlan(
      academicYear: academicYear,
      term: term,
      monthsInTerm: 3,
      canteenExpenseRows: const [],
      canteenFeeRows: const [],
      schoolFeeRows: const [],
      monthlySalaryBudget: 0,
      monthlyTaxBudget: 0,
      monthlySsnitBudget: 0,
    );
  }

  factory DirectorBudgetPlan.fromJson(Map<String, dynamic> json) {
    return DirectorBudgetPlan(
      academicYear: _asInt(json['academicYear']) ?? DateTime.now().year,
      term: _asInt(json['term']) ?? 1,
      monthsInTerm: (_asInt(json['monthsInTerm']) ?? 3).clamp(1, 12),
      canteenExpenseRows: _readList(json['canteenExpenseRows'])
          .map(BudgetExpenseRow.fromJson)
          .toList(growable: false),
      canteenFeeRows: _readList(json['canteenFeeRows'])
          .map(CanteenFeeBudgetRow.fromJson)
          .toList(growable: false),
      schoolFeeRows: _readList(json['schoolFeeRows'])
          .map(SchoolFeeBudgetRow.fromJson)
          .toList(growable: false),
      monthlySalaryBudget: _asDouble(json['monthlySalaryBudget']),
      monthlyTaxBudget: _asDouble(json['monthlyTaxBudget']),
      monthlySsnitBudget: _asDouble(json['monthlySsnitBudget']),
    );
  }

  DirectorBudgetPlan normalized({required int academicYear, required int term}) {
    return copyWith(
      academicYear: academicYear,
      term: term,
      monthsInTerm: monthsInTerm.clamp(1, 12),
    );
  }

  DirectorBudgetPlan copyWith({
    int? academicYear,
    int? term,
    int? monthsInTerm,
    List<BudgetExpenseRow>? canteenExpenseRows,
    List<CanteenFeeBudgetRow>? canteenFeeRows,
    List<SchoolFeeBudgetRow>? schoolFeeRows,
    double? monthlySalaryBudget,
    double? monthlyTaxBudget,
    double? monthlySsnitBudget,
  }) {
    return DirectorBudgetPlan(
      academicYear: academicYear ?? this.academicYear,
      term: term ?? this.term,
      monthsInTerm: monthsInTerm ?? this.monthsInTerm,
      canteenExpenseRows: canteenExpenseRows ?? this.canteenExpenseRows,
      canteenFeeRows: canteenFeeRows ?? this.canteenFeeRows,
      schoolFeeRows: schoolFeeRows ?? this.schoolFeeRows,
      monthlySalaryBudget: monthlySalaryBudget ?? this.monthlySalaryBudget,
      monthlyTaxBudget: monthlyTaxBudget ?? this.monthlyTaxBudget,
      monthlySsnitBudget: monthlySsnitBudget ?? this.monthlySsnitBudget,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'academicYear': academicYear,
      'term': term,
      'monthsInTerm': monthsInTerm,
      'canteenExpenseRows': canteenExpenseRows.map((row) => row.toJson()).toList(growable: false),
      'canteenFeeRows': canteenFeeRows.map((row) => row.toJson()).toList(growable: false),
      'schoolFeeRows': schoolFeeRows.map((row) => row.toJson()).toList(growable: false),
      'monthlySalaryBudget': monthlySalaryBudget,
      'monthlyTaxBudget': monthlyTaxBudget,
      'monthlySsnitBudget': monthlySsnitBudget,
    };
  }

  bool get hasEntries {
    return canteenExpenseRows.isNotEmpty ||
        canteenFeeRows.isNotEmpty ||
        schoolFeeRows.isNotEmpty ||
        monthlySalaryBudget > 0 ||
        monthlyTaxBudget > 0 ||
        monthlySsnitBudget > 0;
  }

  double get totalCanteenExpensesPerTerm =>
      canteenExpenseRows.fold<double>(0, (sum, row) => sum + row.termTotal(monthsInTerm));

  double get totalCanteenFeesPerTerm =>
      canteenFeeRows.fold<double>(0, (sum, row) => sum + row.termTotal(monthsInTerm));

  double get totalSchoolFees =>
      schoolFeeRows.fold<double>(0, (sum, row) => sum + row.total);

  double get monthlyPayrollTotal => monthlySalaryBudget + monthlyTaxBudget + monthlySsnitBudget;
  double get salaryBudgetPerTerm => monthlySalaryBudget * monthsInTerm;
  double get taxBudgetPerTerm => monthlyTaxBudget * monthsInTerm;
  double get ssnitBudgetPerTerm => monthlySsnitBudget * monthsInTerm;
  double get payrollBudgetPerTerm => monthlyPayrollTotal * monthsInTerm;
  double get totalExpensesPerTerm => totalCanteenExpensesPerTerm + payrollBudgetPerTerm;
}

class DirectorBudgetAnalytics {
  const DirectorBudgetAnalytics({
    required this.termBudgetPlan,
    required this.canteenIncomePerTerm,
    required this.schoolFeesPerTerm,
    required this.otherFeesPerTerm,
    required this.totalIncomePerTerm,
    required this.totalExpensesPerTerm,
    required this.actualIncomePerTerm,
    required this.actualExpensesPerTerm,
    required this.canteenPurchasingPerTerm,
    required this.salariesPerTerm,
    required this.taxPerTerm,
    required this.ssnitPerTerm,
  });

  final DirectorBudgetPlan termBudgetPlan;
  final double canteenIncomePerTerm;
  final double schoolFeesPerTerm;
  final double otherFeesPerTerm;
  final double totalIncomePerTerm;
  final double totalExpensesPerTerm;
  final double actualIncomePerTerm;
  final double actualExpensesPerTerm;
  final double canteenPurchasingPerTerm;
  final double salariesPerTerm;
  final double taxPerTerm;
  final double ssnitPerTerm;

  double get projectedBalance => totalIncomePerTerm - totalExpensesPerTerm;
  double get actualBalance => actualIncomePerTerm - actualExpensesPerTerm;
  double get incomeVariance => actualIncomePerTerm - totalIncomePerTerm;
  double get expenseVariance => actualExpensesPerTerm - totalExpensesPerTerm;
  double get balanceVariance => actualBalance - projectedBalance;
}

class DirectorBudgetSnapshot {
  const DirectorBudgetSnapshot({
    required this.academicYear,
    required this.term,
    required this.savedAt,
    required this.note,
    required this.plan,
    required this.totalIncomePerTerm,
    required this.totalExpensesPerTerm,
    required this.projectedBalance,
    required this.actualIncomePerTerm,
    required this.actualExpensesPerTerm,
    required this.balanceVariance,
    required this.canteenIncomePerTerm,
    required this.schoolFeesPerTerm,
    required this.otherFeesPerTerm,
  });

  final int academicYear;
  final int term;
  final DateTime savedAt;
  final String? note;
  final DirectorBudgetPlan plan;
  final double totalIncomePerTerm;
  final double totalExpensesPerTerm;
  final double projectedBalance;
  final double actualIncomePerTerm;
  final double actualExpensesPerTerm;
  final double balanceVariance;
  final double canteenIncomePerTerm;
  final double schoolFeesPerTerm;
  final double otherFeesPerTerm;

  factory DirectorBudgetSnapshot.fromJson(Map<String, dynamic> json) {
    return DirectorBudgetSnapshot(
      academicYear: _asInt(json['academicYear']) ?? DateTime.now().year,
      term: _asInt(json['term']) ?? 1,
      savedAt: DateTime.tryParse((json['savedAt'] as String? ?? '').trim()) ?? DateTime.now(),
      note: (json['note'] as String?)?.trim().isEmpty == true ? null : (json['note'] as String?)?.trim(),
      plan: json['plan'] is Map<String, dynamic>
          ? DirectorBudgetPlan.fromJson(json['plan'] as Map<String, dynamic>)
          : DirectorBudgetPlan.empty(
              academicYear: _asInt(json['academicYear']) ?? DateTime.now().year,
              term: _asInt(json['term']) ?? 1,
            ),
      totalIncomePerTerm: _asDouble(json['totalIncomePerTerm']),
      totalExpensesPerTerm: _asDouble(json['totalExpensesPerTerm']),
      projectedBalance: _asDouble(json['projectedBalance']),
      actualIncomePerTerm: _asDouble(json['actualIncomePerTerm']),
      actualExpensesPerTerm: _asDouble(json['actualExpensesPerTerm']),
      balanceVariance: _asDouble(json['balanceVariance']),
      canteenIncomePerTerm: _asDouble(json['canteenIncomePerTerm']),
      schoolFeesPerTerm: _asDouble(json['schoolFeesPerTerm']),
      otherFeesPerTerm: _asDouble(json['otherFeesPerTerm']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'academicYear': academicYear,
      'term': term,
      'savedAt': savedAt.toIso8601String(),
      'note': note,
      'plan': plan.toJson(),
      'totalIncomePerTerm': totalIncomePerTerm,
      'totalExpensesPerTerm': totalExpensesPerTerm,
      'projectedBalance': projectedBalance,
      'actualIncomePerTerm': actualIncomePerTerm,
      'actualExpensesPerTerm': actualExpensesPerTerm,
      'balanceVariance': balanceVariance,
      'canteenIncomePerTerm': canteenIncomePerTerm,
      'schoolFeesPerTerm': schoolFeesPerTerm,
      'otherFeesPerTerm': otherFeesPerTerm,
    };
  }
}

class BudgetExpenseRow {
  const BudgetExpenseRow({
    required this.itemName,
    required this.unitPrice,
    required this.monthlyQuantities,
  });

  final String itemName;
  final double unitPrice;
  /// One quantity entry per month of the term (e.g. 3 entries for a 3-month term).
  final List<double> monthlyQuantities;

  factory BudgetExpenseRow.empty() {
    return const BudgetExpenseRow(
      itemName: '',
      unitPrice: 0,
      monthlyQuantities: [],
    );
  }

  factory BudgetExpenseRow.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('unitPrice') || json.containsKey('monthlyQuantities')) {
      return BudgetExpenseRow(
        itemName: (json['itemName'] as String? ?? '').trim(),
        unitPrice: _asDouble(json['unitPrice']),
        monthlyQuantities: (json['monthlyQuantities'] as List<dynamic>? ?? [])
            .map((e) => _asDouble(e))
            .toList(growable: false),
      );
    }
    // Legacy migration: map old week1-4 quantities and actualPrice as unitPrice.
    final legacyQtys = [
      _asDouble(json['week1']),
      _asDouble(json['week2']),
      _asDouble(json['week3']),
      _asDouble(json['week4']),
    ];
    return BudgetExpenseRow(
      itemName: (json['itemName'] as String? ?? '').trim(),
      unitPrice: _asDouble(json['actualPrice'] ?? json['expectedPrice']),
      monthlyQuantities: legacyQtys,
    );
  }

  BudgetExpenseRow copyWith({
    String? itemName,
    double? unitPrice,
    List<double>? monthlyQuantities,
  }) {
    return BudgetExpenseRow(
      itemName: itemName ?? this.itemName,
      unitPrice: unitPrice ?? this.unitPrice,
      monthlyQuantities: monthlyQuantities ?? this.monthlyQuantities,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemName': itemName,
      'unitPrice': unitPrice,
      'monthlyQuantities': monthlyQuantities,
    };
  }

  double quantityForMonth(int month) =>
      month < monthlyQuantities.length ? monthlyQuantities[month] : 0;

  double amountForMonth(int month) => unitPrice * quantityForMonth(month);

  double termTotal(int months) {
    double total = 0;
    for (var i = 0; i < months; i++) {
      total += amountForMonth(i);
    }
    return total;
  }
}

class CanteenFeeBudgetRow {
  const CanteenFeeBudgetRow({
    required this.classId,
    required this.classLabel,
    required this.studentCount,
    required this.amountPerChild,
    required this.daysPerWeek,
    required this.weeksPerMonth,
  });

  final int? classId;
  final String classLabel;
  final int studentCount;
  final double amountPerChild;
  final double daysPerWeek;
  final double weeksPerMonth;

  factory CanteenFeeBudgetRow.empty() {
    return const CanteenFeeBudgetRow(
      classId: null,
      classLabel: '',
      studentCount: 0,
      amountPerChild: 0,
      daysPerWeek: 0,
      weeksPerMonth: 0,
    );
  }

  factory CanteenFeeBudgetRow.fromJson(Map<String, dynamic> json) {
    return CanteenFeeBudgetRow(
      classId: _asInt(json['classId']),
      classLabel: (json['classLabel'] as String? ?? '').trim(),
      studentCount: _asInt(json['studentCount']) ?? 0,
      amountPerChild: _asDouble(json['amountPerChild']),
      daysPerWeek: _asDouble(json['daysPerWeek']),
      weeksPerMonth: _asDouble(json['weeksPerMonth']),
    );
  }

  CanteenFeeBudgetRow copyWith({
    int? classId,
    bool clearClassId = false,
    String? classLabel,
    int? studentCount,
    double? amountPerChild,
    double? daysPerWeek,
    double? weeksPerMonth,
  }) {
    return CanteenFeeBudgetRow(
      classId: clearClassId ? null : (classId ?? this.classId),
      classLabel: classLabel ?? this.classLabel,
      studentCount: studentCount ?? this.studentCount,
      amountPerChild: amountPerChild ?? this.amountPerChild,
      daysPerWeek: daysPerWeek ?? this.daysPerWeek,
      weeksPerMonth: weeksPerMonth ?? this.weeksPerMonth,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'classId': classId,
      'classLabel': classLabel,
      'studentCount': studentCount,
      'amountPerChild': amountPerChild,
      'daysPerWeek': daysPerWeek,
      'weeksPerMonth': weeksPerMonth,
    };
  }

  double get total => studentCount * amountPerChild;
  double get daysInWeekTotal => total * daysPerWeek;
  double get weekInMonthTotal => daysInWeekTotal * weeksPerMonth;
  double termTotal(int monthsInTerm) => weekInMonthTotal * monthsInTerm;
}

class SchoolFeeBudgetRow {
  const SchoolFeeBudgetRow({
    required this.classId,
    required this.classLabel,
    required this.studentCount,
    required this.amount,
  });

  final int? classId;
  final String classLabel;
  final int studentCount;
  final double amount;

  factory SchoolFeeBudgetRow.empty() {
    return const SchoolFeeBudgetRow(
      classId: null,
      classLabel: '',
      studentCount: 0,
      amount: 0,
    );
  }

  factory SchoolFeeBudgetRow.fromJson(Map<String, dynamic> json) {
    return SchoolFeeBudgetRow(
      classId: _asInt(json['classId']),
      classLabel: (json['classLabel'] as String? ?? '').trim(),
      studentCount: _asInt(json['studentCount']) ?? 0,
      amount: _asDouble(json['amount']),
    );
  }

  SchoolFeeBudgetRow copyWith({
    int? classId,
    bool clearClassId = false,
    String? classLabel,
    int? studentCount,
    double? amount,
  }) {
    return SchoolFeeBudgetRow(
      classId: clearClassId ? null : (classId ?? this.classId),
      classLabel: classLabel ?? this.classLabel,
      studentCount: studentCount ?? this.studentCount,
      amount: amount ?? this.amount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'classId': classId,
      'classLabel': classLabel,
      'studentCount': studentCount,
      'amount': amount,
    };
  }

  double get total => studentCount * amount;
}

List<Map<String, dynamic>> _readList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<Map>().map((row) => row.cast<String, dynamic>()).toList(growable: false);
}

double _asDouble(Object? value) {
  if (value is num) {
    final v = value.toDouble();
    if (v.isNaN || v.isInfinite || v < 0) return 0;
    return v;
  }
  if (value is String) {
    final parsed = double.tryParse(value.trim());
    if (parsed == null || parsed.isNaN || parsed.isInfinite || parsed < 0) return 0;
    return parsed;
  }
  return 0;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}
