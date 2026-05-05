import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/features/attendance/staff_attendance_service.dart';

final staffAttendanceServiceProvider = Provider<StaffAttendanceService>((ref) {
  final db = ref.watch(databaseProvider);
  return StaffAttendanceService(db);
});

final staffAttendanceSessionProvider = FutureProvider.family<StaffAttendanceSession?, StaffAttendanceQuery>((ref, query) async {
  return ref.watch(staffAttendanceServiceProvider).getSession(query.date, period: query.period);
});

final staffAttendanceRecordsProvider = FutureProvider.family<List<StaffAttendanceRecord>, int>((ref, sessionId) async {
  return ref.watch(staffAttendanceServiceProvider).getRecordsForSession(sessionId);
});

class StaffAttendanceQuery {
  final DateTime date;
  final String? period;

  StaffAttendanceQuery({required this.date, this.period});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StaffAttendanceQuery &&
          runtimeType == other.runtimeType &&
          date == other.date &&
          period == other.period;

  @override
  int get hashCode => date.hashCode ^ period.hashCode;
}
