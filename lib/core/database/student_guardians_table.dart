import 'package:drift/drift.dart';
import 'academic_tables.dart';

/// Table for storing multiple guardians per student.
/// Allows students to have primary and secondary guardians with contact information.
class StudentGuardians extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get studentId => integer().references(Students, #id)();
  
  // Guardian details
  TextColumn get guardianName => text()();
  TextColumn get relationship => text()(); // 'parent', 'guardian', 'uncle', 'aunt', etc.
  TextColumn get phone => text()();
  TextColumn get email => text().nullable()();
  TextColumn get occupation => text().nullable()();
  TextColumn get address => text().nullable()();
  
  /// Priority/order indicator. 1 = primary/first guardian, 2 = secondary, etc.
  /// Lower numbers display first
  IntColumn get priority => integer().withDefault(const Constant(1))();
  
  BoolColumn get isPrimaryContact => boolean().withDefault(const Constant(false))();
  
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
}
