import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:meta/meta.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tables.dart';
import 'academic_tables.dart';
import 'financial_tables.dart';
import 'activity_tables.dart';
import 'attendance_tables.dart';
import 'assessment_tables.dart';
import 'system_settings_table.dart';
import 'report_tables.dart';
import 'question_bank_tables.dart';
import 'finance_expenditure_tables.dart';
import 'parent_tables.dart';
import 'sync_tables.dart';
import 'alarms_tables.dart';
import 'lesson_note_tables.dart';
import 'shop_tables.dart';

import 'package:ghanaclass_school_management/core/data/ges_subject_catalog.dart';
import 'canteen_tables.dart';
import 'chef_tables.dart';
import 'ict_lab_tables.dart';
import 'science_lab_tables.dart';
import 'infirmary_tables.dart';
import 'security_tables.dart';
import 'library_tables.dart';
import 'secretary_tables.dart';
import 'workflow_tables.dart';

import 'user_preferences_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  InstitutionalIdentity,
  Users,
  Sessions,
  Students,
  StudentSubjectEnrollments,
  SchoolClasses,
  SchoolSubjects,
  ClassSubjectOfferings,
  Staff,
  HealthRecords,
  AcademicHistory,
  ClassSubjectTeachers,
  FeeStructures,
  Payments,
  Expenses,
  ActivityLogs,
  AttendanceSessions,
  AttendanceRecords,
  StaffAttendanceSessions,
  StaffAttendanceRecords,
  Assessments,
  StudentGrades,
  TermResults,
  GradingScales,
  SystemSettings,
  ReportSummaries,
  QuestionBank,
  ExamPapers,
  StaffSalaries,
  PayrollRecords,
  InstitutionalExpenses,
  ParentAccounts,
  Notifications,
  ParentMessages,
  LessonNotes,
  LessonNoteRows,
  SyncMetadata,
  SyncOutbox,
  Alarms,
  ShopCategories,
  ShopSuppliers,
  ShopItems,
  ShopStockMovements,
  ShopSales,
  ShopSaleItems,
  StudentWallets,
  WalletTransactions,
  CanteenMenus,
  CanteenMenuItems,
  CanteenItemDetails,
  StudentDietaryNotes,
  CanteenPortionPlans,
  CanteenRecipes,
  CanteenRecipeIngredients,
  CanteenProductionRecords,
  CanteenTemperatureLogs,
  CanteenHygieneChecks,
  CanteenIncidents,
  CanteenWasteLogs,
  CanteenOrders,
  CanteenMenuTemplates,
  CanteenMenuTemplateItems,
  IctLabDevices,
  IctLabBookings,
  IctLabUsageSessions,
  IctLabUsageParticipants,
  IctLabMaintenanceTickets,
  IctLabDeviceLoans,
  ScienceLabItems,
  ScienceLabBookings,
  ScienceLabExperimentTemplates,
  ScienceLabExperimentRequests,
  ScienceLabSafetyChecks,
  ScienceLabIncidents,
  ScienceLabUsageSessions,
  ScienceLabUsageParticipants,
  StudentEmergencyContacts,
  StudentPhysicianDetails,
  StudentVitalsLogs,
  StudentHealthDocuments,
  StudentAllergyAlerts,
  StudentChronicConditions,
  InfirmaryVisits,
  StudentMedications,
  MedicationAdministrationLogs,
  StudentImmunizations,
  StudentCheckups,
  InfirmaryInventoryItems,
  InfirmaryInventoryTransactions,
  SecurityVisitorEntries,
  SecurityIncidents,
  LibraryBooks,
  LibraryLoans,
  SecretaryCorrespondenceTemplates,
  ApprovalRequests,
  DelegationTasks,
  StaffAppraisals,
  ComplianceChecklistItems,
  ComplianceChecklistCompletions,
  UserPreferences,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @visibleForTesting
  AppDatabase.forTesting(super.executor);

  // Cache table column lookups for legacy-schema compatibility.
  final Map<String, Future<Set<String>>> _tableColumnsCache = {};

  Future<Set<String>> _tableColumns(String tableName) {
    return _tableColumnsCache.putIfAbsent(tableName, () async {
      try {
        final rows = await customSelect(
          'PRAGMA table_info("$tableName")',
          readsFrom: const {},
        ).get();
        return rows
            .map((r) => r.data['name']?.toString())
            .whereType<String>()
            .map((s) => s.toLowerCase())
            .toSet();
      } catch (_) {
        return <String>{};
      }
    });
  }

  void _invalidateTableColumnsCache(String tableName) {
    _tableColumnsCache.remove(tableName);
  }

  Future<Map<String, String>> _foreignKeyTargetsByFromColumn(String tableName) async {
    try {
      final rows = await customSelect(
        'PRAGMA foreign_key_list("$tableName")',
        readsFrom: const {},
      ).get();

      final map = <String, String>{};
      for (final r in rows) {
        final from = r.data['from']?.toString().toLowerCase();
        final toTable = r.data['table']?.toString().toLowerCase();
        if (from == null || toTable == null) continue;
        map[from] = toTable;
      }
      return map;
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<void> _ensureClassSubjectTeachersSchemaCompatible() async {
    // Older databases may have class_subject_teachers foreign keys pointing to
    // legacy tables (e.g. classes/subjects/staff). That causes FK failures when
    // inserting assignments using current ids (school_classes/school_subjects/users).
    if (!await _hasTable('class_subject_teachers')) return;

    // Ensure drift's intended uniqueness exists even on legacy DBs.
    try {
      await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_class_subject_teachers_class_subject '
        'ON class_subject_teachers(class_id, subject_id)',
      );
    } catch (_) {
      // Best-effort; ignore.
    }

    final targets = await _foreignKeyTargetsByFromColumn('class_subject_teachers');

    // If PRAGMA returns nothing (some legacy/odd DBs), don't rebuild blindly.
    if (targets.isEmpty) return;

    final expected = <String, String>{
      'class_id': 'school_classes',
      'subject_id': 'school_subjects',
      'teacher_id': 'users',
    };

    bool mismatch = false;
    for (final e in expected.entries) {
      final actual = targets[e.key];
      if (actual == null || actual != e.value) {
        mismatch = true;
        break;
      }
    }
    if (!mismatch) return;

    // Rebuild the table to point to the correct FK targets.
    // We do this as best-effort and preserve rows when possible.
    await transaction(() async {
      await customStatement('PRAGMA foreign_keys = OFF');

      final legacy = 'class_subject_teachers__legacy';
      try {
        await customStatement('DROP TABLE IF EXISTS $legacy');
      } catch (_) {
        // ignore
      }

      await customStatement('ALTER TABLE class_subject_teachers RENAME TO $legacy');
      _invalidateTableColumnsCache('class_subject_teachers');
      _invalidateTableColumnsCache(legacy);

      // Create a fresh table using the current expected schema.
      // Note: Drift stores DateTime as an integer (ms since epoch) in this project.
      await customStatement(
        'CREATE TABLE class_subject_teachers (\n'
        '  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,\n'
        '  class_id INTEGER NOT NULL REFERENCES school_classes(id),\n'
        '  subject_id INTEGER NOT NULL REFERENCES school_subjects(id),\n'
        '  teacher_id INTEGER NOT NULL REFERENCES users(id),\n'
        '  created_at INTEGER NOT NULL DEFAULT (CAST(strftime(\'%s\',\'now\') AS INTEGER) * 1000),\n'
        '  remote_id TEXT UNIQUE,\n'
        '  last_synced_at INTEGER,\n'
        '  is_dirty INTEGER NOT NULL DEFAULT 0,\n'
        '  UNIQUE(class_id, subject_id)\n'
        ')',
      );

      // Copy what we can from the legacy table.
      final cols = await _tableColumns(legacy);

      String colOrNull(String c) => cols.contains(c) ? c : 'NULL AS $c';
      final createdAtExpr = cols.contains('created_at') ? 'created_at' : "(CAST(strftime('%s','now') AS INTEGER) * 1000) AS created_at";
      final remoteIdExpr = colOrNull('remote_id');
      final lastSyncedAtExpr = colOrNull('last_synced_at');
      final isDirtyExpr = cols.contains('is_dirty')
          ? "(CASE WHEN typeof(is_dirty) IN ('integer','real') THEN CASE WHEN is_dirty != 0 THEN 1 ELSE 0 END WHEN lower(trim(CAST(is_dirty AS TEXT))) IN ('1','true','t','yes','y') THEN 1 ELSE 0 END) AS is_dirty"
          : '0 AS is_dirty';

      // We don't know whether legacy ids exist in referenced tables; ignore rows that don't.
      await customStatement(
        'INSERT OR IGNORE INTO class_subject_teachers (id, class_id, subject_id, teacher_id, created_at, remote_id, last_synced_at, is_dirty)\n'
        'SELECT\n'
        '  id,\n'
        '  class_id,\n'
        '  subject_id,\n'
        '  teacher_id,\n'
        '  $createdAtExpr,\n'
        '  ${remoteIdExpr.split(' AS ').first},\n'
        '  ${lastSyncedAtExpr.split(' AS ').first},\n'
        '  ${isDirtyExpr.split(' AS ').first}\n'
        'FROM $legacy',
      );

      // Drop legacy after successful migration.
      await customStatement('DROP TABLE IF EXISTS $legacy');

      // Recreate unique index (idempotent).
      await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_class_subject_teachers_class_subject '
        'ON class_subject_teachers(class_id, subject_id)',
      );

      await customStatement('PRAGMA foreign_keys = ON');
    });
  }

  Future<void> _ensureTableColumn({
    required String table,
    required String column,
    required String alterSql,
  }) async {
    final cols = await _tableColumns(table);
    if (cols.contains(column.toLowerCase())) return;
    await customStatement(alterSql);
    _invalidateTableColumnsCache(table);
  }

  Future<void> _ensureLegacyAuthSchema() async {
    // Ensure tables contain the columns that Drift expects to write/read.
    // This prevents registration/login from failing on older DB files.
    await _ensureTableColumn(
      table: 'users',
      column: 'remote_id',
      alterSql: 'ALTER TABLE users ADD COLUMN remote_id TEXT',
    );
    await _ensureTableColumn(
      table: 'users',
      column: 'last_synced_at',
      alterSql: 'ALTER TABLE users ADD COLUMN last_synced_at INTEGER',
    );
    await _ensureTableColumn(
      table: 'users',
      column: 'is_dirty',
      alterSql: 'ALTER TABLE users ADD COLUMN is_dirty INTEGER NOT NULL DEFAULT 0',
    );

    await _ensureTableColumn(
      table: 'institutional_identity',
      column: 'remote_id',
      alterSql: 'ALTER TABLE institutional_identity ADD COLUMN remote_id TEXT',
    );
    await _ensureTableColumn(
      table: 'institutional_identity',
      column: 'last_synced_at',
      alterSql: 'ALTER TABLE institutional_identity ADD COLUMN last_synced_at INTEGER',
    );
    await _ensureTableColumn(
      table: 'institutional_identity',
      column: 'is_dirty',
      alterSql: 'ALTER TABLE institutional_identity ADD COLUMN is_dirty INTEGER NOT NULL DEFAULT 0',
    );

    // Optional identity columns that older DBs may not have.
    await _ensureTableColumn(
      table: 'institutional_identity',
      column: 'address',
      alterSql: 'ALTER TABLE institutional_identity ADD COLUMN address TEXT',
    );
    await _ensureTableColumn(
      table: 'institutional_identity',
      column: 'motto',
      alterSql: 'ALTER TABLE institutional_identity ADD COLUMN motto TEXT',
    );
    await _ensureTableColumn(
      table: 'institutional_identity',
      column: 'logo_path',
      alterSql: 'ALTER TABLE institutional_identity ADD COLUMN logo_path TEXT',
    );
    await _ensureTableColumn(
      table: 'institutional_identity',
      column: 'logo_bytes',
      alterSql: 'ALTER TABLE institutional_identity ADD COLUMN logo_bytes BLOB',
    );
    await _ensureTableColumn(
      table: 'institutional_identity',
      column: 'phone_number',
      alterSql: 'ALTER TABLE institutional_identity ADD COLUMN phone_number TEXT',
    );
  }

  String _boolAsIntExpr({required String column, required int defaultValue}) {
    // Normalizes NULLs and text-encoded booleans into 0/1.
    return "(CASE "
        "WHEN $column IS NULL THEN $defaultValue "
        "WHEN typeof($column) IN ('integer','real') THEN CASE WHEN $column != 0 THEN 1 ELSE 0 END "
        "WHEN lower(trim(CAST($column AS TEXT))) IN ('1','true','t','yes','y') THEN 1 "
        "ELSE 0 END)";
  }

  String _dateExpr({required String column}) {
    // Ensures non-empty text and fills NULLs.
    return "COALESCE(NULLIF(TRIM(CAST($column AS TEXT)), ''), CURRENT_TIMESTAMP)";
  }

  Future<String> _usersSelectSql({required bool withWhereEmail}) async {
    final cols = await _tableColumns('users');

    final hasIsActive = cols.contains('is_active');
    final hasCreatedAt = cols.contains('created_at');
    final hasUpdatedAt = cols.contains('updated_at');
    final hasLastLoginAt = cols.contains('last_login_at');
    final hasRemoteId = cols.contains('remote_id');
    final hasLastSyncedAt = cols.contains('last_synced_at');
    final hasIsDirty = cols.contains('is_dirty');

    final isActiveExpr = hasIsActive
        ? "${_boolAsIntExpr(column: 'is_active', defaultValue: 1)} AS is_active"
        : '1 AS is_active';

    final isDirtyExpr = hasIsDirty
        ? "${_boolAsIntExpr(column: 'is_dirty', defaultValue: 0)} AS is_dirty"
        : '0 AS is_dirty';

    final createdAtExpr = hasCreatedAt
        ? "${_dateExpr(column: 'created_at')} AS created_at"
        : 'CURRENT_TIMESTAMP AS created_at';

    final updatedAtExpr = hasUpdatedAt
        ? "${_dateExpr(column: 'updated_at')} AS updated_at"
        : 'CURRENT_TIMESTAMP AS updated_at';

    final lastLoginAtExpr = hasLastLoginAt ? 'last_login_at' : 'NULL AS last_login_at';
    final remoteIdExpr = hasRemoteId ? 'remote_id' : 'NULL AS remote_id';
    final lastSyncedAtExpr = hasLastSyncedAt ? 'last_synced_at' : 'NULL AS last_synced_at';

    final base = 'SELECT '
        '  id, full_name, email, password_hash, role, photo_path, phone_number, '
        '  $isActiveExpr, '
        '  $createdAtExpr, '
        '  $updatedAtExpr, '
        '  $lastLoginAtExpr, '
        '  $remoteIdExpr, '
        '  $lastSyncedAtExpr, '
        '  $isDirtyExpr '
        'FROM users';

    if (!withWhereEmail) return base;

    return '$base WHERE lower(trim(email)) = ? LIMIT 1';
  }

  Future<String> _institutionalIdentitySelectSql() async {
    final cols = await _tableColumns('institutional_identity');

    final hasAddress = cols.contains('address');
    final hasMotto = cols.contains('motto');
    final hasLogoPath = cols.contains('logo_path');
    final hasLogoBytes = cols.contains('logo_bytes');
    final hasPhoneNumber = cols.contains('phone_number');

    final hasCreatedAt = cols.contains('created_at');
    final hasUpdatedAt = cols.contains('updated_at');
    final hasRemoteId = cols.contains('remote_id');
    final hasLastSyncedAt = cols.contains('last_synced_at');
    final hasIsDirty = cols.contains('is_dirty');

    final createdAtExpr = hasCreatedAt
        ? "(CASE WHEN typeof(created_at) IN ('integer','real') THEN created_at ELSE COALESCE(datetime(created_at), CURRENT_TIMESTAMP) END) AS created_at"
        : 'CURRENT_TIMESTAMP AS created_at';

    final updatedAtExpr = hasUpdatedAt
        ? "(CASE WHEN typeof(updated_at) IN ('integer','real') THEN updated_at ELSE COALESCE(datetime(updated_at), CURRENT_TIMESTAMP) END) AS updated_at"
        : 'CURRENT_TIMESTAMP AS updated_at';

    final remoteIdExpr = hasRemoteId ? 'remote_id' : 'NULL AS remote_id';
    final lastSyncedAtExpr = hasLastSyncedAt ? 'last_synced_at' : 'NULL AS last_synced_at';

    final addressExpr = hasAddress ? 'address' : 'NULL AS address';
    final mottoExpr = hasMotto ? 'motto' : 'NULL AS motto';
    final logoPathExpr = hasLogoPath ? 'logo_path' : 'NULL AS logo_path';
    final logoBytesExpr = hasLogoBytes ? 'logo_bytes' : 'NULL AS logo_bytes';
    final phoneNumberExpr = hasPhoneNumber ? 'phone_number' : 'NULL AS phone_number';

    final isDirtyExpr = hasIsDirty
        ? "${_boolAsIntExpr(column: 'is_dirty', defaultValue: 0)} AS is_dirty"
        : '0 AS is_dirty';

    return 'SELECT '
      '  id, school_name, head_of_institution, official_email, '
      '  $addressExpr, $mottoExpr, $logoPathExpr, $logoBytesExpr, $phoneNumberExpr, '
        '  master_password_hash, '
        '  $createdAtExpr, '
        '  $updatedAtExpr, '
        '  $remoteIdExpr, '
        '  $lastSyncedAtExpr, '
        '  $isDirtyExpr '
        'FROM institutional_identity '
        'LIMIT 1';
  }

  @override
  int get schemaVersion => 25;

  static const _nowMsExpr = "(CAST(strftime('%s','now') AS INTEGER) * 1000)";

  Future<bool> _hasColumn(String tableName, String columnName) async {
    final rows = await customSelect("PRAGMA table_info($tableName)").get();
    for (final row in rows) {
      final name = row.data['name'];
      if (name is String && name.toLowerCase() == columnName.toLowerCase()) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _hasTable(String tableName) async {
    final rows = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND lower(name) = lower(?)",
      variables: [Variable<String>(tableName)],
    ).get();
    return rows.isNotEmpty;
  }

  Future<void> _ensureUserPreferencesTable() async {
    if (await _hasTable('user_preferences')) return;

    await customStatement('''
      CREATE TABLE IF NOT EXISTS user_preferences (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL REFERENCES users(id),
        key TEXT NOT NULL,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      )
    ''');
  }

  Future<void> _addColumnIfMissing({
    required String tableName,
    required String columnName,
    required String sqlType,
  }) async {
    final exists = await _hasColumn(tableName, columnName);
    if (exists) return;
    await customStatement('ALTER TABLE $tableName ADD COLUMN $columnName $sqlType');
  }

  Future<void> _ensureStudentsSyncColumns() async {
    // Sync columns added later in development; older DB files may not have them.
    await _addColumnIfMissing(tableName: 'students', columnName: 'remote_id', sqlType: 'TEXT');
    await _addColumnIfMissing(tableName: 'students', columnName: 'last_synced_at', sqlType: 'INTEGER');
    await _addColumnIfMissing(tableName: 'students', columnName: 'is_dirty', sqlType: 'INTEGER NOT NULL DEFAULT 0');

    // Unique is implemented as an index for legacy upgrades.
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_students_remote_id ON students(remote_id)'
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_students_is_dirty ON students(is_dirty)'
    );
  }

  Future<void> _ensureStaffLegacyColumns() async {
    // Older DB files may have a `staff` table without later-added metadata/sync columns.
    // Missing columns cause Drift's generated mappers (which use `!`) to crash at runtime.
    if (!await _hasTable('staff')) return;

    // Metadata
    await _addColumnIfMissing(tableName: 'staff', columnName: 'created_at', sqlType: 'INTEGER');
    await _addColumnIfMissing(tableName: 'staff', columnName: 'updated_at', sqlType: 'INTEGER');

    // Status + sync
    await _addColumnIfMissing(tableName: 'staff', columnName: 'is_active', sqlType: 'INTEGER NOT NULL DEFAULT 1');
    await _addColumnIfMissing(tableName: 'staff', columnName: 'remote_id', sqlType: 'TEXT');
    await _addColumnIfMissing(tableName: 'staff', columnName: 'last_synced_at', sqlType: 'INTEGER');
    await _addColumnIfMissing(tableName: 'staff', columnName: 'is_dirty', sqlType: 'INTEGER NOT NULL DEFAULT 0');

    // Phone is required by Drift schema; keep legacy rows readable.
    await _addColumnIfMissing(tableName: 'staff', columnName: 'phone_number', sqlType: "TEXT NOT NULL DEFAULT 'N/A'");
  }

  Future<void> _ensureStudentRelatedSyncColumns() async {
    // Health records
    await _addColumnIfMissing(tableName: 'health_records', columnName: 'remote_id', sqlType: 'TEXT');
    await _addColumnIfMissing(tableName: 'health_records', columnName: 'last_synced_at', sqlType: 'INTEGER');
    await _addColumnIfMissing(tableName: 'health_records', columnName: 'is_dirty', sqlType: 'INTEGER NOT NULL DEFAULT 0');
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_health_records_remote_id ON health_records(remote_id)'
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_health_records_is_dirty ON health_records(is_dirty)'
    );

    // Academic history
    await _addColumnIfMissing(tableName: 'academic_history', columnName: 'remote_id', sqlType: 'TEXT');
    await _addColumnIfMissing(tableName: 'academic_history', columnName: 'last_synced_at', sqlType: 'INTEGER');
    await _addColumnIfMissing(tableName: 'academic_history', columnName: 'is_dirty', sqlType: 'INTEGER NOT NULL DEFAULT 0');
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_academic_history_remote_id ON academic_history(remote_id)'
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_academic_history_is_dirty ON academic_history(is_dirty)'
    );
  }

  Future<void> _ensureLegacyClassesShim() async {
    // Some legacy databases had a table named `classes` referenced by foreign keys.
    // Newer code uses `school_classes`. If the FK still points to `classes`, inserts
    // will fail unless `classes` exists and contains the referenced ids.
    final hasSchoolClasses = await _hasTable('school_classes');
    if (!hasSchoolClasses) return;

    await customStatement('CREATE TABLE IF NOT EXISTS classes (id INTEGER PRIMARY KEY)');
    _invalidateTableColumnsCache('classes');

    String placeholderLiteralForType(String? sqliteType) {
      final t = (sqliteType ?? '').toUpperCase();
      if (t.contains('INT')) return '0';
      if (t.contains('REAL') || t.contains('FLOA') || t.contains('DOUB')) return '0';
      if (t.contains('BLOB')) return "X''";
      // TEXT / CLOB / CHAR or unknown
      return "''";
    }

    // Determine the column set we must populate in `classes` so inserts won't fail
    // due to NOT NULL constraints in legacy schemas.
    String quoteIdent(String ident) => '"${ident.replaceAll('"', '""')}"';

    final classesInfo = await customSelect(
      'PRAGMA table_info("classes")',
      readsFrom: const {},
    ).get();

    final schoolCols = await _tableColumns('school_classes');

    final insertCols = <String>[];
    final backfillExprs = <String>[];
    final triggerExprs = <String>[];
    bool hasAnyNonId = false;

    for (final row in classesInfo) {
      final nameRaw = row.data['name'];
      if (nameRaw is! String || nameRaw.trim().isEmpty) continue;
      final colName = nameRaw;
      final colLower = colName.toLowerCase();

      final pk = (row.data['pk'] is int) ? (row.data['pk'] as int) : 0;
      final notNull = (row.data['notnull'] is int) ? (row.data['notnull'] as int) : 0;
      final dflt = row.data['dflt_value'];
      final type = row.data['type']?.toString();

      if (pk != 0 || colLower == 'id') {
        insertCols.add(colName);
        backfillExprs.add('id AS ${quoteIdent(colName)}');
        triggerExprs.add('NEW.id');
        continue;
      }

      if (schoolCols.contains(colLower)) {
        hasAnyNonId = true;
        insertCols.add(colName);
        backfillExprs.add(quoteIdent(colName));
        triggerExprs.add('NEW.${quoteIdent(colName)}');
        continue;
      }

      // Only populate columns that would otherwise break an INSERT due to NOT NULL.
      if (notNull != 0 && dflt == null) {
        hasAnyNonId = true;
        final placeholder = placeholderLiteralForType(type);
        insertCols.add(colName);
        backfillExprs.add('$placeholder AS ${quoteIdent(colName)}');
        triggerExprs.add(placeholder);
      }
    }

    // Backfill rows for existing classes.
    if (insertCols.isNotEmpty) {
      await customStatement(
        'INSERT OR IGNORE INTO classes(${insertCols.map(quoteIdent).join(', ')}) '
        'SELECT ${backfillExprs.join(', ')} FROM school_classes',
      );
    }

    // Keep in sync for newly created classes.
    // We intentionally drop and recreate to handle schema changes across versions.
    await customStatement('DROP TRIGGER IF EXISTS trg_school_classes_to_classes_ai');
    if (insertCols.isNotEmpty && hasAnyNonId) {
      await customStatement(
        'CREATE TRIGGER trg_school_classes_to_classes_ai '
        'AFTER INSERT ON school_classes '
        'BEGIN '
        '  INSERT OR IGNORE INTO classes(${insertCols.map(quoteIdent).join(', ')}) '
        '  VALUES (${triggerExprs.join(', ')}); '
        'END;',
      );
    } else {
      // Fallback: legacy `classes` with only a primary key column.
      await customStatement(
        'CREATE TRIGGER trg_school_classes_to_classes_ai '
        'AFTER INSERT ON school_classes '
        'BEGIN '
        '  INSERT OR IGNORE INTO classes(id) VALUES (NEW.id); '
        'END;',
      );
    }
  }

  Future<void> _repairLegacyStaffNulls() async {
    // Older/buggy builds may have inserted NULLs into columns Drift now treats as non-null.
    // Backfill safe defaults to prevent runtime mapper crashes.
    await customStatement(
      "UPDATE staff SET "
      "  staff_id = COALESCE(NULLIF(TRIM(staff_id), ''), 'STAFF-' || id), "
      "  first_name = COALESCE(NULLIF(TRIM(first_name), ''), 'Unknown'), "
      "  last_name = COALESCE(NULLIF(TRIM(last_name), ''), 'Staff'), "
      "  gender = COALESCE(NULLIF(TRIM(gender), ''), 'unknown'), "
      "  phone_number = COALESCE(NULLIF(TRIM(phone_number), ''), 'N/A'), "
      "  position = COALESCE(NULLIF(TRIM(position), ''), 'staff'), "
      "  date_of_birth = (CASE WHEN date_of_birth IS NULL THEN $_nowMsExpr WHEN typeof(date_of_birth) IN ('integer','real') THEN date_of_birth ELSE $_nowMsExpr END), "
      "  hire_date = (CASE WHEN hire_date IS NULL THEN $_nowMsExpr WHEN typeof(hire_date) IN ('integer','real') THEN hire_date ELSE $_nowMsExpr END), "
      "  base_salary = (CASE WHEN base_salary IS NULL THEN 0 WHEN typeof(base_salary) IN ('integer','real') THEN base_salary ELSE CAST(base_salary AS REAL) END), "
      "  is_active = ${_boolAsIntExpr(column: 'is_active', defaultValue: 1)}, "
      "  is_dirty = ${_boolAsIntExpr(column: 'is_dirty', defaultValue: 0)}, "
      "  created_at = (CASE WHEN created_at IS NULL THEN $_nowMsExpr WHEN typeof(created_at) IN ('integer','real') THEN created_at ELSE $_nowMsExpr END), "
      "  updated_at = (CASE WHEN updated_at IS NULL THEN $_nowMsExpr WHEN typeof(updated_at) IN ('integer','real') THEN updated_at ELSE $_nowMsExpr END) "
      "WHERE staff_id IS NULL "
      "   OR TRIM(staff_id) = '' "
      "   OR user_id IS NULL "
      "   OR first_name IS NULL "
      "   OR last_name IS NULL "
      "   OR gender IS NULL "
      "   OR phone_number IS NULL "
      "   OR position IS NULL "
      "   OR date_of_birth IS NULL "
      "   OR typeof(date_of_birth) NOT IN ('integer','real') "
      "   OR hire_date IS NULL "
      "   OR typeof(hire_date) NOT IN ('integer','real') "
      "   OR base_salary IS NULL "
      "   OR typeof(base_salary) NOT IN ('integer','real') "
      "   OR is_active IS NULL "
      "   OR is_dirty IS NULL "
      "   OR created_at IS NULL "
      "   OR updated_at IS NULL"
    );

    // Ensure every staff row has a valid linked user.
    // Some legacy DBs have staff.user_id NULL or pointing to a missing users row.
    // That makes Drift's mapper crash because user_id is non-nullable.
    try {
      // 1) Create missing users for orphaned user_ids (keep the same id).
      final orphanUserRows = await customSelect(
        "SELECT DISTINCT user_id AS uid "
        "FROM staff "
        "WHERE user_id IS NOT NULL "
        "  AND user_id NOT IN (SELECT id FROM users)",
        readsFrom: const {},
      ).get();

      for (final r in orphanUserRows) {
        final uid = r.data['uid'];
        if (uid is! int) continue;

        var email = 'legacy-staff-$uid@local.school';
        var suffix = 0;
        while (true) {
          final exists = await (select(users)..where((u) => u.email.equals(email))).getSingleOrNull();
          if (exists == null) break;
          suffix++;
          email = 'legacy-staff-$uid-$suffix@local.school';
        }

        await into(users).insert(
          UsersCompanion(
            id: Value(uid),
            fullName: const Value('Legacy Staff'),
            email: Value(email),
            passwordHash: const Value('legacy'),
            role: const Value('staff'),
            isActive: const Value(true),
            updatedAt: Value(DateTime.now()),
            createdAt: Value(DateTime.now()),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }

      // 2) For staff rows with NULL user_id, create a new user and link it.
      final missingUserIdStaffRows = await customSelect(
        "SELECT id, staff_id, first_name, last_name, phone_number "
        "FROM staff WHERE user_id IS NULL",
        readsFrom: const {},
      ).get();

      for (final r in missingUserIdStaffRows) {
        final staffTableId = r.data['id'];
        if (staffTableId is! int) continue;

        final staffId = (r.data['staff_id']?.toString().trim().isNotEmpty ?? false)
            ? r.data['staff_id']!.toString().trim()
            : 'STAFF-$staffTableId';
        final firstName = (r.data['first_name']?.toString().trim().isNotEmpty ?? false)
            ? r.data['first_name']!.toString().trim()
            : 'Unknown';
        final lastName = (r.data['last_name']?.toString().trim().isNotEmpty ?? false)
            ? r.data['last_name']!.toString().trim()
            : 'Staff';
        final phone = r.data['phone_number']?.toString();

        var email = '${staffId.toLowerCase()}@local.school';
        var suffix = 0;
        while (true) {
          final exists = await (select(users)..where((u) => u.email.equals(email))).getSingleOrNull();
          if (exists == null) break;
          suffix++;
          email = '${staffId.toLowerCase()}-$suffix@local.school';
        }

        final newUserId = await into(users).insert(
          UsersCompanion.insert(
            fullName: '$firstName $lastName',
            email: email,
            passwordHash: 'legacy',
            role: 'staff',
            phoneNumber: Value(phone?.trim().isNotEmpty == true ? phone!.trim() : null),
          ),
        );

        await (update(staff)..where((t) => t.id.equals(staffTableId))).write(
          StaffCompanion(userId: Value(newUserId)),
        );
      }
    } catch (_) {
      // Best-effort; ignore if users/staff aren't present in this DB.
    }
  }

  Future<void> repairStaffRows() async {
    try {
      await _repairLegacyStaffNulls();
    } catch (_) {
      // Best-effort; ignore.
    }
  }

  /// Runs non-auth-critical maintenance tasks that can be slow on some devices.
  ///
  /// These are intentionally not executed in Drift's `beforeOpen`, because that
  /// blocks the first query (and can make login look stuck).
  Future<void> runDeferredMaintenance() async {
    // Ensure critical sync columns exist for student enrollment/import.
    try {
      await _ensureStudentsSyncColumns();
      await _ensureStudentRelatedSyncColumns();
      await _ensureLegacyClassesShim();
      await _ensureClassSubjectTeachersSchemaCompatible();
    } catch (_) {
      // Best-effort; ignore.
    }

    // Staff legacy forward-compat + row repairs.
    try {
      await _ensureStaffLegacyColumns();
      await _repairLegacyStaffNulls();
    } catch (_) {
      // Best-effort; ignore.
    }

    // Seed NaCCA/WAEC-aligned subjects + default offerings (idempotent).
    try {
      await ensureGesSubjectCatalogSeeded();
      await ensureGesClassSubjectOfferingsSeeded();
    } catch (_) {
      // Best-effort; ignore.
    }
  }


  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          // Enable foreign keys
          await customStatement('PRAGMA foreign_keys = ON');

          // Some legacy installs already report the current schema version but
          // still missed late-added tables, so self-heal these on every open.
          try {
            await _ensureUserPreferencesTable();
          } catch (_) {
            // Best-effort; if open continues, the caller will still surface any
            // remaining issue and avoid crashing the whole migration path here.
          }

          // Avoid running expensive repair/seed routines on every open.
          // They are primarily needed when creating a new database or upgrading
          // from legacy installs.
          final shouldRunRepairs = details.hadUpgrade;

          if (shouldRunRepairs) {
            // Make schema forward-compatible (older DBs may be missing columns).
            try {
              await _ensureLegacyAuthSchema();
            } catch (_) {
              // Best-effort; ignore if tables don't exist yet.
            }

            // Legacy-schema repair: earlier versions created some tables without
            // proper defaults, leaving NULLs in non-nullable columns. Drift's
            // generated mappers use `!` and will crash if a row contains NULL.
            // Backfill the common defaulted columns to keep the app resilient.
            try {
              // Normalize date columns
              await customStatement(
                "UPDATE users "
                "SET created_at = COALESCE(NULLIF(TRIM(CAST(created_at AS TEXT)), ''), CURRENT_TIMESTAMP), "
                "    updated_at = COALESCE(NULLIF(TRIM(CAST(updated_at AS TEXT)), ''), CURRENT_TIMESTAMP) "
                "WHERE created_at IS NULL "
                "   OR updated_at IS NULL "
                "   OR (typeof(created_at) = 'text' AND TRIM(CAST(created_at AS TEXT)) = '') "
                "   OR (typeof(updated_at) = 'text' AND TRIM(CAST(updated_at AS TEXT)) = '')",
              );

              // Normalize boolean columns (handle NULLs and text-encoded bools)
              await customStatement(
                "UPDATE users "
                "SET is_active = ("
                "  CASE "
                "    WHEN is_active IS NULL THEN 1 "
                "    WHEN typeof(is_active) IN ('integer','real') THEN CASE WHEN is_active != 0 THEN 1 ELSE 0 END "
                "    WHEN lower(trim(CAST(is_active AS TEXT))) IN ('1','true','t','yes','y') THEN 1 "
                "    ELSE 0 "
                "  END"
                "), "
                "    is_dirty = ("
                "  CASE "
                "    WHEN is_dirty IS NULL THEN 0 "
                "    WHEN typeof(is_dirty) IN ('integer','real') THEN CASE WHEN is_dirty != 0 THEN 1 ELSE 0 END "
                "    WHEN lower(trim(CAST(is_dirty AS TEXT))) IN ('1','true','t','yes','y') THEN 1 "
                "    ELSE 0 "
                "  END"
                ") "
                "WHERE is_active IS NULL "
                "   OR is_dirty IS NULL "
                "   OR typeof(is_active) NOT IN ('integer','real') "
                "   OR typeof(is_dirty) NOT IN ('integer','real')",
              );

              await customStatement(
                "UPDATE institutional_identity "
                "SET created_at = ("
                "  CASE "
                "    WHEN created_at IS NULL THEN CURRENT_TIMESTAMP "
                "    WHEN typeof(created_at) IN ('integer','real') THEN created_at "
                "    ELSE COALESCE(NULLIF(TRIM(CAST(created_at AS TEXT)), ''), CURRENT_TIMESTAMP) "
                "  END"
                "), "
                "    updated_at = ("
                "  CASE "
                "    WHEN updated_at IS NULL THEN CURRENT_TIMESTAMP "
                "    WHEN typeof(updated_at) IN ('integer','real') THEN updated_at "
                "    ELSE COALESCE(NULLIF(TRIM(CAST(updated_at AS TEXT)), ''), CURRENT_TIMESTAMP) "
                "  END"
                "), "
                "    is_dirty = ("
                "  CASE "
                "    WHEN is_dirty IS NULL THEN 0 "
                "    WHEN typeof(is_dirty) IN ('integer','real') THEN CASE WHEN is_dirty != 0 THEN 1 ELSE 0 END "
                "    WHEN lower(trim(CAST(is_dirty AS TEXT))) IN ('1','true','t','yes','y') THEN 1 "
                "    ELSE 0 "
                "  END"
                ") "
                "WHERE created_at IS NULL "
                "   OR updated_at IS NULL "
                "   OR (typeof(created_at) = 'text' AND TRIM(CAST(created_at AS TEXT)) = '') "
                "   OR (typeof(updated_at) = 'text' AND TRIM(CAST(updated_at AS TEXT)) = '') "
                "   OR is_dirty IS NULL "
                "   OR typeof(is_dirty) NOT IN ('integer','real')",
              );

              await customStatement(
                "UPDATE sessions "
                "SET created_at = COALESCE(created_at, CURRENT_TIMESTAMP) "
                "WHERE created_at IS NULL",
              );
            } catch (_) {
              // Best-effort repair; ignore if tables/columns don't exist.
            }

          }
        },
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // Ensure newly-added tables exist for existing installs.
          // Note: We must bump `schemaVersion` whenever we add new tables, otherwise
          // Drift won't run `onUpgrade` and the app will crash at runtime.
          if (from < 15) {
            if (!await _hasTable('lesson_notes')) {
              await m.createTable(lessonNotes);
            }
            if (!await _hasTable('lesson_note_rows')) {
              await m.createTable(lessonNoteRows);
            }
          }

          // Ensure user_preferences table exists for legacy DBs
          if (!await _hasTable('user_preferences')) {
            await m.createTable(userPreferences);
          }

          if (from < 16) {
            if (!await _hasTable('shop_categories')) {
              await m.createTable(shopCategories);
            }
            if (!await _hasTable('shop_suppliers')) {
              await m.createTable(shopSuppliers);
            }
            if (!await _hasTable('shop_items')) {
              await m.createTable(shopItems);
            }
            if (!await _hasTable('shop_stock_movements')) {
              await m.createTable(shopStockMovements);
            }
            if (!await _hasTable('shop_sales')) {
              await m.createTable(shopSales);
            }
            if (!await _hasTable('shop_sale_items')) {
              await m.createTable(shopSaleItems);
            }
            if (!await _hasTable('student_wallets')) {
              await m.createTable(studentWallets);
            }
            if (!await _hasTable('wallet_transactions')) {
              await m.createTable(walletTransactions);
            }
          }

          if (from < 17) {
            if (!await _hasTable('canteen_menus')) {
              await m.createTable(canteenMenus);
            }
            if (!await _hasTable('canteen_menu_items')) {
              await m.createTable(canteenMenuItems);
            }

            // Add new ShopItems column for role-based canteen separation.
            if (await _hasTable('shop_items')) {
              await _addColumnIfMissing(
                tableName: 'shop_items',
                columnName: 'is_canteen_item',
                sqlType: 'INTEGER NOT NULL DEFAULT 0',
              );
              _invalidateTableColumnsCache('shop_items');
            }
          }

          if (from < 18) {
            if (!await _hasTable('canteen_item_details')) {
              await m.createTable(canteenItemDetails);
            }
            if (!await _hasTable('student_dietary_notes')) {
              await m.createTable(studentDietaryNotes);
            }
            if (!await _hasTable('canteen_portion_plans')) {
              await m.createTable(canteenPortionPlans);
            }
            if (!await _hasTable('canteen_recipes')) {
              await m.createTable(canteenRecipes);
            }
            if (!await _hasTable('canteen_recipe_ingredients')) {
              await m.createTable(canteenRecipeIngredients);
            }
            if (!await _hasTable('canteen_production_records')) {
              await m.createTable(canteenProductionRecords);
            }
            if (!await _hasTable('canteen_temperature_logs')) {
              await m.createTable(canteenTemperatureLogs);
            }
            if (!await _hasTable('canteen_hygiene_checks')) {
              await m.createTable(canteenHygieneChecks);
            }
            if (!await _hasTable('canteen_incidents')) {
              await m.createTable(canteenIncidents);
            }
            if (!await _hasTable('canteen_waste_logs')) {
              await m.createTable(canteenWasteLogs);
            }
            if (!await _hasTable('canteen_orders')) {
              await m.createTable(canteenOrders);
            }
            if (!await _hasTable('canteen_menu_templates')) {
              await m.createTable(canteenMenuTemplates);
            }
            if (!await _hasTable('canteen_menu_template_items')) {
              await m.createTable(canteenMenuTemplateItems);
            }
          }

          if (from < 25) {
            if (!await _hasTable('approval_requests')) {
              await m.createTable(approvalRequests);
            }
            if (!await _hasTable('delegation_tasks')) {
              await m.createTable(delegationTasks);
            }
            if (!await _hasTable('staff_appraisals')) {
              await m.createTable(staffAppraisals);
            }
            if (!await _hasTable('compliance_checklist_items')) {
              await m.createTable(complianceChecklistItems);
            }
            if (!await _hasTable('compliance_checklist_completions')) {
              await m.createTable(complianceChecklistCompletions);
            }
          }

          if (from < 20) {
            if (!await _hasTable('ict_lab_device_loans')) {
              await m.createTable(ictLabDeviceLoans);
            }
          }

          if (from < 21) {
            if (!await _hasTable('science_lab_items')) {
              await m.createTable(scienceLabItems);
            }
            if (!await _hasTable('science_lab_bookings')) {
              await m.createTable(scienceLabBookings);
            }
            if (!await _hasTable('science_lab_experiment_templates')) {
              await m.createTable(scienceLabExperimentTemplates);
            }
            if (!await _hasTable('science_lab_experiment_requests')) {
              await m.createTable(scienceLabExperimentRequests);
            }
            if (!await _hasTable('science_lab_safety_checks')) {
              await m.createTable(scienceLabSafetyChecks);
            }
            if (!await _hasTable('science_lab_incidents')) {
              await m.createTable(scienceLabIncidents);
            }
            if (!await _hasTable('science_lab_usage_sessions')) {
              await m.createTable(scienceLabUsageSessions);
            }
            if (!await _hasTable('science_lab_usage_participants')) {
              await m.createTable(scienceLabUsageParticipants);
            }
          }

          if (from < 22) {
            if (!await _hasTable('student_emergency_contacts')) {
              await m.createTable(studentEmergencyContacts);
            }
            if (!await _hasTable('student_physician_details')) {
              await m.createTable(studentPhysicianDetails);
            }
            if (!await _hasTable('student_vitals_logs')) {
              await m.createTable(studentVitalsLogs);
            }
            if (!await _hasTable('student_health_documents')) {
              await m.createTable(studentHealthDocuments);
            }
            if (!await _hasTable('student_allergy_alerts')) {
              await m.createTable(studentAllergyAlerts);
            }
            if (!await _hasTable('student_chronic_conditions')) {
              await m.createTable(studentChronicConditions);
            }
            if (!await _hasTable('infirmary_visits')) {
              await m.createTable(infirmaryVisits);
            }
            if (!await _hasTable('student_medications')) {
              await m.createTable(studentMedications);
            }
            if (!await _hasTable('medication_administration_logs')) {
              await m.createTable(medicationAdministrationLogs);
            }
            if (!await _hasTable('student_immunizations')) {
              await m.createTable(studentImmunizations);
            }
            if (!await _hasTable('student_checkups')) {
              await m.createTable(studentCheckups);
            }
            if (!await _hasTable('infirmary_inventory_items')) {
              await m.createTable(infirmaryInventoryItems);
            }
            if (!await _hasTable('infirmary_inventory_transactions')) {
              await m.createTable(infirmaryInventoryTransactions);
            }
          }

          // Create any other missing tables first, then repair/add missing columns for legacy DBs.
          await m.createAll();

          // When upgrading to newer versions, older DB files may not contain later-added
          // sync columns. Ensure they exist now.
          if (from < 10) {
            await _ensureStudentsSyncColumns();
            await _ensureStudentRelatedSyncColumns();
            await _ensureLegacyClassesShim();
            await _repairLegacyStaffNulls();
          }

          // Ensure class_subject_teachers points to current FK tables.
          try {
            await _ensureClassSubjectTeachersSchemaCompatible();
          } catch (_) {
            // Best-effort; ignore.
          }

          if (from < 23) {
            if (!await _hasTable('security_visitor_entries')) {
              await m.createTable(securityVisitorEntries);
            }
            if (!await _hasTable('security_incidents')) {
              await m.createTable(securityIncidents);
            }
            if (!await _hasTable('library_books')) {
              await m.createTable(libraryBooks);
            }
            if (!await _hasTable('library_loans')) {
              await m.createTable(libraryLoans);
            }
            if (!await _hasTable('secretary_correspondence_templates')) {
              await m.createTable(secretaryCorrespondenceTemplates);
            }
          }

          if (from < 24) {
            if (await _hasTable('students')) {
              await _addColumnIfMissing(
                tableName: 'students',
                columnName: 'eats_canteen',
                sqlType: 'INTEGER NOT NULL DEFAULT 0',
              );
              await _addColumnIfMissing(
                tableName: 'students',
                columnName: 'takes_school_bus',
                sqlType: 'INTEGER NOT NULL DEFAULT 0',
              );
              _invalidateTableColumnsCache('students');
            }
          }
        },
      );

  Future<void> ensureGesSubjectCatalogSeeded() async {
    // Insert/update by subjectCode (unique).
    // This is safe to call multiple times and across upgrades.
    for (final item in GesSubjectCatalog.items) {
      await into(schoolSubjects).insertOnConflictUpdate(
        SchoolSubjectsCompanion.insert(
          subjectName: item.name,
          subjectCode: item.code,
          description: Value(item.description),
          isCore: Value(item.isCore),
        ),
      );
    }
  }

  // -------- Offerings (subjects per class) --------

  Future<List<SchoolSubject>> getOfferedSubjectsForClass(int classId) async {
    final q = select(schoolSubjects).join([
      innerJoin(
        classSubjectOfferings,
        classSubjectOfferings.subjectId.equalsExp(schoolSubjects.id),
      )
    ])
      ..where(classSubjectOfferings.classId.equals(classId));

    final rows = await q.get();
    return rows.map((r) => r.readTable(schoolSubjects)).toList(growable: false);
  }

  Future<void> ensureGesClassSubjectOfferingsSeeded() async {
    final classes = await select(schoolClasses).get();
    if (classes.isEmpty) return;

    for (final cls in classes) {
      await ensureDefaultOfferingsForClass(cls.id, cls.className, cls.classCode);
    }
  }

  Future<void> ensureDefaultOfferingsForClass(
    int classId,
    String className,
    String classCode,
  ) async {
    // If the class already has any offerings, we assume it's been configured.
    final existingCountExp = classSubjectOfferings.id.count();
    final existingRow = await (selectOnly(classSubjectOfferings)
          ..addColumns([existingCountExp])
          ..where(classSubjectOfferings.classId.equals(classId)))
        .getSingle();
    final existingCount = existingRow.read(existingCountExp) ?? 0;
    if (existingCount > 0) return;

    final level = _inferGesLevel(className: className, classCode: classCode);
    final subjects = await select(schoolSubjects).get();

    bool shouldOffer(SchoolSubject s) {
      final code = (s.subjectCode).toLowerCase().trim();
      switch (level) {
        case _GesClassLevel.kg:
          return code.startsWith('kg.');
        case _GesClassLevel.primary:
          return code.startsWith('be.') && !code.startsWith('jhs.') && !code.startsWith('shs.');
        case _GesClassLevel.jhs:
          return code.startsWith('be.') || code.startsWith('jhs.');
        case _GesClassLevel.shs:
          return code.startsWith('shs.core.');
        case _GesClassLevel.unknown:
          return false;
      }
    }

    final offered = subjects.where(shouldOffer).toList();
    if (offered.isEmpty) return;

    await batch((b) {
      for (final s in offered) {
        b.insert(
          classSubjectOfferings,
          ClassSubjectOfferingsCompanion.insert(
            classId: classId,
            subjectId: s.id,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  /// Deletes a subject and all known dependent rows in a single transaction.
  ///
  /// This prevents SQLite foreign key constraint failures when removing a
  /// subject that is referenced by assessments, enrollments, offerings, etc.
  Future<int> deleteSubjectCascade(int subjectId) async {
    return transaction(() async {
      // 1) Dependent rows of assessments
      final assessmentRows = await (select(assessments)..where((t) => t.subjectId.equals(subjectId))).get();
      final assessmentIds = assessmentRows.map((e) => e.id).toList(growable: false);
      if (assessmentIds.isNotEmpty) {
        await (delete(studentGrades)..where((t) => t.assessmentId.isIn(assessmentIds))).go();
      }
      await (delete(assessments)..where((t) => t.subjectId.equals(subjectId))).go();

      // 2) Direct subject references
      await (delete(termResults)..where((t) => t.subjectId.equals(subjectId))).go();
      await (delete(gradingScales)..where((t) => t.subjectId.equals(subjectId))).go();
      await (delete(questionBank)..where((t) => t.subjectId.equals(subjectId))).go();
      await (delete(examPapers)..where((t) => t.subjectId.equals(subjectId))).go();
      await (delete(classSubjectTeachers)..where((t) => t.subjectId.equals(subjectId))).go();
      await (delete(studentSubjectEnrollments)..where((t) => t.subjectId.equals(subjectId))).go();
      await (delete(classSubjectOfferings)..where((t) => t.subjectId.equals(subjectId))).go();

      // 3) Finally, delete the subject itself.
      return (delete(schoolSubjects)..where((t) => t.id.equals(subjectId))).go();
    });
  }

  // -------- Student subject enrollments --------

  Future<int?> getStudentCurrentClassId(int studentId) async {
    final s = await (select(students)..where((t) => t.id.equals(studentId))).getSingleOrNull();
    return s?.classId;
  }

  Future<void> ensureStudentEnrolledInClassSubjects({
    required int studentId,
    required int classId,
  }) async {
    // Ensure the class has offerings (if none, we leave as-is).
    final offered = await getOfferedSubjectsForClass(classId);
    if (offered.isEmpty) return;

    await batch((b) {
      for (final subj in offered) {
        b.insert(
          studentSubjectEnrollments,
          StudentSubjectEnrollmentsCompanion.insert(
            studentId: studentId,
            classId: classId,
            subjectId: subj.id,
            isActive: const Value(true),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  Future<void> syncStudentEnrollmentsAfterClassChange({
    required int studentId,
    required int? oldClassId,
    required int? newClassId,
  }) async {
    if (oldClassId != null) {
      await (update(studentSubjectEnrollments)
            ..where((t) => t.studentId.equals(studentId) & t.classId.equals(oldClassId)))
          .write(
        StudentSubjectEnrollmentsCompanion(
          isActive: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }

    if (newClassId != null) {
      await ensureStudentEnrolledInClassSubjects(studentId: studentId, classId: newClassId);
    }
  }

  Future<List<SchoolSubject>> getActiveSubjectsForStudent(int studentId) async {
    final classId = await getStudentCurrentClassId(studentId);
    if (classId == null) return const <SchoolSubject>[];

    // Backfill enrollments if missing.
    await ensureStudentEnrolledInClassSubjects(studentId: studentId, classId: classId);

    final q = select(schoolSubjects).join([
      innerJoin(
        studentSubjectEnrollments,
        studentSubjectEnrollments.subjectId.equalsExp(schoolSubjects.id),
      )
    ])
      ..where(studentSubjectEnrollments.studentId.equals(studentId))
      ..where(studentSubjectEnrollments.classId.equals(classId))
      ..where(studentSubjectEnrollments.isActive.equals(true));

    final rows = await q.get();
    return rows.map((r) => r.readTable(schoolSubjects)).toList(growable: false);
  }

  Future<Set<int>> getActiveSubjectIdsForStudent(int studentId) async {
    final classId = await getStudentCurrentClassId(studentId);
    if (classId == null) return <int>{};

    final rows = await (select(studentSubjectEnrollments)
          ..where((t) => t.studentId.equals(studentId) & t.classId.equals(classId) & t.isActive.equals(true)))
        .get();
    return rows.map((r) => r.subjectId).toSet();
  }

  Future<void> setStudentSubjectActive({
    required int studentId,
    required int classId,
    required int subjectId,
    required bool isActive,
  }) async {
    // Update if exists, else insert.
    final existing = await (select(studentSubjectEnrollments)
          ..where((t) => t.studentId.equals(studentId) & t.classId.equals(classId) & t.subjectId.equals(subjectId))
          ..limit(1))
        .getSingleOrNull();

    if (existing == null) {
      await into(studentSubjectEnrollments).insert(
        StudentSubjectEnrollmentsCompanion.insert(
          studentId: studentId,
          classId: classId,
          subjectId: subjectId,
          isActive: Value(isActive),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      return;
    }

    await (update(studentSubjectEnrollments)..where((t) => t.id.equals(existing.id))).write(
      StudentSubjectEnrollmentsCompanion(
        isActive: Value(isActive),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  _GesClassLevel _inferGesLevel({required String className, required String classCode}) {
    final name = className.toLowerCase();
    final code = classCode.toLowerCase();

    bool hasToken(String token) => name.contains(token) || code.contains(token);

    if (hasToken('kg') || hasToken('k.g') || hasToken('kindergarten')) {
      return _GesClassLevel.kg;
    }
    if (hasToken('jhs') || hasToken('j.h.s') || hasToken('junior high')) {
      return _GesClassLevel.jhs;
    }
    if (hasToken('shs') || hasToken('s.h.s') || hasToken('senior high') || hasToken('form')) {
      return _GesClassLevel.shs;
    }

    final primaryMatch = RegExp(r'\b(p|primary)\s*([1-6])\b').hasMatch(name) ||
        RegExp(r'^p[1-6]').hasMatch(code) ||
        RegExp(r'\bgrade\s*([1-6])\b').hasMatch(name);
    if (primaryMatch) {
      return _GesClassLevel.primary;
    }

    return _GesClassLevel.unknown;
  }

  // Institutional Identity Queries
  Future<InstitutionalIdentityData?> getInstitutionalIdentity() async {
    final sql = await _institutionalIdentitySelectSql();
    final row = await customSelect(sql, readsFrom: {institutionalIdentity}).getSingleOrNull();
    if (row == null) return null;
    return institutionalIdentity.map(row.data);
  }

  Future<int> createInstitutionalIdentity(InstitutionalIdentityCompanion entry) async {
    return await into(institutionalIdentity).insert(entry);
  }

  Future<void> upsertInstitutionalIdentity(InstitutionalIdentityCompanion entry) async {
    // IMPORTANT:
    // `insertOnConflictUpdate` still performs an INSERT attempt, which will fail
    // when the companion omits NOT NULL columns without defaults (e.g.
    // `masterPasswordHash`). For settings updates we often write partial
    // companions, so we do an UPDATE-first upsert.
    final updated = await (update(institutionalIdentity)..where((t) => t.id.isNotNull())).write(entry);
    if (updated > 0) return;

    if (!entry.masterPasswordHash.present) {
      throw InvalidDataException(
        'Institutional identity is missing required fields (masterPasswordHash). '
        'Please re-register the institution or restore a valid backup.',
      );
    }

    await into(institutionalIdentity).insert(entry);
  }

  Future<bool> updateInstitutionalIdentity(InstitutionalIdentityCompanion entry) async {
    return await (update(institutionalIdentity)..where((t) => t.id.isNotNull())).write(entry) > 0;
  }

  // User Queries
  Future<List<User>> getAllUsers() async {
    final sql = await _usersSelectSql(withWhereEmail: false);
    final rows = await customSelect(sql, readsFrom: {users}).get();

    return rows.map((row) => users.map(row.data)).toList(growable: false);
  }

  Future<User?> getUserByEmail(String email) async {
    final normalized = email.toLowerCase().trim();

    final sql = await _usersSelectSql(withWhereEmail: true);
    final row = await customSelect(
      sql,
      variables: [Variable<String>(normalized)],
      readsFrom: {users},
    ).getSingleOrNull();

    if (row == null) return null;
    return users.map(row.data);
  }

  Future<User?> getUserById(int id) async {
    return await (select(users)..where((u) => u.id.equals(id))).getSingleOrNull();
  }

  Future<int> createUser(UsersCompanion entry) async {
    return await into(users).insert(entry);
  }

  Future<bool> updateUser(UsersCompanion entry) async {
    return await (update(users)..where((t) => t.id.equals(entry.id.value))).write(entry) > 0;
  }

  Future<int> deleteUser(int id) async {
    return await (delete(users)..where((u) => u.id.equals(id))).go();
  }

  // Admin count for robust registration check
  Future<int> getAdminCount() async {
    final countExp = users.id.count();
    final query = selectOnly(users)..addColumns([countExp])..where(users.role.equals('admin'));
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  // Session Queries
  Future<Session?> getSessionByToken(String token) async {
    return await (select(sessions)..where((s) => s.token.equals(token))).getSingleOrNull();
  }

  Future<int> createSession(SessionsCompanion entry) async {
    return await into(sessions).insert(entry);
  }

  Future<int> deleteSession(String token) async {
    return await (delete(sessions)..where((s) => s.token.equals(token))).go();
  }

  Future<int> deleteExpiredSessions() async {
    return await (delete(sessions)..where((s) => s.expiresAt.isSmallerThanValue(DateTime.now()))).go();
  }

  // Health Record Queries
  Future<HealthRecord?> getHealthRecordByStudentId(int studentId) async {
    return await (select(healthRecords)..where((r) => r.studentId.equals(studentId))).getSingleOrNull();
  }

  Future<int> createHealthRecord(HealthRecordsCompanion entry) async {
    return await into(healthRecords).insert(entry);
  }

  Future<bool> updateHealthRecord(HealthRecordsCompanion entry) async {
    return await (update(healthRecords)..where((t) => t.id.equals(entry.id.value))).write(entry) > 0;
  }

  // Academic History Queries
  Future<List<AcademicHistoryData>> getAcademicHistoryByStudentId(int studentId) async {
    return await (select(academicHistory)..where((r) => r.studentId.equals(studentId))).get();
  }

  Future<int> createAcademicHistory(AcademicHistoryCompanion entry) async {
    return await into(academicHistory).insert(entry);
  }

  // Class Subject Teacher Queries
  Future<List<ClassSubjectTeacher>> getTeachersForClass(int classId) async {
    return await (select(classSubjectTeachers)..where((r) => r.classId.equals(classId))).get();
  }

  Future<int> assignTeacherToClassSubject(ClassSubjectTeachersCompanion entry) async {
    // Important: Avoid `INSERT OR REPLACE` here.
    // REPLACE is implemented as DELETE + INSERT, which can trip foreign-key
    // constraints (and can also change the auto-incremented `id`).
    // We want to keep the existing row and just update `teacher_id` on conflict.

    final classId = entry.classId.value;
    final subjectId = entry.subjectId.value;
    final teacherId = entry.teacherId.value;

    final classExists = await (select(schoolClasses)..where((t) => t.id.equals(classId))).getSingleOrNull();
    if (classExists == null) {
      throw StateError('Class not found (id: $classId)');
    }

    final subjectExists = await (select(schoolSubjects)..where((t) => t.id.equals(subjectId))).getSingleOrNull();
    if (subjectExists == null) {
      throw StateError('Subject not found (id: $subjectId)');
    }

    final teacherExists = await (select(users)..where((t) => t.id.equals(teacherId))).getSingleOrNull();
    if (teacherExists == null) {
      throw StateError('Teacher user not found (id: $teacherId)');
    }

    // Upsert on unique key (class_id, subject_id).
    return await into(classSubjectTeachers).insertOnConflictUpdate(entry);
  }

  // Emergency Reset Queries - Resilient table clearing
  Future<void> emergencyReset() async {
    final tableNames = [
      'sessions', 'users', 'institutional_identity', 'students', 'school_classes', 
      'school_subjects', 'staff', 'health_records', 'academic_history', 
      'class_subject_offerings',
      'student_subject_enrollments',
      'class_subject_teachers', 'fee_structures', 'payments', 'expenses',
      'activity_logs', 'attendance_sessions', 'attendance_records',
      'assessments', 'student_grades', 'term_results', 'grading_scales',
      'system_settings', 'report_summaries', 'question_bank', 'exam_papers',
      'staff_salaries', 'payroll_records', 'institutional_expenses'
      , 'sync_metadata', 'sync_outbox'
    ];

    // Best-effort speed-up: disable FK checks during bulk deletes.
    try {
      await customStatement('PRAGMA foreign_keys = OFF');
    } catch (_) {
      // ignore
    }

    await transaction(() async {
      await batch((b) {
        for (final name in tableNames) {
          // Use customStatement to avoid issues with table class objects if they aren't initialized
          b.customStatement('DELETE FROM "$name"');
        }
        // Reset autoincrement counters where SQLite uses sqlite_sequence.
        b.customStatement('DELETE FROM sqlite_sequence');
      });
    });

    // Restore FK enforcement.
    try {
      await customStatement('PRAGMA foreign_keys = ON');
    } catch (_) {
      // ignore
    }
  }

  // Sync helpers
  Future<String?> getSyncMetadataValue(String key) async {
    final row = await (select(syncMetadata)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setSyncMetadataValue(String key, String? value) async {
    await into(syncMetadata).insertOnConflictUpdate(
      SyncMetadataCompanion.insert(
        key: key,
        value: Value(value),
      ),
    );
  }

  Future<List<SyncOutboxData>> getPendingOutbox({int limit = 200}) async {
    return (select(syncOutbox)
          ..where((t) => t.status.isIn(['pending', 'failed', 'sent']))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<void> markOutboxAttempted(int id) async {
    await customStatement(
      'UPDATE sync_outbox '
      'SET attempt_count = attempt_count + 1, last_attempt_at = CURRENT_TIMESTAMP '
      'WHERE id = ?',
      [id],
    );
  }

  Future<void> markOutboxStatus(int id, String status, {String? serverAck}) async {
    await (update(syncOutbox)..where((t) => t.id.equals(id))).write(
      SyncOutboxCompanion(
        status: Value(status),
        serverAck: Value(serverAck),
      ),
    );
  }

  Future<void> deleteOutboxByOpIds(Iterable<String> opIds) async {
    final ids = opIds.where((e) => e.trim().isNotEmpty).toList();
    if (ids.isEmpty) return;
    await (delete(syncOutbox)..where((t) => t.opId.isIn(ids))).go();
  }
}

enum _GesClassLevel {
  kg,
  primary,
  jhs,
  shs,
  unknown,
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final file = await getDatabaseFile();
    return NativeDatabase(
      file,
      setup: (db) {
        // Improve reliability on desktop where multiple processes / antivirus can
        // temporarily lock the DB file.
        db.execute('PRAGMA busy_timeout = 60000');
        // Better concurrency for reads during writes.
        db.execute('PRAGMA journal_mode = WAL');
        db.execute('PRAGMA foreign_keys = ON');
      },
    );
  });
}

Future<File> getDatabaseFile() async {
  final dbFolder = await getApplicationDocumentsDirectory();
  return File(p.join(dbFolder.path, 'ghanaclass.db'));
}
