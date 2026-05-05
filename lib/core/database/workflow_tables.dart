import 'package:drift/drift.dart';

import 'academic_tables.dart';
import 'tables.dart';

/// Generic approvals/workflow engine for director/admin operations.
class ApprovalRequests extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get category => text().withDefault(const Constant('general'))();
  TextColumn get description => text().nullable()();

  /// pending | approved | rejected
  TextColumn get status => text().withDefault(const Constant('pending'))();

  @ReferenceName('approvalRequestedBy')
  IntColumn get requestedByUserId => integer().references(Users, #id)();
  DateTimeColumn get requestedAt => dateTime().withDefault(currentDateAndTime)();

  @ReferenceName('approvalDecidedBy')
  IntColumn get decidedByUserId => integer().nullable().references(Users, #id)();
  DateTimeColumn get decidedAt => dateTime().nullable()();
  TextColumn get decisionNote => text().nullable()();

  RealColumn get amount => real().nullable()();
  TextColumn get metadataJson => text().nullable()();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
}

/// Task delegation for approvals follow-ups and general admin operations.
class DelegationTasks extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();

  @ReferenceName('taskCreatedBy')
  IntColumn get createdByUserId => integer().references(Users, #id)();

  @ReferenceName('taskAssignedTo')
  IntColumn get assignedToUserId => integer().references(Users, #id)();

  /// open | done | cancelled
  TextColumn get status => text().withDefault(const Constant('open'))();

  DateTimeColumn get dueAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
}

/// Appraisals for staff oversight.
class StaffAppraisals extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get staffId => integer().references(Staff, #id)();

  IntColumn get periodYear => integer()();
  IntColumn get periodTerm => integer().nullable()();

  /// draft | submitted | finalized
  TextColumn get status => text().withDefault(const Constant('draft'))();

  RealColumn get score => real().nullable()();
  TextColumn get notes => text().nullable()();

  IntColumn get createdByUserId => integer().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
}

class ComplianceChecklistItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get category => text().withDefault(const Constant('general'))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class ComplianceChecklistCompletions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get checklistItemId => integer().references(ComplianceChecklistItems, #id)();

  IntColumn get completedByUserId => integer().references(Users, #id)();
  DateTimeColumn get completedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get notes => text().nullable()();

  IntColumn get academicYear => integer().nullable()();
  IntColumn get term => integer().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {checklistItemId, academicYear, term},
      ];
}
