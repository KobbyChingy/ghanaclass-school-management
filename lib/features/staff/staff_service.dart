import 'package:drift/drift.dart' as drift;
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';

class StaffWithUser {
  final StaffData staff;
  final User? user;

  const StaffWithUser({required this.staff, required this.user});
}

class BulkStaffActionResult {
  final int requested;
  final int affected;
  final List<int> skippedStaffTableIds;
  final List<String> errors;

  const BulkStaffActionResult({
    required this.requested,
    required this.affected,
    required this.skippedStaffTableIds,
    required this.errors,
  });
}

class StaffService {
  final AppDatabase _database;

  StaffService(this._database);

  Future<List<StaffData>> getAllStaff() async {
    await _database.repairStaffRows();
    final q = _database.select(_database.staff)
      ..orderBy([
        (t) => drift.OrderingTerm(expression: t.lastName),
        (t) => drift.OrderingTerm(expression: t.firstName),
        (t) => drift.OrderingTerm(expression: t.staffId),
      ]);
    return await q.get();
  }

  Future<StaffData?> getStaffByUserId(int userId) async {
    return (_database.select(_database.staff)..where((t) => t.userId.equals(userId))).getSingleOrNull();
  }

  Future<StaffData?> getStaffByStaffId(String staffId) async {
    final normalized = staffId.trim();
    return (_database.select(_database.staff)..where((t) => t.staffId.equals(normalized))).getSingleOrNull();
  }

  Future<int> createStaff(StaffCompanion entry) async {
    return await _database.into(_database.staff).insert(entry);
  }

  Future<bool> updateStaff(StaffCompanion entry) async {
    return await (_database.update(_database.staff)
          ..where((t) => t.id.equals(entry.id.value)))
        .write(entry) > 0;
  }

