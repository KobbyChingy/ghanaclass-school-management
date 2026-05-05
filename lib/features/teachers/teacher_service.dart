import 'package:drift/drift.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';

class TeacherClassSubjectAccess {
  final int classId;
  final int subjectId;
  final bool viaHeadTeacherRole;

  const TeacherClassSubjectAccess({
    required this.classId,
    required this.subjectId,
    required this.viaHeadTeacherRole,
  });
}

class TeacherService {
  final AppDatabase _database;

  TeacherService(this._database);

  /// Get students for a head teacher (all students in their assigned class)
  Future<List<Student>> getStudentsForHeadTeacher(int userId) async {
    final classRecord = await (_database.select(_database.schoolClasses)
      ..where((c) => c.headTeacherId.equals(userId))).getSingleOrNull();
    
    if (classRecord == null) return [];
    
    return await (_database.select(_database.students)
      ..where((s) => s.classId.equals(classRecord.id))).get();
  }

  /// Get students for a subject teacher (students taking their subject in specific classes)
  Future<List<Student>> getStudentsForSubjectTeacher(int userId) async {
    // Preferred: use enrollments to restrict to only students taking the subjects
    // the teacher is assigned to in each class.
    try {
      final enrollmentCountExp = _database.studentSubjectEnrollments.id.count();
      final enrollmentCountRow = await (_database.selectOnly(_database.studentSubjectEnrollments)
            ..addColumns([enrollmentCountExp]))
          .getSingle();
      final enrollmentCount = enrollmentCountRow.read(enrollmentCountExp) ?? 0;

      if (enrollmentCount > 0) {
        final rows = await _database.customSelect(
          '''
          SELECT DISTINCT s.*
          FROM students s
          INNER JOIN student_subject_enrollments e
            ON e.student_id = s.id
          INNER JOIN class_subject_teachers cst
            ON cst.class_id = e.class_id
           AND cst.subject_id = e.subject_id
          WHERE cst.teacher_id = ?
          ''',
          variables: [Variable<int>(userId)],
          readsFrom: {
            _database.students,
            _database.studentSubjectEnrollments,
            _database.classSubjectTeachers,
          },
        ).get();

        return rows.map((r) => _database.students.map(r.data)).toList(growable: false);
      }
    } catch (_) {
      // Best-effort; fall back below.
    }

    // Fallback for legacy DBs where enrollments aren't used yet:
    // show class-based access from assignments.
    final assignments = await (_database.select(_database.classSubjectTeachers)
          ..where((t) => t.teacherId.equals(userId)))
        .get();

    if (assignments.isEmpty) return [];

    final classIds = assignments.map((a) => a.classId).toSet().toList();

    return await (_database.select(_database.students)..where((s) => s.classId.isIn(classIds))).get();
  }

  /// Get class-subject assignments for a teacher
  Future<List<ClassSubjectTeacher>> getTeacherAssignments(int userId) async {
    return await (_database.select(_database.classSubjectTeachers)
      ..where((t) => t.teacherId.equals(userId))).get();
  }

  /// Get class-subject access for assessments/exams.
  ///
  /// - Subject teachers: access is based on ClassSubjectTeachers rows.
  /// - Head/class teachers: access includes ALL offered subjects for their class.
  Future<List<TeacherClassSubjectAccess>> getAssessmentAccess(int userId) async {
    final access = <TeacherClassSubjectAccess>[];

    // Subject-teacher assignments
    final subjectAssignments = await getTeacherAssignments(userId);
    for (final a in subjectAssignments) {
      access.add(
        TeacherClassSubjectAccess(
          classId: a.classId,
          subjectId: a.subjectId,
          viaHeadTeacherRole: false,
        ),
      );
    }

    // Head/class teacher access: all subjects offered for the class
    final classRecord = await (_database.select(_database.schoolClasses)
          ..where((c) => c.headTeacherId.equals(userId))
          ..limit(1))
        .getSingleOrNull();
    if (classRecord != null) {
      final offered = await _database.getOfferedSubjectsForClass(classRecord.id);
      for (final s in offered) {
        access.add(
          TeacherClassSubjectAccess(
            classId: classRecord.id,
            subjectId: s.id,
            viaHeadTeacherRole: true,
          ),
        );
      }
    }

    // Deduplicate (classId, subjectId)
    final seen = <String>{};
    final deduped = <TeacherClassSubjectAccess>[];
    for (final a in access) {
      final key = '${a.classId}:${a.subjectId}';
      if (seen.add(key)) deduped.add(a);
    }
    return deduped;
  }

  Future<bool> isHeadOrClassTeacher(int userId) async {
    final rows = await (_database.select(_database.schoolClasses)
          ..where((c) => c.headTeacherId.equals(userId))
          ..limit(1))
        .get();
    return rows.isNotEmpty;
  }

  Future<int?> getHeadOrClassTeacherClassId(int userId) async {
    final classRecord = await (_database.select(_database.schoolClasses)
          ..where((c) => c.headTeacherId.equals(userId))
          ..limit(1))
        .getSingleOrNull();
    return classRecord?.id;
  }

  Future<bool> isSubjectTeacher(int userId) async {
    final rows = await (_database.select(_database.classSubjectTeachers)
          ..where((t) => t.teacherId.equals(userId))
          ..limit(1))
        .get();
    return rows.isNotEmpty;
  }
}
