import 'package:drift/drift.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';

class AssessmentService {
  final AppDatabase _database;

  AssessmentService(this._database);

  // Assessment Configuration (CA/Exam)
  Future<List<Assessment>> getAssessments(int classId, int subjectId, int term) async {
    return await (_database.select(_database.assessments)
          ..where((t) => t.classId.equals(classId))
          ..where((t) => t.subjectId.equals(subjectId))
          ..where((t) => t.term.equals(term)))
        .get();
  }

  Future<int> createAssessment(AssessmentsCompanion entry) async {
    return await _database.into(_database.assessments).insert(entry);
  }

  // Grading Scales
  Future<GradingScale?> getGradingScale(int classId, int subjectId, int term) async {
    return await (_database.select(_database.gradingScales)
          ..where((t) => t.classId.equals(classId))
          ..where((t) => t.subjectId.equals(subjectId))
          ..where((t) => t.term.equals(term)))
        .getSingleOrNull();
  }

  Future<int> upsertGradingScale(GradingScalesCompanion entry) async {
    return await _database.into(_database.gradingScales).insertOnConflictUpdate(entry);
  }

  // Grades entry
  Future<void> saveGrades(List<StudentGradesCompanion> grades) async {
    await _database.transaction(() async {
      for (final grade in grades) {
        await _database.into(_database.studentGrades).insertOnConflictUpdate(grade);
      }
    });
  }

  Future<List<StudentGrade>> getGradesForAssessment(int assessmentId) async {
    return await (_database.select(_database.studentGrades)
          ..where((t) => t.assessmentId.equals(assessmentId)))
        .get();
  }

  // Calculation logic
  Future<void> calculateTermResults(int classId, int subjectId, int term) async {
    final scale = await getGradingScale(classId, subjectId, term);
    final caWeight = scale?.caWeight ?? 30.0;
    final examWeight = scale?.examWeight ?? 70.0;

    final assessments = await getAssessments(classId, subjectId, term);
    final students = await (_database.select(_database.students)
          ..where((t) => t.classId.equals(classId) & t.isActive.equals(true)))
        .get();

    if (students.isEmpty) {
      return;
    }

    if (assessments.isEmpty) {
      await (_database.delete(_database.termResults)
            ..where((t) => t.classId.equals(classId) & t.subjectId.equals(subjectId) & t.term.equals(term)))
          .go();
      return;
    }

    final caAssessments = assessments.where((a) => a.assessmentType != 'exam').toList();
    final examAssessments = assessments.where((a) => a.assessmentType == 'exam').toList();

    final assessmentIds = assessments.map((assessment) => assessment.id).toList(growable: false);
    final studentIds = students.map((student) => student.id).toList(growable: false);
    final grades = await (_database.select(_database.studentGrades)
          ..where((t) => t.assessmentId.isIn(assessmentIds) & t.studentId.isIn(studentIds)))
        .get();
    final gradesByAssessmentAndStudent = <int, Map<int, StudentGrade>>{};
    for (final grade in grades) {
      gradesByAssessmentAndStudent.putIfAbsent(grade.assessmentId, () => <int, StudentGrade>{})[grade.studentId] = grade;
    }

    final resultsToUpsert = <TermResultsCompanion>[];
    final studentsWithoutScores = <int>[];

    for (final student in students) {
      double totalCaScaled = 0;
      double totalCaPossibleScaled = 0;
      var hasRecordedScore = false;

      for (final assessment in caAssessments) {
        final grade = gradesByAssessmentAndStudent[assessment.id]?[student.id];
        if (grade != null) {
          final raw = grade.score;
          final rawMax = assessment.maxScore;
          final scaledMax = _effectiveAssessmentWeight(assessment);

          if (rawMax > 0) {
            totalCaScaled += (raw / rawMax) * scaledMax;
          }
          totalCaPossibleScaled += scaledMax;
          hasRecordedScore = true;
        }
      }

      final scaledCa = totalCaPossibleScaled > 0 ? (totalCaScaled / totalCaPossibleScaled) * caWeight : 0.0;

      double totalExamScaled = 0;
      double totalExamPossibleScaled = 0;

      for (final assessment in examAssessments) {
        final grade = gradesByAssessmentAndStudent[assessment.id]?[student.id];
        if (grade != null) {
          final raw = grade.score;
          final rawMax = assessment.maxScore;
          final scaledMax = _effectiveAssessmentWeight(assessment);

          if (rawMax > 0) {
            totalExamScaled += (raw / rawMax) * scaledMax;
          }
          totalExamPossibleScaled += scaledMax;
          hasRecordedScore = true;
        }
      }

      if (!hasRecordedScore) {
        studentsWithoutScores.add(student.id);
        continue;
      }

      final scaledExam = totalExamPossibleScaled > 0 ? (totalExamScaled / totalExamPossibleScaled) * examWeight : 0.0;
      final totalScore = scaledCa + scaledExam;

      resultsToUpsert.add(
        TermResultsCompanion.insert(
          studentId: student.id,
          classId: classId,
          subjectId: subjectId,
          term: term,
          totalCaScore: Value(scaledCa),
          examScore: Value(scaledExam),
          totalScore: Value(totalScore),
          grade: Value(_calculateGrade(totalScore)),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }

    await _database.transaction(() async {
      if (studentsWithoutScores.isNotEmpty) {
        await (_database.delete(_database.termResults)
              ..where((t) =>
                  t.classId.equals(classId) &
                  t.subjectId.equals(subjectId) &
                  t.term.equals(term) &
                  t.studentId.isIn(studentsWithoutScores)))
            .go();
      }

      for (final result in resultsToUpsert) {
        await _database.into(_database.termResults).insertOnConflictUpdate(result);
      }
    });
  }

  double _effectiveAssessmentWeight(Assessment assessment) {
    // Backwards-compatible defaulting:
    // - Historically, `weightage` existed but wasn't used; its DB default is 1.0.
    // - Treat `weightage == 1.0` (and maxScore != 1.0) as "unset".
    final weight = assessment.weightage;
    if (weight.isNaN || weight.isInfinite || weight <= 0) return assessment.maxScore;
    if (weight == 1.0 && assessment.maxScore != 1.0) return assessment.maxScore;
    return weight;
  }

  String _calculateGrade(double score) {
    if (score >= 80) return 'A1';
    if (score >= 70) return 'B2';
    if (score >= 65) return 'B3';
    if (score >= 60) return 'C4';
    if (score >= 55) return 'C5';
    if (score >= 50) return 'C6';
    if (score >= 45) return 'D7';
    if (score >= 40) return 'E8';
    return 'F9';
  }
}
