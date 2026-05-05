import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/core/services/activity_service.dart';
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';
import 'package:ghanaclass_school_management/core/router/role_routes.dart';

final activityServiceProvider = Provider<ActivityService>((ref) {
  final db = ref.watch(databaseProvider);
  return ActivityService(db);
});

/// Latest activity feed for dashboards
final recentActivitiesProvider = FutureProvider<List<ActivityLog>>((ref) async {
  return ref.watch(activityServiceProvider).getRecentActivities(limit: 25);
});

final allActivityLogsProvider = FutureProvider<List<ActivityLog>>((ref) async {
  return ref.watch(activityServiceProvider).getRecentActivities(limit: 100);
});

/// Important activities that double as notifications for admins
final importantActivitiesProvider =
    FutureProvider<List<ActivityLog>>((ref) async {
  final currentUser = ref.watch(currentUserProvider);

  // No session yet (or logged out) => no portal notifications.
  if (currentUser == null) return const <ActivityLog>[];

  final role = UserRole.values.firstWhere(
    (r) => roleNameMatches(currentUser.role, r),
    orElse: () => UserRole.admin,
  );

  // Leadership roles see all important events
  const leadershipRoles = [
    UserRole.admin,
    UserRole.director,
    UserRole.headmaster,
    UserRole.headmistress,
    UserRole.deputyheadmaster,
    UserRole.deputyheadmistress,
  ];

  if (leadershipRoles.contains(role)) {
    return ref.watch(activityServiceProvider).getImportantActivities(limit: 15);
  } else {
    return ref
        .watch(activityServiceProvider)
        .getImportantActivities(limit: 15, forRole: role);
  }
});

