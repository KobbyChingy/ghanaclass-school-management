import 'package:drift/drift.dart';
import 'academic_tables.dart';
import 'tables.dart';

class QuestionBank extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get subjectId => integer().references(SchoolSubjects, #id)();
  TextColumn get subSubject => text().nullable()();
  TextColumn get difficulty => text()(); // 'easy', 'medium', 'hard'
  TextColumn get questionText => text()();
  TextColumn get questionType => text()(); // 'mcq', 'theory'
  TextColumn get options => text().nullable()(); // JSON string for MCQ options
  TextColumn get correctAnswer => text().nullable()();
  RealColumn get marks => real().withDefault(const Constant(1.0))();
  IntColumn get teacherId => integer().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
}

class ExamPapers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  IntColumn get subjectId => integer().references(SchoolSubjects, #id)();
  IntColumn get classId => integer().nullable().references(SchoolClasses, #id)();
  IntColumn get term => integer()();
  IntColumn get academicYear => integer()();
  TextColumn get instructions => text().nullable()();
  TextColumn get questionsJson => text()(); // Snapshot of questions used
  IntColumn get teacherId => integer().references(Users, #id)();
  DateTimeColumn get examDate => dateTime().nullable()();
  TextColumn get teacherNameOverride => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
}
