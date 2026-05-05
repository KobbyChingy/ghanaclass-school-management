import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'dart:convert';
import 'package:drift/drift.dart';

class PayrollHistoryEntry {
  final PayrollRecord record;
  final User staff;
  final User paidBy;

  const PayrollHistoryEntry({
    required this.record,
    required this.staff,
    required this.paidBy,
  });
}

class FinanceService {
  final AppDatabase _database;

  FinanceService(this._database);

  Future<List<FeeStructure>> _getApplicableFeeStructuresForClass(
    int? classId, {
    int? feeStructureId,
  }) async {
    final query = _database.select(_database.feeStructures);
    if (feeStructureId != null) {
      query.where((t) => t.id.equals(feeStructureId));
    }

    final fees = await query.get();
    return fees
        .where((fee) => fee.classId == null || fee.classId == classId)
        .toList(growable: false);
  }

  // Fee Structure
  Future<List<FeeStructure>> getAllFeeStructures() async {
    return await _database.select(_database.feeStructures).get();
  }

  Future<int> createFeeStructure(FeeStructuresCompanion entry) async {
    return await _database.into(_database.feeStructures).insert(entry);
  }

  // Payments
  Future<List<Payment>> getAllPayments() async {
    return await _database.select(_database.payments).get();
  }

  Future<int> recordPayment(PaymentsCompanion entry) async {
    return await _database.into(_database.payments).insert(entry);
  }

  Future<List<Payment>> getPaymentsForStudent(int studentId) async {
    return await (_database.select(_database.payments)..where((t) => t.studentId.equals(studentId))).get();
  }

