import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:drift/drift.dart';

class ReportData {
  final Student student;
  final SchoolClassesData schoolClass;
  final InstitutionalIdentityData schoolInfo;
  final List<SubjectResult> results;
  final int term;
  final int academicYear;
  
  // New Metrics
  final int position;
  final int totalStudents;
  final double averageScore;
  final int totalAttendanceDays;
  final int pupilAttendance;
  final String attendanceRate;
  
  // Remarks
  final String? teacherRemarks;
  final String? headteacherRemarks;
  final String? conduct;

  ReportData({
    required this.student,
    required this.schoolClass,
    required this.schoolInfo,
    required this.results,
    required this.term,
    required this.academicYear,
    required this.position,
    required this.totalStudents,
    required this.averageScore,
    required this.totalAttendanceDays,
    required this.pupilAttendance,
    required this.attendanceRate,
    this.teacherRemarks,
    this.headteacherRemarks,
    this.conduct,
  });
}

class SubjectResult {
  final String subjectName;
  final double caScore;
  final double examScore;
  final double totalScore;
  final String grade;
  final String? remarks;

  SubjectResult({
    required this.subjectName,
    required this.caScore,
    required this.examScore,
    required this.totalScore,
    required this.grade,
    this.remarks,
  });
}

class _ComputedSubjectResult {
  final SubjectResult result;
  final bool includeInAverage;

  const _ComputedSubjectResult({
    required this.result,
    required this.includeInAverage,
  });
}

class ReportService {
  final AppDatabase _database;

  ReportService(this._database);

  Future<ReportData> getStudentReportData(int studentId, int term, int academicYear) async {
    // 1. Fetch Student & Class & School Info
    final student = await (_database.select(_database.students)..where((s) => s.id.equals(studentId))).getSingleOrNull();
    if (student == null) {
      throw StateError('Student record not found.');
    }
    final classId = student.classId;
    if (classId == null) {
      throw StateError('Student is not assigned to a class.');
    }
    final schoolClass = await (_database.select(_database.schoolClasses)..where((c) => c.id.equals(classId))).getSingleOrNull() ??
        _fallbackSchoolClass(classId, academicYear);
    final schoolInfo = await _database.getInstitutionalIdentity() ?? _fallbackSchoolInfo();

    // 2. Fetch all student results in the class for ranking
    final allInClass = await (_database.select(_database.students)..where((s) => s.classId.equals(classId))).get();

    final subjects = await _getSubjectsForReport(studentId, classId, term);
    final subjectResults = await _buildSubjectResults(
      studentId: studentId,
      classId: classId,
      term: term,
      subjects: subjects,
    );

    final List<Map<String, dynamic>> rankings = [];
    for (var s in allInClass) {
      final rankingSubjects = s.id == studentId ? subjects : await _getSubjectsForReport(s.id, classId, term);
      final rankingResults = s.id == studentId
          ? subjectResults
          : await _buildSubjectResults(
              studentId: s.id,
              classId: classId,
              term: term,
              subjects: rankingSubjects,
            );

      final includedResults = rankingResults.where((result) => result.includeInAverage).toList(growable: false);
      final total = includedResults.fold<double>(0.0, (sum, result) => sum + result.result.totalScore);
      final avg = includedResults.isEmpty ? 0.0 : total / includedResults.length;
      rankings.add({'id': s.id, 'avg': avg});
    }

    // Sort by average descending
    rankings.sort((a, b) => (b['avg'] as double).compareTo(a['avg'] as double));
    
    final studentRankIndex = rankings.indexWhere((r) => r['id'] == studentId);
    final position = studentRankIndex + 1;
    final avgScore = studentRankIndex >= 0 ? rankings[studentRankIndex]['avg'] as double : 0.0;

    // 3. Use live per-subject assessment results for this student's report rows.
    final reportResults = subjectResults.map((result) => result.result).toList(growable: false);

    // 4. Attendance Calculation (generated from Attendance page data)
    final yearStart = DateTime(academicYear, 1, 1);
    final nextYearStart = DateTime(academicYear + 1, 1, 1);
    final sessions = await (_database.select(_database.attendanceSessions)
          ..where((s) => s.classId.equals(classId))
          ..where((s) => s.date.isBiggerOrEqualValue(yearStart))
          ..where((s) => s.date.isSmallerThanValue(nextYearStart)))
        .get();
    final sessionIds = sessions.map((s) => s.id).toList(growable: false);

    var totalAttendanceDays = sessionIds.length;
    var pupilAttendance = 0;
    var attendanceRate = 'N/A';

    if (sessionIds.isNotEmpty) {
      final records = await (_database.select(_database.attendanceRecords)
            ..where((r) => r.studentId.equals(studentId) & r.sessionId.isIn(sessionIds)))
          .get();

      // Treat anything not marked absent as attended for day-level attendance.
      pupilAttendance = records.where((r) => r.status != 'absent').length;
      attendanceRate = '${((pupilAttendance / totalAttendanceDays) * 100).toStringAsFixed(0)}%';
    } else {
      totalAttendanceDays = 0;
      pupilAttendance = 0;
    }

    // 5. Fetch Summary/Remarks
    final summary = await (_database.select(_database.reportSummaries)
      ..where((s) => s.studentId.equals(studentId) & s.term.equals(term) & s.academicYear.equals(academicYear)))
      .getSingleOrNull();

    return ReportData(
      student: student,
      schoolClass: schoolClass,
      schoolInfo: schoolInfo,
      results: reportResults,
      term: term,
      academicYear: academicYear,
      position: position,
      totalStudents: allInClass.length,
      averageScore: avgScore,
      totalAttendanceDays: totalAttendanceDays,
      pupilAttendance: pupilAttendance,
      attendanceRate: attendanceRate,
      teacherRemarks: summary?.teacherRemarks,
      headteacherRemarks: summary?.headteacherRemarks,
      conduct: summary?.conduct,
    );
  }

