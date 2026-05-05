import 'package:drift/drift.dart';

import 'tables.dart';
import 'academic_tables.dart';

class LessonNotes extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get createdByUserId => integer().references(Users, #id)();

  TextColumn get title => text().withLength(min: 1, max: 200)();

  /// School term (1..3)
  IntColumn get term => integer()();

  /// Academic year (e.g. 2026)
  IntColumn get academicYear => integer()();

  /// Optional context
  IntColumn get classId => integer().nullable().references(SchoolClasses, #id)();
  IntColumn get subjectId => integer().nullable().references(SchoolSubjects, #id)();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class LessonNoteRows extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get noteId => integer().references(LessonNotes, #id, onDelete: KeyAction.cascade)();

  /// Stable ordering for table rendering.
  IntColumn get rowIndex => integer()();

  IntColumn get week => integer().nullable()();
  TextColumn get strand => text().nullable()();
  TextColumn get subStrand => text().nullable()();
  TextColumn get contentStandards => text().nullable()();
  TextColumn get indicators => text().nullable()();
  TextColumn get resources => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
