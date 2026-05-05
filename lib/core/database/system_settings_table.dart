import 'package:drift/drift.dart';

class SystemSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get activeAcademicYear => integer().withDefault(Constant(DateTime.now().year))();
  IntColumn get activeTerm => integer().withDefault(const Constant(1))(); // 1, 2, or 3
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
