import 'package:drift/drift.dart';
import 'academic_tables.dart';

class ReportSummaries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get studentId => integer().references(Students, #id)();
  IntColumn get term => integer()();
  IntColumn get academicYear => integer()();
  
  // Attendance
  IntColumn get attendancePresent => integer().withDefault(const Constant(0))();
  IntColumn get attendanceTotal => integer().withDefault(const Constant(0))();
  
  // Academic Metrics
  IntColumn get position => integer().nullable()();
  IntColumn get totalStudents => integer().nullable()();
  RealColumn get averageScore => real().nullable()();
  
  // Remarks
  TextColumn get conduct => text().nullable()();
  TextColumn get teacherRemarks => text().nullable()();
  TextColumn get headteacherRemarks => text().nullable()();
  
  DateTimeColumn get nextTermBegins => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {studentId, term, academicYear}
  ];
}
