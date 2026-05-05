import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/features/assessments/assessment_service.dart';

void main() {
  group('AssessmentService.calculateTermResults', () {
    late AppDatabase db;
    late AssessmentService service;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      service = AssessmentService(db);
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> insertClass() {
      return db.into(db.schoolClasses).insert(
            SchoolClassesCompanion.insert(
              className: 'JHS 1A',
              classCode: 'JHS1A',
              academicYear: 2026,
              capacity: const drift.Value(40),
            ),
          );
    }

    Future<int> insertSubject() {
      return db.into(db.schoolSubjects).insert(
            SchoolSubjectsCompanion.insert(
              subjectName: 'Mathematics',
              subjectCode: 'MATH',
              isCore: const drift.Value(true),
            ),
          );
    }

    Future<int> insertTeacher() {
      return db.into(db.users).insert(
            UsersCompanion.insert(
              fullName: 'Kwame Teacher',
              email: 'teacher@ghanaclass.test',
              passwordHash: 'hash',
              role: 'teacher',
            ),
          );
    }

    Future<int> insertStudent({
      required String studentId,
      required String admissionNumber,
      required int classId,
      required String firstName,
    }) {
      return db.into(db.students).insert(
            StudentsCompanion.insert(
              studentId: studentId,
              firstName: firstName,
              lastName: 'Mensah',
              gender: 'female',
              dateOfBirth: DateTime(2012, 1, 1),
              guardianName: 'Parent',
              guardianPhone: '0550000000',
              guardianRelationship: 'parent',
              admissionDate: DateTime(2026, 1, 10),
              admissionNumber: admissionNumber,
              classId: drift.Value(classId),
            ),
          );
    }

    Future<int> insertAssessment({
      required int classId,
      required int subjectId,
      required int teacherId,
      required String title,
      required String type,
      required double maxScore,
    }) {
      return db.into(db.assessments).insert(
            AssessmentsCompanion.insert(
              title: title,
              assessmentType: type,
              classId: classId,
              subjectId: subjectId,
              teacherId: teacherId,
              maxScore: drift.Value(maxScore),
              term: const drift.Value(3),
              date: DateTime(2026, 7, 1),
            ),
          );
    }

    test('calculates scores in bulk and removes stale rows for students without grades', () async {
      final classId = await insertClass();
      final subjectId = await insertSubject();
      final teacherId = await insertTeacher();
      final amaId = await insertStudent(
        studentId: 'STU-001',
        admissionNumber: 'ADM-001',
        classId: classId,
        firstName: 'Ama',
      );
      final kojoId = await insertStudent(
        studentId: 'STU-002',
        admissionNumber: 'ADM-002',
        classId: classId,
        firstName: 'Kojo',
      );

      final testId = await insertAssessment(
        classId: classId,
        subjectId: subjectId,
        teacherId: teacherId,
        title: 'Class Test',
        type: 'test',
        maxScore: 20,
      );
      final examId = await insertAssessment(
        classId: classId,
        subjectId: subjectId,
        teacherId: teacherId,
        title: 'Main Exam',
        type: 'exam',
        maxScore: 80,
      );

      await db.into(db.studentGrades).insert(
            StudentGradesCompanion.insert(
              assessmentId: testId,
              studentId: amaId,
              score: 18,
            ),
          );
      await db.into(db.studentGrades).insert(
            StudentGradesCompanion.insert(
              assessmentId: examId,
              studentId: amaId,
              score: 60,
            ),
          );

      await db.into(db.termResults).insert(
            TermResultsCompanion.insert(
              studentId: kojoId,
              classId: classId,
              subjectId: subjectId,
              term: 3,
              totalCaScore: const drift.Value(12),
              examScore: const drift.Value(20),
              totalScore: const drift.Value(32),
              grade: const drift.Value('F9'),
            ),
          );

      await service.calculateTermResults(classId, subjectId, 3);

      final termResults = await (db.select(db.termResults)
            ..where((t) => t.classId.equals(classId) & t.subjectId.equals(subjectId) & t.term.equals(3)))
          .get();

      expect(termResults, hasLength(1));

      final amaResult = termResults.single;
      expect(amaResult.studentId, amaId);
      expect(amaResult.totalCaScore, closeTo(27.0, 0.001));
      expect(amaResult.examScore, closeTo(52.5, 0.001));
      expect(amaResult.totalScore, closeTo(79.5, 0.001));
      expect(amaResult.grade, 'B2');
    });
  });
}