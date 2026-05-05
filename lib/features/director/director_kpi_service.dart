import 'package:drift/drift.dart' as drift;
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/features/director/director_budget_service.dart';

class DirectorKpis {
  final int totalStudents;
  final int totalStaff;

  /// Percentage 0-100
  final double studentAttendanceRateToday;
  /// Percentage 0-100
  final double staffAttendanceRateToday;

  final double feesExpected;
  final double feesCollected;

  /// Percentage 0-100
  final double feesCollectionRate;

  final double expensesThisMonth;
  final double? termBudget;
  final double? academicYearBudget;
  final double projectedTermIncome;
  final double projectedTermExpenses;
  final double projectedTermBalance;
  final double actualTermIncome;
  final double actualTermExpenses;
  final double termBalanceVariance;
  final int budgetSnapshotCount;
  final DateTime? lastBudgetSavedAt;

  final double payrollNetThisMonth;
  final double payrollAllowancesThisMonth;

  final int admissionsThisYear;
  /// Percentage 0-100
  final double retentionRate;

  final int maleStudents;
  final int femaleStudents;
  final int newStudentsThisYear;
  final int repeaters;

  final int reportSummariesThisTerm;

  final int classesThisYear;
  final int activeSubjects;

  final int notificationsSent;
  final int openAlerts;
  final int auditEvents;

  final DateTime? lastSyncAt;
  final String settingsStatus;

  const DirectorKpis({
    required this.totalStudents,
    required this.totalStaff,
    required this.studentAttendanceRateToday,
    required this.staffAttendanceRateToday,
    required this.feesExpected,
    required this.feesCollected,
    required this.feesCollectionRate,
    required this.expensesThisMonth,
    required this.termBudget,
    required this.academicYearBudget,
    required this.projectedTermIncome,
    required this.projectedTermExpenses,
    required this.projectedTermBalance,
    required this.actualTermIncome,
    required this.actualTermExpenses,
    required this.termBalanceVariance,
    required this.budgetSnapshotCount,
    required this.lastBudgetSavedAt,
    required this.payrollNetThisMonth,
    required this.payrollAllowancesThisMonth,
    required this.admissionsThisYear,
    required this.retentionRate,
    required this.maleStudents,
    required this.femaleStudents,
    required this.newStudentsThisYear,
    required this.repeaters,
    required this.reportSummariesThisTerm,
    required this.classesThisYear,
    required this.activeSubjects,
    required this.notificationsSent,
    required this.openAlerts,
    required this.auditEvents,
    required this.lastSyncAt,
    required this.settingsStatus,
  });
}

class DirectorKpiService {
  DirectorKpiService(this._db);

  final AppDatabase _db;

  Future<DirectorKpis> getKpis({required int activeTerm, required int activeYear}) async {
    final budgetService = DirectorBudgetService(_db);

    // Counts
    final totalStudents = await _countActiveStudents();
    final totalStaff = await _countActiveStaff();

    final studentAttendanceRateToday = await _computeStudentAttendanceRateToday();
    final staffAttendanceRateToday = await _computeStaffAttendanceRateToday();

    // Fees
    final feesExpected = await _sumActiveStudentsEnrolledFees();
    final feesCollected = await _sumAllPayments();
    final feesCollectionRate = feesExpected > 0 ? (feesCollected / feesExpected) * 100.0 : 0.0;

    // Expenses + payroll
    final now = DateTime.now();
    final expensesThisMonth = await _sumExpensesForMonth(now.year, now.month);

    final termBudget = await budgetService.getTermBudget(academicYear: activeYear, term: activeTerm);
    final academicYearBudget = await budgetService.getAcademicYearBudget(academicYear: activeYear);
    final budgetAnalytics = await budgetService.getBudgetAnalytics(academicYear: activeYear, term: activeTerm);
    final budgetSnapshots = await budgetService.getBudgetSnapshots();
    final currentSnapshot = budgetSnapshots.cast<DirectorBudgetSnapshot?>().firstWhere(
          (row) => row?.academicYear == activeYear && row?.term == activeTerm,
          orElse: () => null,
        );

    final payroll = await _sumPayrollForMonth(activeYear, now.month);

    // Admissions & retention
    final admissionsThisYear = await _countAdmissionsForYear(activeYear);
    final retentionRate = await _computeRetentionRate();

    // Demographics
    final maleStudents = await _countStudentsByGender('male');
    final femaleStudents = await _countStudentsByGender('female');
    final newStudentsThisYear = admissionsThisYear;

    // Repeaters is not explicitly tracked in current schema.
    final repeaters = 0;

    // Academic
    final reportSummariesThisTerm = await _countReportSummaries(activeTerm, activeYear);
    final classesThisYear = await _countActiveClasses(activeYear);
    final activeSubjects = await _countActiveSubjects();

    // Comms + alerts + audit
    final notificationsSent = await _countNotificationsSent();
    final openAlerts = await _countOpenSecurityIncidents();
    final auditEvents = await _countAuditEvents();

    final lastSyncAt = await _getLastSyncAt();
    final settingsStatus = 'Term $activeTerm • $activeYear';

    return DirectorKpis(
      totalStudents: totalStudents,
      totalStaff: totalStaff,
      studentAttendanceRateToday: _clampPercent(studentAttendanceRateToday),
      staffAttendanceRateToday: _clampPercent(staffAttendanceRateToday),
      feesExpected: feesExpected,
      feesCollected: feesCollected,
      feesCollectionRate: _clampPercent(feesCollectionRate),
      expensesThisMonth: expensesThisMonth,
      termBudget: termBudget,
      academicYearBudget: academicYearBudget,
      projectedTermIncome: budgetAnalytics.totalIncomePerTerm,
      projectedTermExpenses: budgetAnalytics.totalExpensesPerTerm,
      projectedTermBalance: budgetAnalytics.projectedBalance,
      actualTermIncome: budgetAnalytics.actualIncomePerTerm,
      actualTermExpenses: budgetAnalytics.actualExpensesPerTerm,
      termBalanceVariance: budgetAnalytics.balanceVariance,
      budgetSnapshotCount: budgetSnapshots.length,
      lastBudgetSavedAt: currentSnapshot?.savedAt,
      payrollNetThisMonth: payroll.netTotal,
      payrollAllowancesThisMonth: payroll.allowancesTotal,
      admissionsThisYear: admissionsThisYear,
      retentionRate: _clampPercent(retentionRate),
      maleStudents: maleStudents,
      femaleStudents: femaleStudents,
      newStudentsThisYear: newStudentsThisYear,
      repeaters: repeaters,
      reportSummariesThisTerm: reportSummariesThisTerm,
      classesThisYear: classesThisYear,
      activeSubjects: activeSubjects,
      notificationsSent: notificationsSent,
      openAlerts: openAlerts,
      auditEvents: auditEvents,
      lastSyncAt: lastSyncAt,
      settingsStatus: settingsStatus,
    );
  }

