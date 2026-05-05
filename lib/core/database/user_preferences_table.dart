import 'package:drift/drift.dart';
import 'tables.dart';

/// Stores per-user dashboard widget preferences (order, visibility, etc.)
class UserPreferences extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id)();
  TextColumn get key => text().withLength(min: 1, max: 100)(); // e.g. 'dashboard_widgets'
  TextColumn get value => text()(); // JSON-encoded widget config
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
