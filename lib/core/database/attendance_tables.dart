import 'package:drift/drift.dart';
import 'academic_tables.dart';

class AttendanceSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get classId => integer().references(SchoolClasses, #id)();
  DateTimeColumn get date => dateTime()();
  TextColumn get period => text().nullable()(); // e.g. 'Morning', 'Afternoon'
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {classId, date, period}
  ];
}

class AttendanceRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(AttendanceSessions, #id)();
  IntColumn get studentId => integer().references(Students, #id)();
  TextColumn get status => text()(); // 'present', 'absent', 'late', 'excused'
  TextColumn get remarks => text().nullable()();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {sessionId, studentId}
  ];
}

class StaffAttendanceSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  TextColumn get period => text().nullable()(); // e.g. 'Morning', 'Afternoon'
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {date, period}
  ];
}

class StaffAttendanceRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(StaffAttendanceSessions, #id)();
  IntColumn get staffId => integer().references(Staff, #id)();
  TextColumn get status => text()(); // 'present', 'absent', 'late', 'excused'
  TextColumn get remarks => text().nullable()();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {sessionId, staffId}
  ];
}