  double _clampPercent(double value) {
    if (value.isNaN || value.isInfinite) return 0.0;
    if (value < 0) return 0.0;
    if (value > 100) return 100.0;
    return value;
  }

  Future<int> _countActiveStudents() async {
    final exp = _db.students.id.count();
    final row = await (_db.selectOnly(_db.students)
          ..addColumns([exp])
          ..where(_db.students.isActive.equals(true)))
        .getSingle();
    return row.read(exp) ?? 0;
  }

  Future<int> _countActiveStaff() async {
    final exp = _db.staff.id.count();
    final row = await (_db.selectOnly(_db.staff)
          ..addColumns([exp])
          ..where(_db.staff.isActive.equals(true)))
        .getSingle();
    return row.read(exp) ?? 0;
  }

  Future<double> _computeStudentAttendanceRateToday() async {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    final sessions = await (_db.select(_db.attendanceSessions)
          ..where((s) => s.date.isBiggerOrEqualValue(todayStart)))
        .get();

    if (sessions.isEmpty) return 0.0;

    int totalPresent = 0;
    int totalExpected = 0;

    for (final s in sessions) {
      final records = await (_db.select(_db.attendanceRecords)
            ..where((r) => r.sessionId.equals(s.id)))
          .get();
      totalExpected += records.length;
      totalPresent += records.where((r) => r.status == 'present').length;
    }

    return totalExpected > 0 ? (totalPresent / totalExpected) * 100.0 : 0.0;
  }

  Future<double> _computeStaffAttendanceRateToday() async {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    final sessions = await (_db.select(_db.staffAttendanceSessions)
          ..where((s) => s.date.isBiggerOrEqualValue(todayStart)))
        .get();

    if (sessions.isEmpty) return 0.0;

    int totalPresent = 0;
    int totalExpected = 0;

    for (final s in sessions) {
      final records = await (_db.select(_db.staffAttendanceRecords)
            ..where((r) => r.sessionId.equals(s.id)))
          .get();
      totalExpected += records.length;
      totalPresent += records.where((r) => r.status == 'present').length;
    }

    return totalExpected > 0 ? (totalPresent / totalExpected) * 100.0 : 0.0;
  }

  Future<double> _sumActiveStudentsEnrolledFees() async {
    final exp = _db.students.enrolledFees.sum();
    final row = await (_db.selectOnly(_db.students)
          ..addColumns([exp])
          ..where(_db.students.isActive.equals(true)))
        .getSingle();
    return row.read(exp) ?? 0.0;
  }

  Future<double> _sumAllPayments() async {
    final exp = _db.payments.amountPaid.sum();
    final row = await (_db.selectOnly(_db.payments)..addColumns([exp])).getSingle();
    return row.read(exp) ?? 0.0;
  }

  Future<double> _sumExpensesForMonth(int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);

