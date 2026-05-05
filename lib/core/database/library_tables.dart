import 'package:drift/drift.dart';

import 'academic_tables.dart';
import 'tables.dart';

class LibraryBooks extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get author => text().nullable().withLength(min: 0, max: 160)();
  TextColumn get isbn => text().nullable().withLength(min: 0, max: 32)();
  TextColumn get category => text().nullable().withLength(min: 0, max: 80)();

  IntColumn get totalCopies => integer().withDefault(const Constant(1))();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {title, author}
      ];
}

class LibraryLoans extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get bookId => integer().references(LibraryBooks, #id)();

  /// student | staff | external
  TextColumn get borrowerType => text().withDefault(const Constant('student'))();

  IntColumn get borrowerStudentId => integer().nullable().references(Students, #id)();

  @ReferenceName('libraryLoansBorrowerUser')
  IntColumn get borrowerUserId => integer().nullable().references(Users, #id)();

  TextColumn get borrowerName => text().withLength(min: 1, max: 160)();

  @ReferenceName('libraryLoansIssuedBy')
  IntColumn get issuedByUserId => integer().references(Users, #id)();

  DateTimeColumn get issuedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get dueAt => dateTime().nullable()();

  DateTimeColumn get returnedAt => dateTime().nullable()();

  @ReferenceName('libraryLoansReturnedBy')
  IntColumn get returnedByUserId => integer().nullable().references(Users, #id)();

  TextColumn get notes => text().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {bookId, borrowerName, issuedAt}
      ];
}
