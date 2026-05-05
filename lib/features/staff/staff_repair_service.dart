import 'package:ghanaclass_school_management/core/database/app_database.dart';

class StaffRepairSnapshot {
  final int totalStaff;
  final int rowsNeedingDefaultBackfill;
  final int rowsMissingUserId;
  final int orphanUserIds;
  final int linkedUsersNeedingNameSync;
  final int linkedUsersNeedingPhoneSync;
  final int linkedUsersNeedingActiveSync;

  const StaffRepairSnapshot({
    required this.totalStaff,
    required this.rowsNeedingDefaultBackfill,
    required this.rowsMissingUserId,
    required this.orphanUserIds,
    required this.linkedUsersNeedingNameSync,
    required this.linkedUsersNeedingPhoneSync,
    required this.linkedUsersNeedingActiveSync,
  });

  int get totalIssues =>
      rowsNeedingDefaultBackfill +
      rowsMissingUserId +
      orphanUserIds +
      linkedUsersNeedingNameSync +
      linkedUsersNeedingPhoneSync +
      linkedUsersNeedingActiveSync;
}

class StaffRepairReport {
  final DateTime startedAt;
  final DateTime finishedAt;
  final StaffRepairSnapshot before;
  final StaffRepairSnapshot after;

  const StaffRepairReport({
    required this.startedAt,
    required this.finishedAt,
    required this.before,
    required this.after,
  });

  Duration get duration => finishedAt.difference(startedAt);
}

class StaffRepairService {
  final AppDatabase _db;

  const StaffRepairService(this._db);

  Future<StaffRepairSnapshot> snapshot() async {
    // Keep the WHERE logic aligned with AppDatabase._repairLegacyStaffNulls.
    final totalStaff = await _scalarInt('SELECT COUNT(*) AS c FROM staff');

    final rowsNeedingDefaultBackfill = await _scalarInt(
      "SELECT COUNT(*) AS c FROM staff "
      "WHERE staff_id IS NULL "
      "   OR TRIM(staff_id) = '' "
      "   OR first_name IS NULL "
      "   OR TRIM(first_name) = '' "
      "   OR last_name IS NULL "
      "   OR TRIM(last_name) = '' "
      "   OR gender IS NULL "
      "   OR TRIM(gender) = '' "
      "   OR phone_number IS NULL "
      "   OR TRIM(phone_number) = '' "
      "   OR position IS NULL "
      "   OR TRIM(position) = '' "
      "   OR date_of_birth IS NULL "
      "   OR typeof(date_of_birth) NOT IN ('integer','real') "
      "   OR hire_date IS NULL "
      "   OR typeof(hire_date) NOT IN ('integer','real') "
      "   OR base_salary IS NULL "
      "   OR typeof(base_salary) NOT IN ('integer','real') "
      "   OR is_active IS NULL "
      "   OR is_dirty IS NULL "
      "   OR created_at IS NULL "
      "   OR updated_at IS NULL",
    );

    final rowsMissingUserId = await _scalarInt(
      'SELECT COUNT(*) AS c FROM staff WHERE user_id IS NULL',
    );

    final orphanUserIds = await _scalarInt(
      "SELECT COUNT(DISTINCT user_id) AS c "
      "FROM staff "
      "WHERE user_id IS NOT NULL "
      "  AND user_id NOT IN (SELECT id FROM users)",
    );

    final linkedUsersNeedingNameSync = await _scalarInt(
      "SELECT COUNT(*) AS c "
      "FROM staff s "
      "JOIN users u ON u.id = s.user_id "
      "WHERE u.role != 'admin' "
      "  AND (u.full_name IS NULL "
      "       OR TRIM(u.full_name) = '' "
      "       OR TRIM(u.full_name) != TRIM(s.first_name) || ' ' || TRIM(s.last_name))",
    );

    final linkedUsersNeedingPhoneSync = await _scalarInt(
      "SELECT COUNT(*) AS c "
      "FROM staff s "
      "JOIN users u ON u.id = s.user_id "
      "WHERE u.role != 'admin' "
      "  AND s.phone_number IS NOT NULL "
      "  AND TRIM(s.phone_number) NOT IN ('', 'N/A') "
      "  AND COALESCE(TRIM(u.phone_number), '') != TRIM(s.phone_number)",
    );

    final linkedUsersNeedingActiveSync = await _scalarInt(
      "SELECT COUNT(*) AS c "
      "FROM staff s "
      "JOIN users u ON u.id = s.user_id "
      "WHERE u.role != 'admin' "
      "  AND u.is_active != s.is_active",
    );

    return StaffRepairSnapshot(
      totalStaff: totalStaff,
      rowsNeedingDefaultBackfill: rowsNeedingDefaultBackfill,
      rowsMissingUserId: rowsMissingUserId,
      orphanUserIds: orphanUserIds,
      linkedUsersNeedingNameSync: linkedUsersNeedingNameSync,
      linkedUsersNeedingPhoneSync: linkedUsersNeedingPhoneSync,
      linkedUsersNeedingActiveSync: linkedUsersNeedingActiveSync,
    );
  }

