import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'academic_service.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';

final academicServiceProvider = Provider<AcademicService>((ref) {
  final db = ref.watch(databaseProvider);
  return AcademicService(db);
});

final classesProvider = FutureProvider<List<SchoolClassesData>>((ref) async {
  return ref.watch(academicServiceProvider).getAllClasses();
});

final subjectsProvider = FutureProvider<List<SchoolSubject>>((ref) async {
  return ref.watch(academicServiceProvider).getAllSubjects();
});

final subjectsForClassProvider = FutureProvider.family<List<SchoolSubject>, int>((ref, classId) async {
  return ref.watch(academicServiceProvider).getSubjectsForClass(classId);
});

final classMappingsProvider = FutureProvider.family<List<ClassSubjectTeacher>, int>((ref, classId) async {
  return ref.watch(academicServiceProvider).getClassMappings(classId);
});

final teacherMappingsProvider = FutureProvider.family<List<ClassSubjectTeacher>, int>((ref, teacherId) async {
  return ref.watch(academicServiceProvider).getTeacherMappings(teacherId);
});

final classAssignmentSummariesProvider = FutureProvider<Map<int, ClassAssignmentsSummary>>((ref) async {
  return ref.watch(academicServiceProvider).getClassAssignmentSummaries();
});