  Future<Payment> getPaymentById(int id) async {
    return await (_database.select(_database.payments)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<double> getTotalPaidForStudentFeeStructure(int studentId, int feeStructureId) async {
    final payments = _database.payments;
    final amountSum = payments.amountPaid.sum();

    final row = await (_database.selectOnly(payments)
          ..addColumns([amountSum])
          ..where(payments.studentId.equals(studentId) & payments.feeStructureId.equals(feeStructureId)))
        .getSingle();

    return row.read(amountSum) ?? 0.0;
  }

  // Expenses
  Future<List<Expense>> getAllExpenses() async {
    return await _database.select(_database.expenses).get();
  }

  Future<int> createExpense(ExpensesCompanion entry) async {
    return await _database.into(_database.expenses).insert(entry);
  }

  /// Get student financial summary
  Future<Map<String, double>> getStudentBalance(int studentId) async {
    final student = await (_database.select(_database.students)
          ..where((t) => t.id.equals(studentId)))
        .getSingle();

    final applicableFees = await _getApplicableFeeStructuresForClass(student.classId);
    final applicableFeeIds = applicableFees.map((fee) => fee.id).toSet();
    final payments = await getPaymentsForStudent(studentId);
    final totalPaid = payments
        .where((payment) => applicableFeeIds.contains(payment.feeStructureId))
        .fold<double>(0, (sum, payment) => sum + payment.amountPaid);
    final totalFees = applicableFees.fold<double>(0, (sum, fee) => sum + fee.amount);

    return {
      'totalFees': totalFees,
      'totalPaid': totalPaid,
      'balance': totalFees - totalPaid,
    };
  }

  Future<double> getOutstandingForStudentFeeStructure(int studentId, int feeStructureId) async {
    final student = await (_database.select(_database.students)
          ..where((t) => t.id.equals(studentId)))
        .getSingle();

    final fee = await (_database.select(_database.feeStructures)
          ..where((t) => t.id.equals(feeStructureId)))
        .getSingleOrNull();
    if (fee == null) {
      return 0.0;
    }

    if (fee.classId != null && fee.classId != student.classId) {
      return 0.0;
    }

    final totalPaid = await getTotalPaidForStudentFeeStructure(studentId, feeStructureId);
    final balance = fee.amount - totalPaid;
    return balance <= 0 ? 0.0 : balance;
  }

  Future<List<FeeStructure>> getApplicableFeeStructuresForStudent(int studentId) async {
    final student = await (_database.select(_database.students)
          ..where((t) => t.id.equals(studentId)))
        .getSingle();
    return _getApplicableFeeStructuresForClass(student.classId);
  }

  Future<List<StudentFeesLedgerRow>> getStudentsFeesLedger({
    bool onlyOwing = true,
    bool onlyActive = true,
    int? classId,
    int? feeStructureId,
  }) async {
    final students = _database.students;
    final classes = _database.schoolClasses;

    final query = _database.select(students).join([
      leftOuterJoin(classes, classes.id.equalsExp(students.classId)),
    ]);

    if (onlyActive) {
      query.where(students.isActive.equals(true));
    }

    if (classId != null) {
      query.where(students.classId.equals(classId));
    }

    final rows = await query.get();
    if (rows.isEmpty) {
      return const <StudentFeesLedgerRow>[];
    }

    final feeQuery = _database.select(_database.feeStructures);
    if (feeStructureId != null) {
      feeQuery.where((t) => t.id.equals(feeStructureId));
    }

    final allFees = await feeQuery.get();
    if (allFees.isEmpty) {
      return const <StudentFeesLedgerRow>[];
    }

    final studentIds = rows.map((row) => row.readTable(students).id).toSet();
    final feeIds = allFees.map((fee) => fee.id).toSet();

    final paymentQuery = _database.select(_database.payments)
      ..where((t) => t.studentId.isIn(studentIds) & t.feeStructureId.isIn(feeIds));
    final allPayments = await paymentQuery.get();
    final result = <StudentFeesLedgerRow>[];

    final globalFees = <FeeStructure>[];
    final classSpecificFees = <int, List<FeeStructure>>{};
    for (final fee in allFees) {
      final targetClassId = fee.classId;
      if (targetClassId == null) {
        globalFees.add(fee);
        continue;
      }
      classSpecificFees.putIfAbsent(targetClassId, () => <FeeStructure>[]).add(fee);
    }

    final paymentsByKey = <String, double>{};
    for (final payment in allPayments) {
      final key = '${payment.studentId}:${payment.feeStructureId}';
      paymentsByKey.update(
        key,
        (value) => value + payment.amountPaid,
        ifAbsent: () => payment.amountPaid,
      );
    }

    for (final row in rows) {
      final student = row.readTable(students);
      final className = row.readTableOrNull(classes)?.className;
      final applicableFees = [
        ...globalFees,
        ...?classSpecificFees[student.classId],
      ];

      for (final fee in applicableFees) {
        final totalPaid = paymentsByKey['${student.id}:${fee.id}'] ?? 0.0;
        final balance = fee.amount - totalPaid;
        if (onlyOwing && balance <= 0.0001) {
          continue;
        }

        result.add(
          StudentFeesLedgerRow(
            studentId: student.id,
            studentCode: student.studentId,
            firstName: student.firstName,
            lastName: student.lastName,
            guardianName: student.guardianName,
            guardianPhone: student.guardianPhone,
            guardianEmail: student.guardianEmail,
            classId: student.classId,
            className: className,
            feeStructureId: fee.id,
            feeName: fee.feeName,
            totalFees: fee.amount,
            totalPaid: totalPaid,
            balance: balance,
          ),
        );
      }
    }

    result.sort((a, b) {
      final balanceCompare = b.balance.compareTo(a.balance);
      if (balanceCompare != 0) return balanceCompare;
      final classCompare = (a.className ?? '').compareTo(b.className ?? '');
      if (classCompare != 0) return classCompare;
      final studentCompare = '${a.firstName} ${a.lastName}'.compareTo('${b.firstName} ${b.lastName}');
      if (studentCompare != 0) return studentCompare;
      return a.feeName.compareTo(b.feeName);
    });
    return result;
  }
  // Phase 9: Staff Salaries
  Future<StaffSalary?> getStaffSalary(int staffId) async {
    return await (_database.select(_database.staffSalaries)
          ..where((t) => t.staffId.equals(staffId)))
        .getSingleOrNull();
  }

  Future<void> upsertStaffSalary(StaffSalariesCompanion entry) async {
    final existing = await getStaffSalary(entry.staffId.value);
    if (existing != null) {
      await (_database.update(_database.staffSalaries)
            ..where((t) => t.staffId.equals(entry.staffId.value)))
          .write(entry);
    } else {
      await _database.into(_database.staffSalaries).insert(entry);
    }
  }

  // Phase 9: Payroll
  Future<List<PayrollRecord>> getPayrollRecords(int month, int year) async {
    return await (_database.select(_database.payrollRecords)
          ..where((t) => t.month.equals(month) & t.year.equals(year)))
        .get();
  }

  Future<List<PayrollHistoryEntry>> getPayrollHistory(int month, int year) async {
    final payroll = _database.payrollRecords;
    final staff = _database.users;
    final paidBy = _database.alias(_database.users, 'paid_by_user');

    final query = _database.select(payroll).join([
      innerJoin(staff, staff.id.equalsExp(payroll.staffId)),
      innerJoin(paidBy, paidBy.id.equalsExp(payroll.paidBy)),
    ])
      ..where(payroll.month.equals(month) & payroll.year.equals(year))
      ..orderBy([OrderingTerm.desc(payroll.paidAt), OrderingTerm.desc(payroll.id)]);

    final rows = await query.get();
    return rows
        .map(
          (r) => PayrollHistoryEntry(
            record: r.readTable(payroll),
            staff: r.readTable(staff),
            paidBy: r.readTable(paidBy),
          ),
        )
        .toList(growable: false);
  }

  Future<void> processPayroll({
    required int month,
    required int year,
    required int adminId,
  }) async {
    // 1. Get all staff (Teachers, Admin, etc. from Users table)
    final allStaff = await _database.select(_database.users).get();
    
    // 2. For each staff, calculate net salary and insert record
    for (final staff in allStaff) {
      final salaryConfig = await getStaffSalary(staff.id);
      if (salaryConfig == null || salaryConfig.baseSalary <= 0) continue;

      // Parse allowances and deductions
      double totalAllowances = 0;
      if (salaryConfig.allowances != null) {
        final List<dynamic> list = jsonDecode(salaryConfig.allowances!);
        totalAllowances = list.fold(0.0, (sum, item) => sum + (item['amount'] ?? 0.0));
      }

      double totalDeductions = 0;
      if (salaryConfig.deductions != null) {
        final List<dynamic> list = jsonDecode(salaryConfig.deductions!);
        totalDeductions = list.fold(0.0, (sum, item) => sum + (item['amount'] ?? 0.0));
      }

      final gross = salaryConfig.baseSalary + totalAllowances;
      final net = gross - totalDeductions;

      await _database.into(_database.payrollRecords).insert(PayrollRecordsCompanion.insert(
        staffId: staff.id,
        grossSalary: gross,
        netSalary: net,
        totalAllowances: totalAllowances,
        totalDeductions: totalDeductions,
        month: month,
        year: year,
        paidBy: adminId,
      ));
    }
  }

  // Phase 9: Institutional Expenses
  Future<List<InstitutionalExpense>> getInstitutionalExpenses() async {
    return await (_database.select(_database.institutionalExpenses)
          ..orderBy([(t) => OrderingTerm.desc(t.expenseDate)]))
        .get();
  }

  Future<int> addInstitutionalExpense(InstitutionalExpensesCompanion entry) async {
    return await _database.into(_database.institutionalExpenses).insert(entry);
  }

  // Financial Stats for Analytics
  Future<Map<String, double>> getGlobalFinancialOverview() async {
    final payments = await getAllPayments();
    final totalIncome = payments.fold<double>(0, (sum, p) => sum + p.amountPaid);

    final payrolls = await _database.select(_database.payrollRecords).get();
    final totalPayroll = payrolls.fold<double>(0, (sum, p) => sum + p.netSalary);

    final expenses = await getInstitutionalExpenses();
    final totalExpenses = expenses.fold<double>(0, (sum, e) => sum + e.amount);

    return {
      'totalIncome': totalIncome,
      'totalPayroll': totalPayroll,
      'totalExpenses': totalExpenses,
      'netBalance': totalIncome - (totalPayroll + totalExpenses),
    };
  }
}

class StudentFeesLedgerRow {
  final int studentId;
  final String studentCode;
  final String firstName;
  final String lastName;
  final String guardianName;
  final String guardianPhone;
  final String? guardianEmail;
  final int? classId;
  final String? className;
  final int feeStructureId;
  final String feeName;
  final double totalFees;
  final double totalPaid;
  final double balance;

  const StudentFeesLedgerRow({
    required this.studentId,
    required this.studentCode,
    required this.firstName,
    required this.lastName,
    required this.guardianName,
    required this.guardianPhone,
    required this.guardianEmail,
    required this.classId,
    required this.className,
    required this.feeStructureId,
    required this.feeName,
    required this.totalFees,
    required this.totalPaid,
    required this.balance,
  });
}
