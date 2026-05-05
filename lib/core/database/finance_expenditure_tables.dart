import 'package:drift/drift.dart';
import 'package:ghanaclass_school_management/core/database/tables.dart';

class StaffSalaries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get staffId => integer().references(Users, #id)();
  RealColumn get baseSalary => real().withDefault(const Constant(0.0))();
  TextColumn get allowances => text().nullable()(); // JSON: [{"name": "Housing", "amount": 200.0}]
  TextColumn get deductions => text().nullable()(); // JSON: [{"name": "SSNIT", "amount": 50.0}]
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
}

class PayrollRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  @ReferenceName('payrollRecordsAsStaff')
  IntColumn get staffId => integer().references(Users, #id)();
  RealColumn get grossSalary => real()();
  RealColumn get netSalary => real()();
  RealColumn get totalAllowances => real()();
  RealColumn get totalDeductions => real()();
  IntColumn get month => integer()(); // 1-12
  IntColumn get year => integer()();
  DateTimeColumn get paidAt => dateTime().withDefault(currentDateAndTime)();
  @ReferenceName('payrollRecordsPaidBy')
  IntColumn get paidBy => integer().references(Users, #id)();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
}

class InstitutionalExpenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get category => text()(); // e.g., 'Utility', 'Maintenance', 'Admin', 'Supplies'
  RealColumn get amount => real()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get expenseDate => dateTime()();
  DateTimeColumn get recordedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get recordedBy => integer().references(Users, #id)();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
}