  Future<int> deleteStaff(int id) async {
    return await (_database.delete(_database.staff)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  Future<BulkStaffActionResult> bulkDeactivateStaff(List<int> staffTableIds, {bool deactivateUsers = true}) async {
    final ids = staffTableIds.toSet().toList();
    if (ids.isEmpty) {
      return const BulkStaffActionResult(requested: 0, affected: 0, skippedStaffTableIds: [], errors: []);
    }

    var affected = 0;
    final errors = <String>[];

    await _database.transaction(() async {
      final staffRows = await (_database.select(_database.staff)..where((t) => t.id.isIn(ids))).get();
      final now = DateTime.now();

      affected = await (_database.update(_database.staff)..where((t) => t.id.isIn(ids))).write(
        StaffCompanion(
          isActive: const drift.Value(false),
          updatedAt: drift.Value(now),
        ),
      );

      if (deactivateUsers) {
        final userIds = staffRows.map((s) => s.userId).toSet().toList();
        if (userIds.isNotEmpty) {
          await (_database.update(_database.users)..where((u) => u.id.isIn(userIds))).write(
            UsersCompanion(
              isActive: const drift.Value(false),
              updatedAt: drift.Value(now),
            ),
          );
        }
      }
    });

    return BulkStaffActionResult(requested: ids.length, affected: affected, skippedStaffTableIds: const [], errors: errors);
  }

  Future<BulkStaffActionResult> bulkDeleteStaff(List<int> staffTableIds, {bool deactivateUsers = true}) async {
    final ids = staffTableIds.toSet().toList();
    if (ids.isEmpty) {
      return const BulkStaffActionResult(requested: 0, affected: 0, skippedStaffTableIds: [], errors: []);
    }

    var affected = 0;
    final errors = <String>[];
    final skipped = <int>[];

    await _database.transaction(() async {
      final now = DateTime.now();
      final staffRows = await (_database.select(_database.staff)..where((t) => t.id.isIn(ids))).get();

      // Safety: do not delete staff profiles that are referenced by attendance records.
      final referencedRows = await (_database.select(_database.staffAttendanceRecords)
            ..where((t) => t.staffId.isIn(ids))
            ..limit(500))
          .get();
      final referencedStaffIds = referencedRows.map((r) => r.staffId).toSet();

      final deletableStaffIds = ids.where((id) => !referencedStaffIds.contains(id)).toList();
      skipped.addAll(ids.where(referencedStaffIds.contains));

      if (deletableStaffIds.isNotEmpty) {
        if (deactivateUsers) {
          final userIds = staffRows
              .where((s) => deletableStaffIds.contains(s.id))
              .map((s) => s.userId)
              .toSet()
              .toList();
          if (userIds.isNotEmpty) {
            await (_database.update(_database.users)..where((u) => u.id.isIn(userIds))).write(
              UsersCompanion(
                isActive: const drift.Value(false),
                updatedAt: drift.Value(now),
              ),
            );
          }
        }

        affected = await (_database.delete(_database.staff)..where((t) => t.id.isIn(deletableStaffIds))).go();
      }

      if (skipped.isNotEmpty) {
        errors.add('Skipped ${skipped.length} staff: referenced by attendance records. Consider deactivating instead.');
      }
    });

    return BulkStaffActionResult(requested: ids.length, affected: affected, skippedStaffTableIds: skipped, errors: errors);
  }

  Future<StaffWithUser?> getStaffWithUserByStaffId(int staffTableId) async {
    final staff = await (_database.select(_database.staff)..where((t) => t.id.equals(staffTableId))).getSingleOrNull();
    if (staff == null) return null;
    final user = await (_database.select(_database.users)..where((u) => u.id.equals(staff.userId))).getSingleOrNull();
    return StaffWithUser(staff: staff, user: user);
  }

  Future<StaffWithUser?> getStaffWithUserForCurrentUser(User currentUser) async {
    User? resolvedUser;

    resolvedUser = await (_database.select(_database.users)..where((u) => u.id.equals(currentUser.id))).getSingleOrNull();

    final remoteId = currentUser.remoteId?.trim();
    if (resolvedUser == null && remoteId != null && remoteId.isNotEmpty) {
      resolvedUser ??= await (_database.select(_database.users)..where((u) => u.remoteId.equals(remoteId))).getSingleOrNull();
    }

    resolvedUser ??= await (_database.select(_database.users)..where((u) => u.email.equals(currentUser.email.toLowerCase().trim()))).getSingleOrNull();

    if (resolvedUser == null) return null;

    final staff = await getStaffByUserId(resolvedUser.id);
    if (staff == null) return null;

    return StaffWithUser(staff: staff, user: resolvedUser);
  }

  Future<void> updateStaffAndUser({
    required int staffTableId,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String position,
    required DateTime hireDate,
    required DateTime dateOfBirth,
    required String gender,
    required double baseSalary,
    String? address,
    String? department,
    String? emergencyContact,
    bool? isActive,
    String? portalRole,
  }) async {
    await _database.transaction(() async {
      final staff = await (_database.select(_database.staff)..where((t) => t.id.equals(staffTableId))).getSingle();

      if (portalRole == UserRole.director.name) {
        final existingDirector = await (_database.select(_database.users)
              ..where((u) => u.role.equals(UserRole.director.name) & u.id.isNotValue(staff.userId))
              ..limit(1))
            .getSingleOrNull();
        if (existingDirector != null) {
          throw Exception('Only one Director account is allowed for a school');
        }
      }

      await (_database.update(_database.staff)..where((t) => t.id.equals(staffTableId))).write(
        StaffCompanion(
          id: drift.Value(staffTableId),
          userId: drift.Value(staff.userId),
          staffId: drift.Value(staff.staffId),
          firstName: drift.Value(firstName),
          lastName: drift.Value(lastName),
          gender: drift.Value(gender),
          dateOfBirth: drift.Value(dateOfBirth),
          phoneNumber: drift.Value(phoneNumber),
          address: drift.Value(address),
          emergencyContact: drift.Value(emergencyContact),
          position: drift.Value(position),
          department: drift.Value(department),
          hireDate: drift.Value(hireDate),
          baseSalary: drift.Value(baseSalary),
          isActive: isActive == null ? const drift.Value.absent() : drift.Value(isActive),
          updatedAt: drift.Value(DateTime.now()),
        ),
      );

      final user = await (_database.select(_database.users)..where((u) => u.id.equals(staff.userId))).getSingleOrNull();
      if (user != null) {
        await (_database.update(_database.users)..where((u) => u.id.equals(user.id))).write(
          UsersCompanion(
            id: drift.Value(user.id),
            fullName: drift.Value('$firstName $lastName'),
            phoneNumber: drift.Value(phoneNumber),
            role: portalRole == null ? const drift.Value.absent() : drift.Value(portalRole),
            isActive: isActive == null ? const drift.Value.absent() : drift.Value(isActive),
            updatedAt: drift.Value(DateTime.now()),
          ),
        );
      }
    });
  }
}
