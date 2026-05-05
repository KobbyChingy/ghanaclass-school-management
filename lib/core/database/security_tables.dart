import 'package:drift/drift.dart';

import 'tables.dart';

class SecurityVisitorEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get visitorName => text().withLength(min: 1, max: 120)();
  TextColumn get visitorPhone => text().nullable().withLength(min: 0, max: 40)();
  TextColumn get purpose => text().nullable().withLength(min: 0, max: 200)();
  TextColumn get personToSee => text().nullable().withLength(min: 0, max: 120)();

  DateTimeColumn get checkedInAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get checkedOutAt => dateTime().nullable()();

  @ReferenceName('securityVisitorEntriesCreatedBy')
  IntColumn get createdByUserId => integer().references(Users, #id)();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class SecurityIncidents extends Table {
  IntColumn get id => integer().autoIncrement()();

  DateTimeColumn get occurredAt => dateTime().withDefault(currentDateAndTime)();

  /// general | theft | fight | trespass | emergency | other
  TextColumn get incidentType => text().withDefault(const Constant('general'))();

  /// low | medium | high
  TextColumn get severity => text().withDefault(const Constant('low'))();

  TextColumn get description => text().withLength(min: 1, max: 2000)();

  DateTimeColumn get resolvedAt => dateTime().nullable()();

  @ReferenceName('securityIncidentsReportedBy')
  IntColumn get reportedByUserId => integer().references(Users, #id)();

  TextColumn get actionsTaken => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