  Future<List<SchoolSubject>> _getSubjectsForReport(int studentId, int classId, int term) async {
    final activeSubjects = await _database.getActiveSubjectsForStudent(studentId);
    if (activeSubjects.isNotEmpty) {
      activeSubjects.sort((a, b) => a.subjectName.compareTo(b.subjectName));
      return activeSubjects;
    }

    final existingResults = await (_database.select(_database.termResults)
          ..where((t) => t.studentId.equals(studentId) & t.classId.equals(classId) & t.term.equals(term)))
        .get();
    if (existingResults.isEmpty) {
      return const <SchoolSubject>[];
    }

    final subjectIds = existingResults.map((result) => result.subjectId).toSet().toList(growable: false);
    final subjects = await (_database.select(_database.schoolSubjects)..where((s) => s.id.isIn(subjectIds))).get();
    subjects.sort((a, b) => a.subjectName.compareTo(b.subjectName));
    return subjects;
  }

  Future<List<_ComputedSubjectResult>> _buildSubjectResults({
    required int studentId,
    required int classId,
    required int term,
    required List<SchoolSubject> subjects,
  }) async {
    final results = <_ComputedSubjectResult>[];

    for (final subject in subjects) {
      final computed = await _computeSubjectResult(
        studentId: studentId,
        classId: classId,
        subject: subject,
        term: term,
      );
      if (computed != null) {
        results.add(computed);
      }
    }

    return results;
  }

