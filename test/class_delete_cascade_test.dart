import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/features/academic/academic_service.dart';

void main() {
  group('AcademicService cascading class deletion', () {
    late AppDatabase db;
    late AcademicService academicService;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      academicService = AcademicService(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('deleting a class still succeeds when optional class-linked tables are missing', () async {
      final teacherId = await db.into(db.users).insert(
        UsersCompanion.insert(
          fullName: 'Teacher Jane',
          email: 'jane@test.local',
          passwordHash: 'hash',
          role: 'teacher',
          isActive: const drift.Value(true),
        ),
      );

      final classId = await db.into(db.schoolClasses).insert(
        SchoolClassesCompanion.insert(
          className: 'Class 1A',
          classCode: 'C1A',
          academicYear: 2026,
        ),
      );

      await db.customStatement('DROP TABLE IF EXISTS science_lab_usage_sessions');
      await db.customStatement('DROP TABLE IF EXISTS lesson_notes');
      await db.customStatement('DROP TABLE IF EXISTS ict_lab_usage_sessions');
      await db.customStatement('DROP TABLE IF EXISTS fee_structures');
      await db.customStatement('DROP TABLE IF EXISTS classes');

      final deletedCount = await academicService.deleteClass(classId);
      expect(deletedCount, 1);

      final classResult = await (db.select(db.schoolClasses)..where((t) => t.id.equals(classId))).getSingleOrNull();
      expect(classResult, isNull);
    });

    test('deleting a class removes all dependencies and nullifies student classId', () async {
      // 1) Setup basic data
      final teacherId = await db.into(db.users).insert(
            UsersCompanion.insert(
              fullName: 'Teacher Jane',
              email: 'jane@test.local',
              passwordHash: 'hash',
              role: 'teacher',
              isActive: const drift.Value(true),
            ),
          );

      final classId = await db.into(db.schoolClasses).insert(
            SchoolClassesCompanion.insert(
              className: 'Class 1A',
              classCode: 'C1A',
              academicYear: 2026,
            ),
          );

      final studentId = await db.into(db.students).insert(
            StudentsCompanion.insert(
              studentId: 'STU001',
              firstName: 'John',
              lastName: 'Doe',
              gender: 'male',
              dateOfBirth: DateTime(2015, 1, 1),
              guardianName: 'Guardian Name',
              guardianPhone: '0550000001',
              guardianRelationship: 'parent',
              admissionDate: DateTime.now(),
              admissionNumber: 'ADM001',
              classId: drift.Value(classId),
            ),
          );

      final subjectId = await db.into(db.schoolSubjects).insert(
            SchoolSubjectsCompanion.insert(
              subjectName: 'Mathematics',
              subjectCode: 'MATH',
            ),
          );

      // 2) Populate non-nullable referencing tables
      final offeringId = await db.into(db.classSubjectOfferings).insert(
            ClassSubjectOfferingsCompanion.insert(
              classId: classId,
              subjectId: subjectId,
            ),
          );

      final teacherAssignmentId = await db.into(db.classSubjectTeachers).insert(
            ClassSubjectTeachersCompanion.insert(
              classId: classId,
              subjectId: subjectId,
              teacherId: teacherId,
            ),
          );

      final enrollmentId = await db.into(db.studentSubjectEnrollments).insert(
            StudentSubjectEnrollmentsCompanion.insert(
              studentId: studentId,
              classId: classId,
              subjectId: subjectId,
            ),
          );

      // 3) Populate multi-level dependent tables (Attendance sessions & records)
      final attendanceSessionId = await db.into(db.attendanceSessions).insert(
            AttendanceSessionsCompanion.insert(
              classId: classId,
              date: DateTime.now(),
            ),
          );

      final attendanceRecordId = await db.into(db.attendanceRecords).insert(
            AttendanceRecordsCompanion.insert(
              sessionId: attendanceSessionId,
              studentId: studentId,
              status: 'present',
            ),
          );

      // 4) Populate multi-level dependent tables (Assessments & grades)
      final assessmentId = await db.into(db.assessments).insert(
            AssessmentsCompanion.insert(
              title: 'First Quiz',
              assessmentType: 'test',
              classId: classId,
              subjectId: subjectId,
              teacherId: teacherId,
              date: DateTime.now(),
            ),
          );

      final gradeId = await db.into(db.studentGrades).insert(
            StudentGradesCompanion.insert(
              assessmentId: assessmentId,
              studentId: studentId,
              score: 95.0,
            ),
          );

      // 5) Perform the cascading deletion via service
      final deletedCount = await academicService.deleteClass(classId);
      expect(deletedCount, 1);

      // 6) Verify class is gone
      final classResult = await (db.select(db.schoolClasses)..where((t) => t.id.equals(classId))).getSingleOrNull();
      expect(classResult, isNull);

      // 7) Verify student classId is nullified
      final studentResult = await (db.select(db.students)..where((t) => t.id.equals(studentId))).getSingle();
      expect(studentResult.classId, isNull);

      // 8) Verify non-nullable direct references are deleted
      final offeringResult = await (db.select(db.classSubjectOfferings)..where((t) => t.id.equals(offeringId))).getSingleOrNull();
      expect(offeringResult, isNull);

      final teacherAssignmentResult = await (db.select(db.classSubjectTeachers)..where((t) => t.id.equals(teacherAssignmentId))).getSingleOrNull();
      expect(teacherAssignmentResult, isNull);

      final enrollmentResult = await (db.select(db.studentSubjectEnrollments)..where((t) => t.id.equals(enrollmentId))).getSingleOrNull();
      expect(enrollmentResult, isNull);

      // 9) Verify multi-level attendance is deleted
      final attendanceSessionResult = await (db.select(db.attendanceSessions)..where((t) => t.id.equals(attendanceSessionId))).getSingleOrNull();
      expect(attendanceSessionResult, isNull);

      final attendanceRecordResult = await (db.select(db.attendanceRecords)..where((t) => t.id.equals(attendanceRecordId))).getSingleOrNull();
      expect(attendanceRecordResult, isNull);

      // 10) Verify multi-level assessment is deleted
      final assessmentResult = await (db.select(db.assessments)..where((t) => t.id.equals(assessmentId))).getSingleOrNull();
      expect(assessmentResult, isNull);

      final gradeResult = await (db.select(db.studentGrades)..where((t) => t.id.equals(gradeId))).getSingleOrNull();
      expect(gradeResult, isNull);
    });
  });
}
