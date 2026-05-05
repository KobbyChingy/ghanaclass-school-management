import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'staff_service.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';

final staffServiceProvider = Provider<StaffService>((ref) {
  final db = ref.watch(databaseProvider);
  return StaffService(db);
});

final staffListProvider = FutureProvider<List<StaffData>>((ref) async {
  return ref.watch(staffServiceProvider).getAllStaff();
});

final staffWithUserProvider = FutureProvider.family<StaffWithUser?, int>((ref, staffTableId) async {
  return ref.watch(staffServiceProvider).getStaffWithUserByStaffId(staffTableId);
});

final currentStaffProfileProvider = FutureProvider<StaffWithUser?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.watch(staffServiceProvider).getStaffWithUserForCurrentUser(user);
});

final directorAccountExistsProvider = FutureProvider.family<bool, int?>((ref, excludeUserId) async {
  final db = ref.watch(databaseProvider);
  final query = db.select(db.users)..where((u) => u.role.equals('director'));

  if (excludeUserId != null) {
    query.where((u) => u.id.isNotValue(excludeUserId));
  }

  final existing = await query.getSingleOrNull();
  return existing != null;
});

final teachersProvider = FutureProvider<List<User>>((ref) async {
  final db = ref.watch(databaseProvider);
  return (db.select(db.users)..where((u) => u.role.equals('teacher'))).get();
});
