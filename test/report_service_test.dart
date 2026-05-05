import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/features/assessments/report_pdf_service.dart';
import 'package:ghanaclass_school_management/features/assessments/report_service.dart';

void main() {
  group('ReportService', () {
    late AppDatabase db;
    late ReportService service;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      service = ReportService(db);
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> seedSchool() async {
      await db.into(db.institutionalIdentity).insert(
            InstitutionalIdentityCompanion.insert(
              schoolName: 'Ghana Class Academy',
              headOfInstitution: 'Head Teacher',
              officialEmail: 'info@ghanaclass.test',
              masterPasswordHash: 'hash',
            ),
          );
    }

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

    Future<int> insertSubject({
      required String name,
      required String code,
      bool isCore = true,
    }) {
      return db.into(db.schoolSubjects).insert(
            SchoolSubjectsCompanion.insert(
              subjectName: name,
              subjectCode: code,
              isCore: drift.Value(isCore),
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
              gender: 'male',
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
      required String title,
      required String assessmentType,
      required double maxScore,
      required int teacherId,
    }) {
      return db.into(db.assessments).insert(
            AssessmentsCompanion.insert(
              title: title,
              assessmentType: assessmentType,
              classId: classId,
              subjectId: subjectId,
              teacherId: teacherId,
              maxScore: drift.Value(maxScore),
              term: const drift.Value(3),
              date: DateTime(2026, 7, 1),
            ),
          );
    }

    test('builds subject grades from assessment scores instead of stale term results', () async {
      await seedSchool();
      final classId = await insertClass();
      final mathId = await insertSubject(name: 'Mathematics', code: 'MATH');
      final scienceId = await insertSubject(name: 'Science', code: 'SCI');

      await db.into(db.classSubjectOfferings).insert(
            ClassSubjectOfferingsCompanion.insert(classId: classId, subjectId: mathId),
          );
      await db.into(db.classSubjectOfferings).insert(
            ClassSubjectOfferingsCompanion.insert(classId: classId, subjectId: scienceId),
          );

      final teacherUserId = await db.into(db.users).insert(
            UsersCompanion.insert(
              fullName: 'Kwame Teacher',
              email: 'teacher@ghanaclass.test',
              passwordHash: 'hash',
              role: 'teacher',
            ),
          );

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

      final mathTestId = await insertAssessment(
        classId: classId,
        subjectId: mathId,
        title: 'Math Test 1',
        assessmentType: 'test',
        maxScore: 20,
        teacherId: teacherUserId,
      );
      final mathExamId = await insertAssessment(
        classId: classId,
        subjectId: mathId,
        title: 'Math Exam',
        assessmentType: 'exam',
        maxScore: 80,
        teacherId: teacherUserId,
      );
      final scienceTestId = await insertAssessment(
        classId: classId,
        subjectId: scienceId,
        title: 'Science Test 1',
        assessmentType: 'test',
        maxScore: 20,
        teacherId: teacherUserId,
      );
      final scienceExamId = await insertAssessment(
        classId: classId,
        subjectId: scienceId,
        title: 'Science Exam',
        assessmentType: 'exam',
        maxScore: 80,
        teacherId: teacherUserId,
      );

      await db.into(db.studentGrades).insert(
            StudentGradesCompanion.insert(
              assessmentId: mathTestId,
              studentId: amaId,
              score: 18,
              remarks: const drift.Value('Strong effort'),
            ),
          );
      await db.into(db.studentGrades).insert(
            StudentGradesCompanion.insert(
              assessmentId: mathExamId,
              studentId: amaId,
              score: 60,
            ),
          );
      await db.into(db.studentGrades).insert(
            StudentGradesCompanion.insert(
              assessmentId: scienceTestId,
              studentId: amaId,
              score: 16,
            ),
          );
      await db.into(db.studentGrades).insert(
            StudentGradesCompanion.insert(
              assessmentId: scienceExamId,
              studentId: amaId,
              score: 56,
            ),
          );

      await db.into(db.studentGrades).insert(
            StudentGradesCompanion.insert(
              assessmentId: mathTestId,
              studentId: kojoId,
              score: 14,
            ),
          );
      await db.into(db.studentGrades).insert(
            StudentGradesCompanion.insert(
              assessmentId: mathExamId,
              studentId: kojoId,
              score: 48,
            ),
          );
      await db.into(db.studentGrades).insert(
            StudentGradesCompanion.insert(
              assessmentId: scienceTestId,
              studentId: kojoId,
              score: 15,
            ),
          );
      await db.into(db.studentGrades).insert(
            StudentGradesCompanion.insert(
              assessmentId: scienceExamId,
              studentId: kojoId,
              score: 50,
            ),
          );

      // Seed stale cached values to prove the report uses live assessment data instead.
      await db.into(db.termResults).insert(
            TermResultsCompanion.insert(
              studentId: amaId,
              classId: classId,
              subjectId: mathId,
              term: 3,
              totalCaScore: const drift.Value(5),
              examScore: const drift.Value(20),
              totalScore: const drift.Value(25),
              grade: const drift.Value('F9'),
            ),
          );

      final report = await service.getStudentReportData(amaId, 3, 2026);

      expect(report.results, hasLength(2));

      final math = report.results.firstWhere((result) => result.subjectName == 'Mathematics');
      final science = report.results.firstWhere((result) => result.subjectName == 'Science');

      expect(math.caScore, closeTo(27.0, 0.001));
      expect(math.examScore, closeTo(52.5, 0.001));
      expect(math.totalScore, closeTo(79.5, 0.001));
      expect(math.grade, 'B2');
      expect(math.remarks, 'Strong effort');

      expect(science.caScore, closeTo(24.0, 0.001));
      expect(science.examScore, closeTo(49.0, 0.001));
      expect(science.totalScore, closeTo(73.0, 0.001));
      expect(science.grade, 'B2');

      expect(report.averageScore, closeTo(76.25, 0.001));
      expect(report.position, 1);
      expect(report.totalStudents, 2);
    });

    test('builds terminal report PDF bytes without network font loading', () async {
      await seedSchool();
      final classId = await insertClass();
      final mathId = await insertSubject(name: 'Mathematics', code: 'MATH');

      await db.into(db.classSubjectOfferings).insert(
            ClassSubjectOfferingsCompanion.insert(classId: classId, subjectId: mathId),
          );

      final teacherUserId = await db.into(db.users).insert(
            UsersCompanion.insert(
              fullName: 'Kwame Teacher',
              email: 'teacher-pdf@ghanaclass.test',
              passwordHash: 'hash',
              role: 'teacher',
            ),
          );

      final studentId = await insertStudent(
        studentId: 'STU-PDF-001',
        admissionNumber: 'ADM-PDF-001',
        classId: classId,
        firstName: 'Efua',
      );

      final assessmentId = await insertAssessment(
        classId: classId,
        subjectId: mathId,
        title: 'Math Exam',
        assessmentType: 'exam',
        maxScore: 100,
        teacherId: teacherUserId,
      );

      await db.into(db.studentGrades).insert(
            StudentGradesCompanion.insert(
              assessmentId: assessmentId,
              studentId: studentId,
              score: 84,
              remarks: const drift.Value('Consistent work'),
            ),
          );

      final report = await service.getStudentReportData(studentId, 3, 2026);
      final pdfService = ReportPdfService(
        regularFontLoader: () async => pw.Font.helvetica(),
        boldFontLoader: () async => pw.Font.helveticaBold(),
      );

      final bytes = await pdfService.buildTerminalReportPdf(data: report);

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });
  });
}