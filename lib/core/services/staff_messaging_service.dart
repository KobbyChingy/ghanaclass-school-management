import 'package:drift/drift.dart' as drift;

import 'package:ghanaclass_school_management/core/database/app_database.dart';

class StaffInboxItem {
  final Notification notification;
  final User? sender;

  const StaffInboxItem({
    required this.notification,
    required this.sender,
  });

  bool get isUnread => (notification.status).toLowerCase() != 'read';
}

class StaffMessagingService {
  final AppDatabase _db;

  StaffMessagingService(this._db);

  Future<int> sendInAppMessage({
    required int fromUserId,
    required String subject,
    required String message,
    int? toUserId,
  }) async {
    final now = DateTime.now();
    return await _db.into(_db.notifications).insert(
          NotificationsCompanion.insert(
            recipientId: drift.Value(toUserId),
            recipientType: 'staff',
            channel: 'in-app',
            subject: drift.Value(subject),
            message: message,
            status: 'sent',
            externalId: const drift.Value(null),
            sentAt: drift.Value(now),
            createdBy: fromUserId,
          ),
        );
  }

  Future<List<StaffInboxItem>> getInboxForUser(int userId) async {
    final notifications = await (_db.select(_db.notifications)
          ..where((n) => n.recipientType.equals('staff'))
          ..where((n) => n.channel.equals('in-app'))
          ..where((n) => n.recipientId.equals(userId) | n.recipientId.isNull())
          ..orderBy([(n) => drift.OrderingTerm.desc(n.createdAt)]))
        .get();

    if (notifications.isEmpty) return const [];

    final senderIds = notifications
        .map((n) => n.createdBy)
        .whereType<int>()
        .toSet()
        .toList(growable: false);

    final senders = senderIds.isEmpty
        ? const <User>[]
        : await (_db.select(_db.users)..where((u) => u.id.isIn(senderIds))).get();

    final senderById = {for (final s in senders) s.id: s};

    return notifications
        .map((n) => StaffInboxItem(notification: n, sender: senderById[n.createdBy]))
        .toList(growable: false);
  }

  Future<int> markRead(int notificationId) async {
    return await (_db.update(_db.notifications)..where((n) => n.id.equals(notificationId))).write(
      const NotificationsCompanion(
        status: drift.Value('read'),
      ),
    );
  }

  Future<int> unreadCountForUser(int userId) async {
    final countExp = _db.notifications.id.count();
    final query = _db.selectOnly(_db.notifications)..addColumns([countExp]);
    query.where(_db.notifications.recipientType.equals('staff'));
    query.where(_db.notifications.channel.equals('in-app'));
    query.where(_db.notifications.recipientId.equals(userId) | _db.notifications.recipientId.isNull());
    query.where(_db.notifications.status.isNotValue('read'));

    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  Future<User?> getFirstAdminUser() async {
    return await (_db.select(_db.users)
          ..where((u) => u.role.equals('admin'))
          ..where((u) => u.isActive.equals(true))
          ..orderBy([(u) => drift.OrderingTerm.asc(u.id)])
          ..limit(1))
        .getSingleOrNull();
  }
}
