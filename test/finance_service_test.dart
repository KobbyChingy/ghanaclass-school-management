import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/features/finance/finance_service.dart';

void main() {
  group('FinanceService.getStudentsFeesLedger', () {
    late AppDatabase db;
    late FinanceService service;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      service = FinanceService(db);
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> insertClass({
      required String name,
      required String code,
    }) {
      return db.into(db.schoolClasses).insert(
            SchoolClassesCompanion.insert(
              className: name,
              classCode: code,
              academicYear: 2026,
              capacity: const drift.Value(40),
            ),
          );
    }

    Future<int> insertStudent({
      required int classId,
      required String studentCode,
      required String admissionNumber,
      required String firstName,
    }) {
      return db.into(db.students).insert(
            StudentsCompanion.insert(
              studentId: studentCode,
              firstName: firstName,
              lastName: 'Mensah',
              gender: 'male',
              dateOfBirth: DateTime(2012, 1, 1),
              guardianName: 'Guardian $firstName',
              guardianPhone: '0550000000',
              guardianRelationship: 'parent',
              admissionDate: DateTime(2026, 1, 10),
              admissionNumber: admissionNumber,
              classId: drift.Value(classId),
            ),
          );
    }

    test('builds ledger rows for global and class fees without including fully paid balances', () async {
      final classA = await insertClass(name: 'JHS 1A', code: 'JHS1A');
      final classB = await insertClass(name: 'JHS 1B', code: 'JHS1B');

      final globalFeeId = await db.into(db.feeStructures).insert(
            FeeStructuresCompanion.insert(
              feeName: 'PTA Levy',
              amount: 100,
              category: 'PTA',
              academicYear: 2026,
            ),
          );

      final classFeeId = await db.into(db.feeStructures).insert(
            FeeStructuresCompanion.insert(
              feeName: 'Class Contribution',
              amount: 50,
              category: 'Class',
              academicYear: 2026,
              classId: drift.Value(classA),
            ),
          );

      final amaId = await insertStudent(
        classId: classA,
        studentCode: 'STU-001',
        admissionNumber: 'ADM-001',
        firstName: 'Ama',
      );
      final kojoId = await insertStudent(
        classId: classA,
        studentCode: 'STU-002',
        admissionNumber: 'ADM-002',
        firstName: 'Kojo',
      );
      final yawId = await insertStudent(
        classId: classB,
        studentCode: 'STU-003',
        admissionNumber: 'ADM-003',
        firstName: 'Yaw',
      );

      await db.into(db.payments).insert(
            PaymentsCompanion.insert(
              studentId: amaId,
              feeStructureId: globalFeeId,
              amountPaid: 100,
              paymentDate: drift.Value(DateTime(2026, 1, 15)),
              receiptNumber: 'RCP-001',
            ),
          );
      await db.into(db.payments).insert(
            PaymentsCompanion.insert(
              studentId: amaId,
              feeStructureId: classFeeId,
              amountPaid: 20,
              paymentDate: drift.Value(DateTime(2026, 1, 16)),
              receiptNumber: 'RCP-002',
            ),
          );
      await db.into(db.payments).insert(
            PaymentsCompanion.insert(
              studentId: kojoId,
              feeStructureId: globalFeeId,
              amountPaid: 30,
              paymentDate: drift.Value(DateTime(2026, 1, 17)),
              receiptNumber: 'RCP-003',
            ),
          );

      final rows = await service.getStudentsFeesLedger();

      expect(rows, hasLength(4));

      final amaClassFee = rows.firstWhere(
        (row) => row.studentId == amaId && row.feeStructureId == classFeeId,
      );
      final kojoGlobalFee = rows.firstWhere(
        (row) => row.studentId == kojoId && row.feeStructureId == globalFeeId,
      );
      final kojoClassFee = rows.firstWhere(
        (row) => row.studentId == kojoId && row.feeStructureId == classFeeId,
      );
      final yawGlobalFee = rows.firstWhere(
        (row) => row.studentId == yawId && row.feeStructureId == globalFeeId,
      );

      expect(amaClassFee.balance, closeTo(30, 0.001));
      expect(kojoGlobalFee.balance, closeTo(70, 0.001));
      expect(kojoClassFee.balance, closeTo(50, 0.001));
      expect(yawGlobalFee.balance, closeTo(100, 0.001));

      expect(
        rows.where((row) => row.studentId == amaId && row.feeStructureId == globalFeeId),
        isEmpty,
      );
    });
  });
}