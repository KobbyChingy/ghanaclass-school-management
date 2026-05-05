import 'package:drift/drift.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';

class ActivityService {
  final AppDatabase _database;

  ActivityService(this._database);

  Future<int> logActivity({
    required int actorUserId,
    required String actorName,
    required UserRole actorRole,
    required String module,
    required String actionType,
    required String description,
    bool isImportant = false,
  }) async {
    return await _database.into(_database.activityLogs).insert(
          ActivityLogsCompanion.insert(
            actorUserId: actorUserId,
            actorName: actorName,
            actorRole: actorRole.name,
            module: module,
            actionType: actionType,
            description: description,
            isImportant: Value(isImportant),
          ),
        );
  }

  Future<List<ActivityLog>> getRecentActivities({int limit = 20}) async {
    final query = (_database.select(_database.activityLogs)
          ..orderBy([
            (tbl) => OrderingTerm.desc(tbl.createdAt),
          ])
          ..limit(limit));
    return query.get();
  }

  /// Important items that should surface as admin notifications
  Future<List<ActivityLog>> getImportantActivities({
    int limit = 20,
    UserRole? forRole,
  }) async {
    final query = _database.select(_database.activityLogs)
      ..where((tbl) => tbl.isImportant.equals(true));

    if (forRole != null) {
      query.where((tbl) => tbl.actorRole.equals(forRole.name));
    }

    query
      ..orderBy([
        (tbl) => OrderingTerm.desc(tbl.createdAt),
      ])
      ..limit(limit);

    return query.get();
  }
}

