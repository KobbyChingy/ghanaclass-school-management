import 'package:drift/drift.dart';
import 'academic_tables.dart';
import 'tables.dart';

class Assessments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get assessmentType => text()(); // 'homework', 'mock', 'test', 'exercise', 'group_work', 'exam'
  IntColumn get term => integer().withDefault(const Constant(1))(); // 1, 2, or 3
  IntColumn get classId => integer().references(SchoolClasses, #id)();
  IntColumn get subjectId => integer().references(SchoolSubjects, #id)();
  IntColumn get teacherId => integer().references(Users, #id)();
  RealColumn get maxScore => real().withDefault(const Constant(100.0))();
  RealColumn get weightage => real().withDefault(const Constant(1.0))(); // For internal CA scaling
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
}

class StudentGrades extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get assessmentId => integer().references(Assessments, #id)();
  IntColumn get studentId => integer().references(Students, #id)();
  RealColumn get score => real()();
  TextColumn get remarks => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {assessmentId, studentId}
  ];
}

// Table to store final scaled results for a term
class TermResults extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get studentId => integer().references(Students, #id)();
  IntColumn get classId => integer().references(SchoolClasses, #id)();
  IntColumn get subjectId => integer().references(SchoolSubjects, #id)();
  IntColumn get term => integer()();
  RealColumn get totalCaScore => real().withDefault(const Constant(0.0))(); // Scaled e.g. out of 30
  RealColumn get examScore => real().withDefault(const Constant(0.0))(); // Scaled e.g. out of 70
  RealColumn get totalScore => real().withDefault(const Constant(0.0))(); // CA + Exam (100)
  TextColumn get grade => text().nullable()(); // A1, B2, etc.
  TextColumn get remarks => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {studentId, classId, subjectId, term}
  ];
}

// Table to store teacher-defined weights for CA and Exams
class GradingScales extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get classId => integer().references(SchoolClasses, #id)();
  IntColumn get subjectId => integer().references(SchoolSubjects, #id)();
  IntColumn get term => integer()();
  RealColumn get caWeight => real().withDefault(const Constant(30.0))(); // e.g., 30
  RealColumn get examWeight => real().withDefault(const Constant(70.0))(); // e.g., 70
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {classId, subjectId, term}
  ];
}
