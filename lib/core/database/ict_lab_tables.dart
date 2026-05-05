import 'package:drift/drift.dart';

import 'academic_tables.dart';
import 'tables.dart';

class IctLabDevices extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get assetTag => text().nullable().customConstraint('UNIQUE')();
  TextColumn get deviceType => text().withDefault(const Constant('computer'))();

  TextColumn get status => text().withDefault(const Constant('working'))();
  TextColumn get seatLabel => text().nullable()();
  TextColumn get notes => text().nullable()();

  DateTimeColumn get lastSeenAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class IctLabBookings extends Table {
  IntColumn get id => integer().autoIncrement()();

  DateTimeColumn get startAt => dateTime()();
  DateTimeColumn get endAt => dateTime()();

  @ReferenceName('ictLabBookingsRequestedBy')
  IntColumn get requestedByUserId => integer().references(Users, #id)();
  IntColumn get classId => integer().nullable().references(SchoolClasses, #id)();
  IntColumn get subjectId => integer().nullable().references(SchoolSubjects, #id)();
  @ReferenceName('ictLabBookingsTeacher')
  IntColumn get teacherUserId => integer().nullable().references(Users, #id)();

  TextColumn get title => text().withLength(min: 1, max: 120)();
  TextColumn get notes => text().nullable()();

  /// pending | approved | rejected | cancelled
  TextColumn get status => text().withDefault(const Constant('pending'))();
  @ReferenceName('ictLabBookingsApprovedBy')
  IntColumn get approvedByUserId => integer().nullable().references(Users, #id)();
  DateTimeColumn get approvedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {startAt, endAt, classId, subjectId, teacherUserId}
      ];
}

class IctLabUsageSessions extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get bookingId => integer().nullable().references(IctLabBookings, #id)();

  IntColumn get conductedByUserId => integer().references(Users, #id)();
  IntColumn get classId => integer().nullable().references(SchoolClasses, #id)();
  IntColumn get subjectId => integer().nullable().references(SchoolSubjects, #id)();

  DateTimeColumn get startedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get endedAt => dateTime().nullable()();

  TextColumn get notes => text().nullable()();
}

class IctLabUsageParticipants extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get sessionId => integer().references(IctLabUsageSessions, #id)();
  IntColumn get studentId => integer().references(Students, #id)();
  IntColumn get deviceId => integer().nullable().references(IctLabDevices, #id)();

  DateTimeColumn get checkInAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get checkOutAt => dateTime().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {sessionId, studentId}
      ];
}

class IctLabMaintenanceTickets extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get deviceId => integer().references(IctLabDevices, #id)();
  IntColumn get reportedByUserId => integer().references(Users, #id)();

  TextColumn get title => text().withLength(min: 1, max: 140)();
  TextColumn get description => text().nullable()();

  /// low | normal | high
  TextColumn get priority => text().withDefault(const Constant('normal'))();

  /// open | in_progress | resolved | closed
  TextColumn get status => text().withDefault(const Constant('open'))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get resolvedAt => dateTime().nullable()();
}

class IctLabDeviceLoans extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get deviceId => integer().references(IctLabDevices, #id)();

  /// Borrower can be either a student OR a staff user.
  IntColumn get borrowerStudentId => integer().nullable().references(Students, #id)();
  @ReferenceName('ictLabDeviceLoansBorrowerUser')
  IntColumn get borrowerUserId => integer().nullable().references(Users, #id)();

  @ReferenceName('ictLabDeviceLoansIssuedBy')
  IntColumn get issuedByUserId => integer().references(Users, #id)();
  DateTimeColumn get issuedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get dueAt => dateTime().nullable()();

  DateTimeColumn get returnedAt => dateTime().nullable()();
  @ReferenceName('ictLabDeviceLoansReturnedBy')
  IntColumn get returnedByUserId => integer().nullable().references(Users, #id)();

  TextColumn get notes => text().nullable()();
}
