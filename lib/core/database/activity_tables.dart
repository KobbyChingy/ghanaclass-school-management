import 'package:drift/drift.dart';
import 'tables.dart';

// High-level activity log for cross-portal auditing
class ActivityLogs extends Table {
  IntColumn get id => integer().autoIncrement()();

  // Who performed the action
  IntColumn get actorUserId => integer().references(Users, #id)();
  TextColumn get actorName => text().withLength(min: 1, max: 200)();
  TextColumn get actorRole => text().withLength(min: 1, max: 50)(); // UserRole.name

  // What and where
  TextColumn get module => text().withLength(min: 1, max: 50)(); // students, finance, staff, inventory, etc.
  TextColumn get actionType => text().withLength(min: 1, max: 100)(); // e.g. 'student_admitted'
  TextColumn get description => text().withLength(min: 1, max: 400)();

  // Whether this should surface as an important admin notification
  BoolColumn get isImportant => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

