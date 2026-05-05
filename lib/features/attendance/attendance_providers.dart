import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'attendance_service.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';

final attendanceServiceProvider = Provider<AttendanceService>((ref) {
  final db = ref.watch(databaseProvider);
  return AttendanceService(db);
});

final classStudentsProvider = FutureProvider.family<List<Student>, int>((ref, classId) async {
  return ref.watch(attendanceServiceProvider).getStudentsForClass(classId);
});

final attendanceSessionProvider = FutureProvider.family<AttendanceSession?, AttendanceQuery>((ref, query) async {
  return ref.watch(attendanceServiceProvider).getSession(query.classId, query.date, period: query.period);
});

final sessionRecordsProvider = FutureProvider.family<List<AttendanceRecord>, int>((ref, sessionId) async {
  return ref.watch(attendanceServiceProvider).getRecordsForSession(sessionId);
});

class AttendanceQuery {
  final int classId;
  final DateTime date;
  final String? period;

  AttendanceQuery({required this.classId, required this.date, this.period});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendanceQuery &&
          runtimeType == other.runtimeType &&
          classId == other.classId &&
          date == other.date &&
          period == other.period;

  @override
  int get hashCode => classId.hashCode ^ date.hashCode ^ period.hashCode;
}
