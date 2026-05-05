import 'package:drift/drift.dart';

import 'academic_tables.dart';
import 'tables.dart';

class ScienceLabItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 160)();

  /// equipment | chemical | consumable | safety_gear
  TextColumn get itemType => text().withDefault(const Constant('equipment'))();

  /// E.g. pcs | bottle | box | ml | l | kg
  TextColumn get unit => text().withDefault(const Constant('pcs'))();

  RealColumn get quantity => real().withDefault(const Constant(0))();
  RealColumn get minQuantity => real().withDefault(const Constant(0))();

  /// working | faulty | maintenance | expired | retired
  TextColumn get condition => text().withDefault(const Constant('working'))();

  TextColumn get location => text().nullable()();

  /// For chemicals/consumables.
  DateTimeColumn get expiryDate => dateTime().nullable()();

  /// MSDS-like notes / hazard tagging.
  TextColumn get hazardNotes => text().nullable()();

  /// Optional supplier/vendor name.
  TextColumn get supplierName => text().nullable()();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class ScienceLabBookings extends Table {
  IntColumn get id => integer().autoIncrement()();

  DateTimeColumn get startAt => dateTime()();
  DateTimeColumn get endAt => dateTime()();

  @ReferenceName('scienceLabBookingsRequestedBy')
  IntColumn get requestedByUserId => integer().references(Users, #id)();

  IntColumn get classId => integer().nullable().references(SchoolClasses, #id)();
  IntColumn get subjectId => integer().nullable().references(SchoolSubjects, #id)();

  @ReferenceName('scienceLabBookingsTeacher')
  IntColumn get teacherUserId => integer().nullable().references(Users, #id)();

  /// Experiment type / practical title.
  TextColumn get title => text().withLength(min: 1, max: 160)();
  TextColumn get notes => text().nullable()();

  /// pending | approved | rejected | cancelled
  TextColumn get status => text().withDefault(const Constant('pending'))();

  @ReferenceName('scienceLabBookingsApprovedBy')
  IntColumn get approvedByUserId => integer().nullable().references(Users, #id)();
  DateTimeColumn get approvedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {startAt, endAt, classId, subjectId, teacherUserId}
      ];
}

class ScienceLabExperimentTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text().withLength(min: 1, max: 180)();
  TextColumn get description => text().nullable()();

  /// Free-form list (can be CSV / bullets).
  TextColumn get materials => text().nullable()();

  /// Free-form procedure steps.
  TextColumn get steps => text().nullable()();

  IntColumn get estimatedMinutes => integer().withDefault(const Constant(45))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class ScienceLabExperimentRequests extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get templateId => integer().nullable().references(ScienceLabExperimentTemplates, #id)();

  TextColumn get title => text().withLength(min: 1, max: 180)();

  IntColumn get classId => integer().nullable().references(SchoolClasses, #id)();
  IntColumn get subjectId => integer().nullable().references(SchoolSubjects, #id)();

  @ReferenceName('scienceLabExperimentRequestsTeacher')
  IntColumn get teacherUserId => integer().nullable().references(Users, #id)();

  @ReferenceName('scienceLabExperimentRequestsRequestedBy')
  IntColumn get requestedByUserId => integer().references(Users, #id)();

  DateTimeColumn get scheduledAt => dateTime().nullable()();

  /// pending | approved | rejected | prepared | completed | cancelled
  TextColumn get status => text().withDefault(const Constant('pending'))();

  TextColumn get prepChecklist => text().nullable()();
  TextColumn get notes => text().nullable()();

  @ReferenceName('scienceLabExperimentRequestsApprovedBy')
  IntColumn get approvedByUserId => integer().nullable().references(Users, #id)();
  DateTimeColumn get approvedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class ScienceLabSafetyChecks extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Day-level date (store as midnight).
  DateTimeColumn get checkDate => dateTime()();

  @ReferenceName('scienceLabSafetyChecksPerformedBy')
  IntColumn get performedByUserId => integer().references(Users, #id)();

  BoolColumn get fireExtinguisherOk => boolean().withDefault(const Constant(true))();
  BoolColumn get firstAidOk => boolean().withDefault(const Constant(true))();
  BoolColumn get ventilationOk => boolean().withDefault(const Constant(true))();
  BoolColumn get waterOk => boolean().withDefault(const Constant(true))();
  BoolColumn get gasOk => boolean().withDefault(const Constant(true))();
  BoolColumn get electricityOk => boolean().withDefault(const Constant(true))();
  BoolColumn get wasteDisposalOk => boolean().withDefault(const Constant(true))();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {checkDate}
      ];
}

class ScienceLabIncidents extends Table {
  IntColumn get id => integer().autoIncrement()();

  DateTimeColumn get occurredAt => dateTime().withDefault(currentDateAndTime)();

  @ReferenceName('scienceLabIncidentsReportedBy')
  IntColumn get reportedByUserId => integer().references(Users, #id)();

  /// low | normal | high
  TextColumn get severity => text().withDefault(const Constant('normal'))();

  /// spill | injury | breakage | near_miss | theft | other
  TextColumn get incidentType => text().withDefault(const Constant('spill'))();

  IntColumn get relatedItemId => integer().nullable().references(ScienceLabItems, #id)();
  IntColumn get relatedBookingId => integer().nullable().references(ScienceLabBookings, #id)();

  TextColumn get description => text().withLength(min: 1, max: 2000)();
  TextColumn get actionsTaken => text().nullable()();

  DateTimeColumn get resolvedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class ScienceLabUsageSessions extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get bookingId => integer().nullable().references(ScienceLabBookings, #id)();

  @ReferenceName('scienceLabUsageSessionsConductedBy')
  IntColumn get conductedByUserId => integer().references(Users, #id)();

  IntColumn get classId => integer().nullable().references(SchoolClasses, #id)();
  IntColumn get subjectId => integer().nullable().references(SchoolSubjects, #id)();

  TextColumn get experimentTitle => text().nullable()();

  DateTimeColumn get startedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get endedAt => dateTime().nullable()();

  TextColumn get notes => text().nullable()();
}

class ScienceLabUsageParticipants extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get sessionId => integer().references(ScienceLabUsageSessions, #id)();
  IntColumn get studentId => integer().references(Students, #id)();

  /// participant | assistant
  TextColumn get role => text().withDefault(const Constant('participant'))();

  DateTimeColumn get checkInAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get checkOutAt => dateTime().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {sessionId, studentId}
      ];
}