    final exp = _db.expenses.amount.sum();
    final institutionalExp = _db.institutionalExpenses.amount.sum();
    final row = await (_db.selectOnly(_db.expenses)
          ..addColumns([exp])
          ..where(_db.expenses.expenseDate.isBiggerOrEqualValue(start) & _db.expenses.expenseDate.isSmallerThanValue(end)))
        .getSingle();
    final institutionalRow = await (_db.selectOnly(_db.institutionalExpenses)
          ..addColumns([institutionalExp])
          ..where(_db.institutionalExpenses.expenseDate.isBiggerOrEqualValue(start) & _db.institutionalExpenses.expenseDate.isSmallerThanValue(end)))
        .getSingle();
    return (row.read(exp) ?? 0.0) + (institutionalRow.read(institutionalExp) ?? 0.0);
  }

  Future<_PayrollSums> _sumPayrollForMonth(int year, int month) async {
    final netExp = _db.payrollRecords.netSalary.sum();
    final allowancesExp = _db.payrollRecords.totalAllowances.sum();

    final row = await (_db.selectOnly(_db.payrollRecords)
          ..addColumns([netExp, allowancesExp])
          ..where(_db.payrollRecords.year.equals(year) & _db.payrollRecords.month.equals(month)))
        .getSingle();

    return _PayrollSums(
      netTotal: row.read(netExp) ?? 0.0,
      allowancesTotal: row.read(allowancesExp) ?? 0.0,
    );
  }

  Future<int> _countAdmissionsForYear(int academicYear) async {
    final start = DateTime(academicYear, 1, 1);
    final end = DateTime(academicYear + 1, 1, 1);
    final exp = _db.students.id.count();
    final row = await (_db.selectOnly(_db.students)
          ..addColumns([exp])
          ..where(_db.students.admissionDate.isBiggerOrEqualValue(start) & _db.students.admissionDate.isSmallerThanValue(end)))
        .getSingle();
    return row.read(exp) ?? 0;
  }

  Future<double> _computeRetentionRate() async {
    final totalExp = _db.students.id.count();
    final activeExp = _db.students.id.count(filter: _db.students.isActive.equals(true));

    final row = await (_db.selectOnly(_db.students)..addColumns([totalExp, activeExp])).getSingle();
    final total = row.read(totalExp) ?? 0;
    final active = row.read(activeExp) ?? 0;

    return total > 0 ? (active / total) * 100.0 : 0.0;
  }

  Future<int> _countStudentsByGender(String genderLower) async {
    final exp = _db.students.id.count();
    final row = await (_db.selectOnly(_db.students)
          ..addColumns([exp])
          ..where(_db.students.gender.lower().equals(genderLower)))
        .getSingle();
    return row.read(exp) ?? 0;
  }

  Future<int> _countReportSummaries(int term, int academicYear) async {
    final exp = _db.reportSummaries.id.count();
    final row = await (_db.selectOnly(_db.reportSummaries)
          ..addColumns([exp])
          ..where(_db.reportSummaries.term.equals(term) & _db.reportSummaries.academicYear.equals(academicYear)))
        .getSingle();
    return row.read(exp) ?? 0;
  }

  Future<int> _countActiveClasses(int academicYear) async {
    final exp = _db.schoolClasses.id.count();
    final row = await (_db.selectOnly(_db.schoolClasses)
          ..addColumns([exp])
          ..where(_db.schoolClasses.academicYear.equals(academicYear) & _db.schoolClasses.isActive.equals(true)))
        .getSingle();
    return row.read(exp) ?? 0;
  }

  Future<int> _countActiveSubjects() async {
    final exp = _db.schoolSubjects.id.count();
    final row = await (_db.selectOnly(_db.schoolSubjects)
          ..addColumns([exp])
          ..where(_db.schoolSubjects.isActive.equals(true)))
        .getSingle();
    return row.read(exp) ?? 0;
  }

  Future<int> _countNotificationsSent() async {
    final exp = _db.notifications.id.count();
    final row = await (_db.selectOnly(_db.notifications)
          ..addColumns([exp])
          ..where(_db.notifications.status.equals('sent')))
        .getSingle();
    return row.read(exp) ?? 0;
  }

  Future<int> _countOpenSecurityIncidents() async {
    final exp = _db.securityIncidents.id.count();
    final row = await (_db.selectOnly(_db.securityIncidents)
          ..addColumns([exp])
          ..where(_db.securityIncidents.resolvedAt.isNull()))
        .getSingle();
    return row.read(exp) ?? 0;
  }

  Future<int> _countAuditEvents() async {
    final exp = _db.activityLogs.id.count();
    final row = await (_db.selectOnly(_db.activityLogs)..addColumns([exp])).getSingle();
    return row.read(exp) ?? 0;
  }

  Future<DateTime?> _getLastSyncAt() async {
    // Best available proxy: when the server sync cursor was last updated.
    final row = await (_db.select(_db.syncMetadata)
          ..where((t) => t.key.equals('server_change_cursor'))
          ..limit(1))
        .getSingleOrNull();
    return row?.updatedAt;
  }
}

class _PayrollSums {
  final double netTotal;
  final double allowancesTotal;

  const _PayrollSums({required this.netTotal, required this.allowancesTotal});
}
