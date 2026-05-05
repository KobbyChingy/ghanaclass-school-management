import 'package:drift/drift.dart';
import 'academic_tables.dart';
import 'tables.dart';

// Fee Structures by Class
class FeeStructures extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get feeName => text().withLength(min: 1, max: 100)();
  RealColumn get amount => real()();
  TextColumn get category => text()(); // 'Tuition', 'Transport', 'Canteen'
  IntColumn get academicYear => integer()();
  IntColumn get classId => integer().nullable().references(SchoolClasses, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
}

// Student Payments
class Payments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get studentId => integer().references(Students, #id)();
  IntColumn get feeStructureId => integer().references(FeeStructures, #id)();
  RealColumn get amountPaid => real()();
  DateTimeColumn get paymentDate => dateTime().withDefault(currentDateAndTime)();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))(); // 'cash', 'bank', 'mobile_money'
  TextColumn get receiptNumber => text().unique()();
  TextColumn get notes => text().nullable()();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
}

// School Expenses
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get description => text()();
  RealColumn get amount => real()();
  TextColumn get category => text()(); // 'Salary', 'Utility', 'Maintenance'
  DateTimeColumn get expenseDate => dateTime().withDefault(currentDateAndTime)();
  IntColumn get recordedBy => integer().references(Users, #id)();
  TextColumn get receiptPath => text().nullable()();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
}