  Future<StaffRepairReport> repairAndReport({bool syncUsersFromStaff = false}) async {
    final startedAt = DateTime.now();
    final before = await snapshot();

    await _db.repairStaffRows();

    if (syncUsersFromStaff) {
      await _syncUsersFromStaff();
    }

    final after = await snapshot();
    final finishedAt = DateTime.now();

    return StaffRepairReport(
      startedAt: startedAt,
      finishedAt: finishedAt,
      before: before,
      after: after,
    );
  }

  Future<void> _syncUsersFromStaff() async {
    // NOTE: Keep this conservative. We avoid touching admins and avoid overwriting
    // user phone numbers with placeholders like 'N/A'.
    //
    // Also: We use an integer "now" expression to stay compatible with legacy
    // DBs that store dates as millis.
    const nowMsExpr = "(CAST(strftime('%s','now') AS INTEGER) * 1000)";

    await _db.customStatement(
      "UPDATE users "
      "SET "
      "  full_name = ( "
      "    SELECT TRIM(s.first_name) || ' ' || TRIM(s.last_name) "
      "    FROM staff s "
      "    WHERE s.user_id = users.id "
      "    LIMIT 1 "
      "  ), "
      "  phone_number = ( "
      "    SELECT "
      "      CASE "
      "        WHEN s.phone_number IS NULL THEN users.phone_number "
      "        WHEN TRIM(s.phone_number) IN ('', 'N/A') THEN users.phone_number "
      "        ELSE TRIM(s.phone_number) "
      "      END "
      "    FROM staff s "
      "    WHERE s.user_id = users.id "
      "    LIMIT 1 "
      "  ), "
      "  is_active = ( "
      "    SELECT s.is_active "
      "    FROM staff s "
      "    WHERE s.user_id = users.id "
      "    LIMIT 1 "
      "  ), "
      "  updated_at = $nowMsExpr "
      "WHERE role != 'admin' "
      "  AND id IN (SELECT user_id FROM staff WHERE user_id IS NOT NULL) "
      "  AND ( "
      "    full_name IS NULL "
      "    OR TRIM(full_name) = '' "
      "    OR TRIM(full_name) != ( "
      "      SELECT TRIM(s.first_name) || ' ' || TRIM(s.last_name) "
      "      FROM staff s "
      "      WHERE s.user_id = users.id "
      "      LIMIT 1 "
      "    ) "
      "    OR ( "
      "      (SELECT s.phone_number FROM staff s WHERE s.user_id = users.id LIMIT 1) IS NOT NULL "
      "      AND TRIM((SELECT s.phone_number FROM staff s WHERE s.user_id = users.id LIMIT 1)) NOT IN ('', 'N/A') "
      "      AND COALESCE(TRIM(phone_number), '') != TRIM((SELECT s.phone_number FROM staff s WHERE s.user_id = users.id LIMIT 1)) "
      "    ) "
      "    OR is_active != ( "
      "      SELECT s.is_active "
      "      FROM staff s "
      "      WHERE s.user_id = users.id "
      "      LIMIT 1 "
      "    ) "
      "  )",
    );
  }

  Future<int> _scalarInt(String sql) async {
    final rows = await _db.customSelect(sql, readsFrom: const {}).get();
    if (rows.isEmpty) return 0;
    final v = rows.first.data['c'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}
