import 'package:drift/drift.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';

class AdminKpis {
  final int totalStudents;
  final int totalStaff;
  final double attendanceRate;
  final double totalRevenue;
  final double totalOutstanding;

  AdminKpis({
    required this.totalStudents,
    required this.totalStaff,
    required this.attendanceRate,
    required this.totalRevenue,
    required this.totalOutstanding,
  });
}

class AdminOversightService {
  final AppDatabase _database;

  AdminOversightService(this._database);

  Future<AdminKpis> getGlobalKpis(int term, int year) async {
    // 1. Student Count
    final studentCountQuery = _database.students.id.count();
    final studentCount = await (_database.selectOnly(_database.students)..addColumns([studentCountQuery])).getSingle();
    
    // 2. Staff Count
    final staffCountQuery = _database.staff.id.count();
    final staffCount = await (_database.selectOnly(_database.staff)..addColumns([staffCountQuery])).getSingle();

    // 3. Attendance Rate (Today)
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final sessions = await (_database.select(_database.attendanceSessions)
      ..where((s) => s.date.isBiggerOrEqualValue(todayStart))).get();
    
    double attendanceRate = 0.0;
    if (sessions.isNotEmpty) {
      int totalPresent = 0;
      int totalExpected = 0;
      for (var s in sessions) {
        final records = await (_database.select(_database.attendanceRecords)
          ..where((r) => r.sessionId.equals(s.id))).get();
        totalExpected += records.length;
        totalPresent += records.where((r) => r.status == 'present').length;
      }
      attendanceRate = totalExpected > 0 ? (totalPresent / totalExpected) * 100 : 0.0;
    }

    // 4. Revenue
    final payments = await _database.select(_database.payments).get();
    final totalRevenue = payments.fold(0.0, (sum, p) => sum + p.amountPaid);

    // 5. Outstanding (Estimate based on fee structures vs payments)
    final feeStructures = await _database.select(_database.feeStructures).get();
    final enrolments = await _database.select(_database.students).get();
    double totalExpectedRevenue = 0.0;
    for (var s in enrolments) {
      final classFees = feeStructures.where((f) => f.classId == s.classId || f.classId == null);
      for (var f in classFees) {
        totalExpectedRevenue += f.amount;
      }
    }
    final totalOutstanding = totalExpectedRevenue - totalRevenue;

    return AdminKpis(
      totalStudents: studentCount.read(studentCountQuery) ?? 0,
      totalStaff: staffCount.read(staffCountQuery) ?? 0,
      attendanceRate: attendanceRate,
      totalRevenue: totalRevenue,
      totalOutstanding: totalOutstanding > 0 ? totalOutstanding : 0.0,
    );
  }
}
