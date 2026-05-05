import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/features/staff/staff_service.dart';

void main() {
  group('StaffService bulk actions', () {
    late AppDatabase db;
    late StaffService staffService;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      staffService = StaffService(db);
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> insertUser({
      required String email,
      String fullName = 'Test User',
      String role = 'staff',
      bool isActive = true,
    }) async {
      return db.into(db.users).insert(
            UsersCompanion.insert(
              fullName: fullName,
              email: email,
              passwordHash: 'hash',
              role: role,
              isActive: drift.Value(isActive),
            ),
          );
    }

    Future<int> insertStaff({
      required int userId,
      required String staffId,
      String firstName = 'Jane',
      String lastName = 'Doe',
      bool isActive = true,
    }) async {
      return db.into(db.staff).insert(
            StaffCompanion.insert(
              userId: userId,
              staffId: staffId,
              firstName: firstName,
              lastName: lastName,
              gender: 'female',
              dateOfBirth: DateTime(1990, 1, 1),
              phoneNumber: '0550000000',
              position: 'teacher',
              hireDate: DateTime(2024, 1, 1),
              baseSalary: 1000.0,
              isActive: drift.Value(isActive),
            ),
          );
    }

    test('bulkDeactivateStaff deactivates staff and users', () async {
      final userId1 = await insertUser(email: 'a@test.local');
      final userId2 = await insertUser(email: 'b@test.local');

      final staffId1 = await insertStaff(userId: userId1, staffId: 'STAFF-1');
      final staffId2 = await insertStaff(userId: userId2, staffId: 'STAFF-2');

      final result = await staffService.bulkDeactivateStaff([staffId1, staffId2], deactivateUsers: true);
      expect(result.requested, 2);
      expect(result.affected, 2);
      expect(result.skippedStaffTableIds, isEmpty);
      expect(result.errors, isEmpty);

      final staff1 = await (db.select(db.staff)..where((t) => t.id.equals(staffId1))).getSingle();
      final staff2 = await (db.select(db.staff)..where((t) => t.id.equals(staffId2))).getSingle();
      expect(staff1.isActive, isFalse);
      expect(staff2.isActive, isFalse);

      final user1 = await (db.select(db.users)..where((t) => t.id.equals(userId1))).getSingle();
      final user2 = await (db.select(db.users)..where((t) => t.id.equals(userId2))).getSingle();
      expect(user1.isActive, isFalse);
      expect(user2.isActive, isFalse);
    });

    test('bulkDeleteStaff deletes unreferenced staff and deactivates user', () async {
      final userId = await insertUser(email: 'c@test.local');
      final staffTableId = await insertStaff(userId: userId, staffId: 'STAFF-3');

      final result = await staffService.bulkDeleteStaff([staffTableId], deactivateUsers: true);
      expect(result.requested, 1);
      expect(result.affected, 1);
      expect(result.skippedStaffTableIds, isEmpty);

      final remainingStaff = await (db.select(db.staff)..where((t) => t.id.equals(staffTableId))).getSingleOrNull();
      expect(remainingStaff, isNull);

      final user = await (db.select(db.users)..where((t) => t.id.equals(userId))).getSingle();
      expect(user.isActive, isFalse);
    });

    test('bulkDeleteStaff skips staff referenced by staff attendance records', () async {
      final userId = await insertUser(email: 'd@test.local', isActive: true);
      final staffTableId = await insertStaff(userId: userId, staffId: 'STAFF-4', isActive: true);

      final sessionId = await db.into(db.staffAttendanceSessions).insert(
            StaffAttendanceSessionsCompanion.insert(
              date: DateTime(2025, 1, 1),
              period: drift.Value('Morning'),
            ),
          );

      await db.into(db.staffAttendanceRecords).insert(
            StaffAttendanceRecordsCompanion.insert(
              sessionId: sessionId,
              staffId: staffTableId,
              status: 'present',
            ),
          );

      final result = await staffService.bulkDeleteStaff([staffTableId], deactivateUsers: true);
      expect(result.requested, 1);
      expect(result.affected, 0);
      expect(result.skippedStaffTableIds, [staffTableId]);
      expect(result.errors, isNotEmpty);

      final remainingStaff = await (db.select(db.staff)..where((t) => t.id.equals(staffTableId))).getSingleOrNull();
      expect(remainingStaff, isNotNull);

      final user = await (db.select(db.users)..where((t) => t.id.equals(userId))).getSingle();
      expect(user.isActive, isTrue);
    });
  });
}
