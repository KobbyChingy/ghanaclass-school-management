import 'package:drift/drift.dart';
import 'academic_tables.dart';
import 'tables.dart';

// Parent Accounts - Links guardians to students with login credentials
class ParentAccounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get studentId => integer().references(Students, #id)();
  TextColumn get parentName => text().withLength(min: 1, max: 200)();
  TextColumn get email => text().withLength(min: 1, max: 200).unique()();
  TextColumn get passwordHash => text()();
  TextColumn get phoneNumber => text()();
  TextColumn get relationship => text()(); // 'father', 'mother', 'guardian'
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastLoginAt => dateTime().nullable()();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
}

// Notifications - Audit trail for sent SMS/Email notifications
class Notifications extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get recipientId => integer().nullable()(); // ParentAccount ID or User ID
  TextColumn get recipientType => text()(); // 'parent', 'staff'
  TextColumn get channel => text()(); // 'sms', 'email', 'in-app'
  TextColumn get subject => text().nullable()();
  TextColumn get message => text()();
  TextColumn get status => text()(); // 'pending', 'sent', 'failed'
  TextColumn get externalId => text().nullable()(); // SMS provider message ID
  DateTimeColumn get sentAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get createdBy => integer().references(Users, #id)();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
}

// Parent-Teacher Messages - Two-way communication
class ParentMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get parentId => integer().references(ParentAccounts, #id)();
  IntColumn get teacherId => integer().nullable().references(Users, #id)();
  IntColumn get studentId => integer().references(Students, #id)();
  TextColumn get subject => text()();
  TextColumn get message => text()();
  TextColumn get senderType => text()(); // 'parent', 'teacher'
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  DateTimeColumn get sentAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get replyToId => integer().nullable().references(ParentMessages, #id)();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
}
