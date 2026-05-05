import 'package:drift/drift.dart';

// Institutional Identity Table
class InstitutionalIdentity extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get schoolName => text().withLength(min: 1, max: 200)();
  TextColumn get headOfInstitution => text().withLength(min: 1, max: 200)();
  TextColumn get officialEmail => text().withLength(min: 1, max: 200)();
  TextColumn get address => text().nullable()();
  TextColumn get motto => text().nullable()();
  TextColumn get logoPath => text().nullable()(); // Path to logo file
  BlobColumn get logoBytes => blob().nullable()(); // Stored logo image bytes (preferred)
  TextColumn get phoneNumber => text().nullable()();
  TextColumn get masterPasswordHash => text()(); // Hashed master password
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
}

// Users Table (Staff with portal access)
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get fullName => text().withLength(min: 1, max: 200)();
  TextColumn get email => text().withLength(min: 1, max: 200).unique()();
  TextColumn get passwordHash => text()();
  TextColumn get role => text()(); // Stored as string, mapped to UserRole enum
  TextColumn get photoPath => text().nullable()();
  TextColumn get phoneNumber => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastLoginAt => dateTime().nullable()();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
}

// Session Table (for JWT-like session management)
class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id)();
  TextColumn get token => text().unique()();
  DateTimeColumn get expiresAt => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
