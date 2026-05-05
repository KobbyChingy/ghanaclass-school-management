import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/features/teachers/teacher_service.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';

final teacherServiceProvider = Provider<TeacherService>((ref) {
  final database = ref.watch(databaseProvider);
  return TeacherService(database);
});

final headTeacherStudentsProvider = FutureProvider<List<Student>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  
  final service = ref.watch(teacherServiceProvider);
  return await service.getStudentsForHeadTeacher(user.id);
});

final subjectTeacherStudentsProvider = FutureProvider<List<Student>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  
  final service = ref.watch(teacherServiceProvider);
  return await service.getStudentsForSubjectTeacher(user.id);
});

final teacherAssignmentsProvider = FutureProvider<List<TeacherClassSubjectAccess>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  
  final service = ref.watch(teacherServiceProvider);
  return await service.getAssessmentAccess(user.id);
});

final isHeadOrClassTeacherProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  if (user.role != UserRole.teacher.name) return false;

  final service = ref.watch(teacherServiceProvider);
  return service.isHeadOrClassTeacher(user.id);
});

final isSubjectTeacherProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  if (user.role != UserRole.teacher.name) return false;

  final service = ref.watch(teacherServiceProvider);
  return service.isSubjectTeacher(user.id);
});

final canAccessExamsToolsProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  if (user.role != UserRole.teacher.name) return false;

  final service = ref.watch(teacherServiceProvider);
  final isHeadOrClass = await service.isHeadOrClassTeacher(user.id);
  if (isHeadOrClass) return true;

  final isSubject = await service.isSubjectTeacher(user.id);
  return isSubject;
});

final headOrClassTeacherClassIdProvider = FutureProvider<int?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  if (user.role != UserRole.teacher.name) return null;

  final service = ref.watch(teacherServiceProvider);
  return service.getHeadOrClassTeacherClassId(user.id);
});

/// All class IDs a teacher can access for assessments/reports.
///
/// Includes:
/// - The teacher's head/class teacher class (if any)
/// - Any classes where the teacher is assigned as a subject teacher
final teacherAccessibleClassIdsProvider = FutureProvider<List<int>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  if (user.role != UserRole.teacher.name) return const [];

  final headClassId = await ref.watch(headOrClassTeacherClassIdProvider.future);
  final assignments = await ref.watch(teacherAssignmentsProvider.future);

  final ids = <int>{};
  if (headClassId != null) ids.add(headClassId);
  for (final a in assignments) {
    ids.add(a.classId);
  }

  final out = ids.toList()..sort();
  return out;
});

/// All students a teacher can access.
///
/// This merges (and de-duplicates) students from:
/// - Head/class teacher class
/// - Subject teacher assignments
final teacherAccessibleStudentsProvider = FutureProvider<List<Student>>((ref) async {
  final head = await ref.watch(headTeacherStudentsProvider.future);
  final subject = await ref.watch(subjectTeacherStudentsProvider.future);

  final byId = <int, Student>{};
  for (final s in head) {
    byId[s.id] = s;
  }
  for (final s in subject) {
    byId[s.id] = s;
  }

  final out = byId.values.toList()
    ..sort((a, b) {
      final last = a.lastName.toLowerCase().compareTo(b.lastName.toLowerCase());
      if (last != 0) return last;
      final first = a.firstName.toLowerCase().compareTo(b.firstName.toLowerCase());
      if (first != 0) return first;
      return a.studentId.toLowerCase().compareTo(b.studentId.toLowerCase());
    });
  return out;
});

/// Unread parent -> teacher message count for the current teacher.
///
/// Counts unread messages where:
/// - senderType == 'parent'
/// - isRead == false
/// - studentId is among the teacher's accessible students
/// - teacherId is null (broadcast) OR matches current teacher
final teacherUnreadParentMessagesCountProvider = FutureProvider<int>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return 0;
  if (user.role != UserRole.teacher.name) return 0;

  final students = await ref.watch(teacherAccessibleStudentsProvider.future);
  if (students.isEmpty) return 0;

  final studentIds = students.map((s) => s.id).toList(growable: false);
  final db = ref.watch(databaseProvider);

  final countExp = db.parentMessages.id.count();
  final query = db.selectOnly(db.parentMessages)..addColumns([countExp]);
  query.where(db.parentMessages.senderType.equals('parent'));
  query.where(db.parentMessages.isRead.equals(false));
  query.where(db.parentMessages.studentId.isIn(studentIds));
  query.where(db.parentMessages.teacherId.isNull() | db.parentMessages.teacherId.equals(user.id));

  final row = await query.getSingle();
  return row.read(countExp) ?? 0;
});
