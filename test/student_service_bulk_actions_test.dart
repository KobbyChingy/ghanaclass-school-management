import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/features/students/student_service.dart';

void main() {
  group('StudentService bulk actions', () {
    late AppDatabase db;
    late StudentService studentService;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      studentService = StudentService(db);
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> insertClass({
      String className = 'JHS 1',
      String classCode = 'JHS1',
      int academicYear = 2025,
    }) async {
      return db.into(db.schoolClasses).insert(
            SchoolClassesCompanion.insert(
              className: className,
              classCode: classCode,
              academicYear: academicYear,
              capacity: const drift.Value(40),
            ),
          );
    }

    Future<int> insertStudent({
      required String studentId,
      required String admissionNumber,
      int? classId,
      String firstName = 'Ama',
      String lastName = 'Mensah',
      String gender = 'female',
      String guardianName = 'Parent',
      String guardianPhone = '0550000000',
      String guardianRelationship = 'parent',
      String status = 'active',
      bool isActive = true,
    }) async {
      return db.into(db.students).insert(
            StudentsCompanion.insert(
              studentId: studentId,
              firstName: firstName,
              lastName: lastName,
              gender: gender,
              dateOfBirth: DateTime(2010, 1, 1),
              guardianName: guardianName,
              guardianPhone: guardianPhone,
              guardianRelationship: guardianRelationship,
              admissionDate: DateTime(2025, 1, 1),
              admissionNumber: admissionNumber,
              classId: drift.Value(classId),
              status: drift.Value(status),
              isActive: drift.Value(isActive),
            ),
          );
    }

    test('bulkDeactivateStudents marks students inactive', () async {
      final id1 = await insertStudent(studentId: 'STU-1', admissionNumber: 'ADM-1');
      final id2 = await insertStudent(studentId: 'STU-2', admissionNumber: 'ADM-2');

      final result = await studentService.bulkDeactivateStudents([id1, id2]);
      expect(result.requested, 2);
      expect(result.affected, 2);
      expect(result.errors, isEmpty);

      final s1 = await (db.select(db.students)..where((t) => t.id.equals(id1))).getSingle();
      final s2 = await (db.select(db.students)..where((t) => t.id.equals(id2))).getSingle();
      expect(s1.isActive, isFalse);
      expect(s2.isActive, isFalse);
      expect(s1.status, 'inactive');
      expect(s2.status, 'inactive');
    });

    test('bulkDeleteStudents deletes unreferenced students', () async {
      final id = await insertStudent(studentId: 'STU-3', admissionNumber: 'ADM-3');

      final result = await studentService.bulkDeleteStudents([id]);
      expect(result.requested, 1);
      expect(result.affected, 1);
      expect(result.skippedStudentTableIds, isEmpty);

      final remaining = await (db.select(db.students)..where((t) => t.id.equals(id))).getSingleOrNull();
      expect(remaining, isNull);
    });

    test('bulkDeleteStudents skips students referenced by attendance records', () async {
      final classId = await insertClass();
      final studentId = await insertStudent(studentId: 'STU-4', admissionNumber: 'ADM-4', classId: classId);

      final sessionId = await db.into(db.attendanceSessions).insert(
            AttendanceSessionsCompanion.insert(
              classId: classId,
              date: DateTime(2025, 1, 2),
              period: const drift.Value('Morning'),
            ),
          );

      await db.into(db.attendanceRecords).insert(
            AttendanceRecordsCompanion.insert(
              sessionId: sessionId,
              studentId: studentId,
              status: 'present',
            ),
          );

      final result = await studentService.bulkDeleteStudents([studentId]);
      expect(result.requested, 1);
      expect(result.affected, 0);
      expect(result.skippedStudentTableIds, [studentId]);
      expect(result.errors, isNotEmpty);

      final remaining = await (db.select(db.students)..where((t) => t.id.equals(studentId))).getSingleOrNull();
      expect(remaining, isNotNull);
    });
  });
}