  Future<_ComputedSubjectResult?> _computeSubjectResult({
    required int studentId,
    required int classId,
    required SchoolSubject subject,
    required int term,
  }) async {
    final assessments = await (_database.select(_database.assessments)
          ..where((assessment) => assessment.classId.equals(classId))
          ..where((assessment) => assessment.subjectId.equals(subject.id))
          ..where((assessment) => assessment.term.equals(term)))
        .get();

    if (assessments.isEmpty) {
      return null;
    }

    final scale = await (_database.select(_database.gradingScales)
          ..where((grading) => grading.classId.equals(classId))
          ..where((grading) => grading.subjectId.equals(subject.id))
          ..where((grading) => grading.term.equals(term)))
        .getSingleOrNull();
    final caWeight = scale?.caWeight ?? 30.0;
    final examWeight = scale?.examWeight ?? 70.0;
    final assessmentIds = assessments.map((assessment) => assessment.id).toList(growable: false);
    final grades = await (_database.select(_database.studentGrades)
          ..where((grade) => grade.studentId.equals(studentId) & grade.assessmentId.isIn(assessmentIds)))
        .get();
    final gradesByAssessmentId = {for (final grade in grades) grade.assessmentId: grade};

    double effectiveAssessmentWeight(Assessment assessment) {
      final weight = assessment.weightage;
      if (weight.isNaN || weight.isInfinite || weight <= 0) return assessment.maxScore;
      if (weight == 1.0 && assessment.maxScore != 1.0) return assessment.maxScore;
      return weight;
    }

    ({double score, double possible, bool hasRecordedScore}) foldAssessments(List<Assessment> source) {
      var totalScaled = 0.0;
      var totalPossibleScaled = 0.0;
      var hasRecordedScore = false;

      for (final assessment in source) {
        final grade = gradesByAssessmentId[assessment.id];
        if (grade == null) {
          continue;
        }

        final rawMax = assessment.maxScore;
        final scaledMax = effectiveAssessmentWeight(assessment);
        if (rawMax > 0) {
          totalScaled += (grade.score / rawMax) * scaledMax;
        }
        totalPossibleScaled += scaledMax;
        hasRecordedScore = true;
      }

      return (score: totalScaled, possible: totalPossibleScaled, hasRecordedScore: hasRecordedScore);
    }

    final caAssessments = assessments.where((assessment) => assessment.assessmentType != 'exam').toList(growable: false);
    final examAssessments = assessments.where((assessment) => assessment.assessmentType == 'exam').toList(growable: false);
    final caTotals = foldAssessments(caAssessments);
    final examTotals = foldAssessments(examAssessments);
    final scaledCa = caTotals.possible > 0 ? (caTotals.score / caTotals.possible) * caWeight : 0.0;
    final scaledExam = examTotals.possible > 0 ? (examTotals.score / examTotals.possible) * examWeight : 0.0;
    final totalScore = scaledCa + scaledExam;
    final hasRecordedScore = caTotals.hasRecordedScore || examTotals.hasRecordedScore;

    String? remarks;
    if (!hasRecordedScore) {
      remarks = 'No scores recorded';
    } else {
      final gradeRemarks = grades.where((grade) => (grade.remarks ?? '').trim().isNotEmpty).toList(growable: false);
      if (gradeRemarks.isNotEmpty) {
        gradeRemarks.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        remarks = gradeRemarks.first.remarks;
      }
    }

    return _ComputedSubjectResult(
      result: SubjectResult(
        subjectName: subject.subjectName,
        caScore: scaledCa,
        examScore: scaledExam,
        totalScore: totalScore,
        grade: hasRecordedScore ? _calculateGrade(totalScore) : 'N/A',
        remarks: remarks,
      ),
      includeInAverage: hasRecordedScore,
    );
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

  Future<void> upsertReportSummary(ReportSummariesCompanion entry) async {
    await _database.into(_database.reportSummaries).insertOnConflictUpdate(entry);
  }

  SchoolClassesData _fallbackSchoolClass(int classId, int academicYear) {
    return SchoolClassesData(
      id: classId,
      className: 'Unassigned Class',
      classCode: 'CLASS-$classId',
      academicYear: academicYear,
      capacity: 0,
      isActive: true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      isDirty: false,
    );
  }

  InstitutionalIdentityData _fallbackSchoolInfo() {
    final now = DateTime.now();
    return InstitutionalIdentityData(
      id: 0,
      schoolName: 'School Management System',
      headOfInstitution: 'Head Teacher',
      officialEmail: 'noreply@school.local',
      masterPasswordHash: '',
      createdAt: now,
      updatedAt: now,
      isDirty: false,
    );
  }
}
