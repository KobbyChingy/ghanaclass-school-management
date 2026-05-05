import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
// import removed: unnecessary
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';
import 'package:drift/drift.dart';
// import removed: unused
import 'role_based_dashboard_widget_config.dart';

/// Provider for user dashboard widget config (order, visibility)
final dashboardWidgetConfigProvider = FutureProvider<List<String>>((ref) async {
  final db = ref.watch(databaseProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) return _defaultWidgetOrder;
  final pref = await (db.select(db.userPreferences)
        ..where((p) => p.userId.equals(user.id) & p.key.equals('dashboard_widgets'))
        ..orderBy([(p) => OrderingTerm.desc(p.updatedAt)])
        ..limit(1))
      .getSingleOrNull();
  if (pref == null) {
    // Use role-based default if available
    final role = UserRole.values.firstWhere(
      (r) => r.name == user.role,
      orElse: () => UserRole.admin,
    );
    return roleBasedWidgetOrder[role] ?? _defaultWidgetOrder;
  }
  try {
    final decoded = jsonDecode(pref.value);
    if (decoded is List && decoded.every((e) => e is String)) {
      return List<String>.from(decoded);
    }
  } catch (_) {}
  return _defaultWidgetOrder;
});

const List<String> _defaultWidgetOrder = [
  'ResourceUtilizationCard',
  'AuditLogsAnalyticsCard',
  'DataAccessAnalyticsCard',
];

/// Save user dashboard widget config
Future<void> saveDashboardWidgetConfig(AppDatabase db, int userId, List<String> order) async {
  final value = jsonEncode(order);
  await db.into(db.userPreferences).insertOnConflictUpdate(
    UserPreferencesCompanion(
      userId: Value(userId),
      key: Value('dashboard_widgets'),
      value: Value(value),
      updatedAt: Value(DateTime.now()),
    ),
  );
}
