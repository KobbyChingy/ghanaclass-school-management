import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghanaclass_school_management/core/providers/database_provider.dart';
import 'package:ghanaclass_school_management/core/providers/sync_providers.dart';
import 'package:ghanaclass_school_management/features/students/student_service.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';

final studentServiceProvider = Provider<StudentService>((ref) {
  final database = ref.watch(databaseProvider);
  final sync = ref.watch(syncServiceProvider);
  return StudentService(database, syncService: sync);
});

final studentsListProvider = FutureProvider.family<List<Student>, StudentFilter>((ref, filter) async {
  final service = ref.watch(studentServiceProvider);
  return await service.getAllStudents(
    searchQuery: filter.searchQuery,
    statusFilter: filter.statusFilter,
    classId: filter.classId,
  );
});

final studentProfileProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, id) async {
  final service = ref.watch(studentServiceProvider);
  return await service.getStudentProfile(id);
});

final studentEnrolledSubjectsProvider = FutureProvider.family<List<SchoolSubject>, int>((ref, studentId) async {
  final service = ref.watch(studentServiceProvider);
  return service.getCurrentEnrolledSubjects(studentId);
});

final studentOfferedSubjectsProvider = FutureProvider.family<List<SchoolSubject>, int>((ref, studentId) async {
  final service = ref.watch(studentServiceProvider);
  return service.getOfferedSubjectsForStudentClass(studentId);
});

class StudentFilter {
  final String? searchQuery;
  final String? statusFilter;
  final int? classId;

  StudentFilter({this.searchQuery, this.statusFilter, this.classId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentFilter &&
          runtimeType == other.runtimeType &&
          searchQuery == other.searchQuery &&
          statusFilter == other.statusFilter &&
          classId == other.classId;

  @override
  int get hashCode => searchQuery.hashCode ^ statusFilter.hashCode ^ classId.hashCode;
}
