import 'package:ghanaclass_school_management/core/database/app_database.dart';

class ClassAssignmentsSummary {
  final int assignmentsCount;
  final int subjectsCount;
  final int teachersCount;

  const ClassAssignmentsSummary({
    required this.assignmentsCount,
    required this.subjectsCount,
    required this.teachersCount,
  });
}

class AcademicService {
  final AppDatabase _database;

  AcademicService(this._database);

  // Class Methods
  Future<List<SchoolClassesData>> getAllClasses() async {
    return await _database.select(_database.schoolClasses).get();
  }

  Future<int> createClass(SchoolClassesCompanion entry) async {
    final id = await _database.into(_database.schoolClasses).insert(entry);

    // Best-effort: seed default offerings for this class.
    try {
      await _database.ensureDefaultOfferingsForClass(
        id,
        entry.className.value,
        entry.classCode.value,
      );
    } catch (_) {
      // ignore
    }

    return id;
  }

  Future<bool> updateClass(SchoolClassesCompanion entry) async {
    return await (_database.update(_database.schoolClasses)
          ..where((t) => t.id.equals(entry.id.value)))
        .write(entry) > 0;
  }

  Future<int> deleteClass(int id) async {
    return await (_database.delete(_database.schoolClasses)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  // Subject Methods
  Future<List<SchoolSubject>> getAllSubjects() async {
    return await _database.select(_database.schoolSubjects).get();
  }

  Future<List<SchoolSubject>> getSubjectsForClass(int classId) async {
    return await _database.getOfferedSubjectsForClass(classId);
  }

  Future<int> createSubject(SchoolSubjectsCompanion entry) async {
    return await _database.into(_database.schoolSubjects).insert(entry);
  }

  Future<bool> updateSubject(SchoolSubjectsCompanion entry) async {
    return await (_database.update(_database.schoolSubjects)
          ..where((t) => t.id.equals(entry.id.value)))
        .write(entry) > 0;
  }

  Future<int> deleteSubject(int id) async {
    return await _database.deleteSubjectCascade(id);
  }

  // Class-Subject-Teacher Mappings
  Future<List<ClassSubjectTeacher>> getClassMappings(int classId) async {
    return await (_database.select(_database.classSubjectTeachers)
          ..where((t) => t.classId.equals(classId)))
        .get();
  }

  Future<List<ClassSubjectTeacher>> getTeacherMappings(int teacherId) async {
    return await (_database.select(_database.classSubjectTeachers)
          ..where((t) => t.teacherId.equals(teacherId)))
        .get();
  }

  Future<Map<int, ClassAssignmentsSummary>> getClassAssignmentSummaries() async {
    // Note: Drift table/column names are snake_case by default.
    // We query in one go to avoid N queries in the UI.
    final rows = await _database.customSelect(
      '''
      SELECT
        class_id AS classId,
        COUNT(*) AS assignmentsCount,
        COUNT(DISTINCT subject_id) AS subjectsCount,
        COUNT(DISTINCT teacher_id) AS teachersCount
      FROM class_subject_teachers
      GROUP BY class_id
      ''',
      readsFrom: {_database.classSubjectTeachers},
    ).get();

    final map = <int, ClassAssignmentsSummary>{};
    for (final row in rows) {
      final classId = row.read<int>('classId');
      final assignmentsCount = row.read<int>('assignmentsCount');
      final subjectsCount = row.read<int>('subjectsCount');
      final teachersCount = row.read<int>('teachersCount');
      map[classId] = ClassAssignmentsSummary(
        assignmentsCount: assignmentsCount,
        subjectsCount: subjectsCount,
        teachersCount: teachersCount,
      );
    }

    return map;
  }

  Future<int> assignTeacher(ClassSubjectTeachersCompanion entry) async {
    return await _database.assignTeacherToClassSubject(entry);
  }

  Future<int> removeAssignment(int id) async {
    return await (_database.delete(_database.classSubjectTeachers)
          ..where((t) => t.id.equals(id)))
        .go();
  }
}
