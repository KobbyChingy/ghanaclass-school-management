import 'package:drift/drift.dart';

/// Local-only tables that support offline-first synchronization.
///
/// These tables are intentionally generic so they can be adopted incrementally
/// without rewiring every feature module at once.

class SyncMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}

/// Client outbox for reliable delivery of locally-made changes to the server.
///
/// The payload is JSON (string) representing the change.
class SyncOutbox extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// UUID generated client-side for idempotency.
  TextColumn get opId => text().unique()();

  /// E.g. "students", "payments", "attendance_records".
  TextColumn get entityType => text()();

  /// Local row id when known (useful before a remoteId exists).
  IntColumn get entityLocalId => integer().nullable()();

  /// Remote identifier (if known).
  TextColumn get entityRemoteId => text().nullable()();

  /// insert | update | delete
  TextColumn get operation => text()();

  /// JSON string with enough data for the server to apply the change.
  TextColumn get payloadJson => text()();

  /// pending | sent | acked | failed
  TextColumn get status => text().withDefault(const Constant('pending'))();

  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Optional server-provided acknowledgment token/version.
  TextColumn get serverAck => text().nullable()();
}
