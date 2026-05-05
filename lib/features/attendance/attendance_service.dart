import 'package:ghanaclass_school_management/core/database/app_database.dart';

class AttendanceService {
  final AppDatabase _database;

  AttendanceService(this._database);

  // Sessions
  Future<int> createSession(AttendanceSessionsCompanion entry) async {
    return await _database.into(_database.attendanceSessions).insert(entry);
  }

  Future<AttendanceSession?> getSession(int classId, DateTime date, {String? period}) async {
    return await (_database.select(_database.attendanceSessions)
          ..where((t) => t.classId.equals(classId))
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

  // Records
  Future<void> saveAttendanceRecords(List<AttendanceRecordsCompanion> records) async {
    await _database.transaction(() async {
      for (final record in records) {
        await _database.into(_database.attendanceRecords).insertOnConflictUpdate(record);
      }
    });
  }

  Future<List<AttendanceRecord>> getRecordsForSession(int sessionId) async {
    return await (_database.select(_database.attendanceRecords)
          ..where((t) => t.sessionId.equals(sessionId)))
        .get();
  }
  
  // High level
  Future<List<Student>> getStudentsForClass(int classId) async {
     return await (_database.select(_database.students)
          ..where((t) => t.classId.equals(classId)))
        .get();
  }
}
