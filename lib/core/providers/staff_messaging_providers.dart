import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/core/services/staff_messaging_service.dart';

final staffMessagingServiceProvider = Provider<StaffMessagingService>((ref) {
  final db = ref.watch(databaseProvider);
  return StaffMessagingService(db);
});

final staffInboxProvider = FutureProvider.autoDispose<List<StaffInboxItem>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  final svc = ref.watch(staffMessagingServiceProvider);
  return await svc.getInboxForUser(user.id);
});

final staffUnreadInboxCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return 0;
  final svc = ref.watch(staffMessagingServiceProvider);
  return await svc.unreadCountForUser(user.id);
});
