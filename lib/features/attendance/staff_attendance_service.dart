import 'package:ghanaclass_school_management/core/database/app_database.dart';

class StaffAttendanceService {
  final AppDatabase _database;

  StaffAttendanceService(this._database);

  Future<int> createSession(StaffAttendanceSessionsCompanion entry) async {
    return _database.into(_database.staffAttendanceSessions).insert(entry);
  }

  Future<StaffAttendanceSession?> getSession(DateTime date, {String? period}) async {
    return (_database.select(_database.staffAttendanceSessions)
          ..where((t) => t.date.equals(date))
          ..where((t) {
            if (period != null) {
              return t.period.equals(period);
            } else {
              return t.period.isNull();
            }
          }))
        .getSingleOrNull();
  }

  Future<void> saveRecords(List<StaffAttendanceRecordsCompanion> records) async {
    await _database.transaction(() async {
      for (final record in records) {
        await _database.into(_database.staffAttendanceRecords).insertOnConflictUpdate(record);
      }
    });
  }

  Future<List<StaffAttendanceRecord>> getRecordsForSession(int sessionId) async {
    return (_database.select(_database.staffAttendanceRecords)
          ..where((t) => t.sessionId.equals(sessionId)))
        .get();
  }
}
