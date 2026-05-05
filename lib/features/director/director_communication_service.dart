import 'package:drift/drift.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/core/services/email_service.dart';
import 'package:ghanaclass_school_management/core/services/sms_service.dart';

enum DirectorAudience {
  parents,
  staff,
}

enum DirectorChannel {
  sms,
  email,
  inApp,
}

class DirectorSendResult {
  const DirectorSendResult({
    required this.success,
    required this.message,
    required this.recipientCount,
  });

  final bool success;
  final String message;
  final int recipientCount;
}

class DirectorCommunicationService {
  DirectorCommunicationService(
    this._db, {
    required SmsGateway? smsGateway,
    required EmailGateway? emailGateway,
  })  : _smsGateway = smsGateway,
        _emailGateway = emailGateway;

  final AppDatabase _db;
  final SmsGateway? _smsGateway;
  final EmailGateway? _emailGateway;

  Stream<List<Notification>> watchRecentNotifications({int limit = 25}) {
    return (_db.select(_db.notifications)
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .watch();
  }

  Future<DirectorSendResult> sendBroadcast({
    required int createdByUserId,
    required DirectorAudience audience,
    required DirectorChannel channel,
    required String subject,
    required String message,
  }) async {
    final trimmedMessage = message.trim();
    final trimmedSubject = subject.trim();

    if (trimmedMessage.isEmpty) {
      return const DirectorSendResult(success: false, message: 'Message cannot be empty.', recipientCount: 0);
    }

    final recipients = await _resolveRecipients(audience: audience, channel: channel);
    if (recipients.isEmpty) {
      return const DirectorSendResult(success: false, message: 'No recipients found.', recipientCount: 0);
    }

    final now = DateTime.now();
    final insertedIds = <int>[];

    for (final r in recipients) {
      final row = await _db.into(_db.notifications).insertReturning(
            NotificationsCompanion.insert(
              recipientId: Value(r.recipientId),
              recipientType: r.recipientType,
              channel: _channelToken(channel),
              subject: trimmedSubject.isEmpty ? const Value.absent() : Value(trimmedSubject),
              message: trimmedMessage,
              status: 'pending',
              createdBy: createdByUserId,
            ),
          );
      insertedIds.add(row.id);
    }

    DirectorSendResult sendResult;
    String? externalId;

    switch (channel) {
      case DirectorChannel.inApp:
        sendResult = DirectorSendResult(
          success: true,
          message: 'In-app notification logged for ${recipients.length} recipient(s).',
          recipientCount: recipients.length,
        );
        break;
      case DirectorChannel.sms:
        final gateway = _smsGateway;
        if (gateway == null) {
          sendResult = const DirectorSendResult(
            success: false,
            message: 'SMS is not configured (enable in Settings).',
            recipientCount: 0,
          );
          break;
        }
        final announcement = trimmedSubject.isEmpty ? trimmedMessage : '$trimmedSubject\n$trimmedMessage';
        final smsResult = await gateway.sendBulkAnnouncement(
          phoneNumbers: recipients.map((e) => e.address).toList(growable: false),
          announcement: announcement,
        );
        externalId = smsResult.messageId;
        sendResult = DirectorSendResult(
          success: smsResult.success,
          message: smsResult.message,
          recipientCount: smsResult.recipientCount,
        );
        break;
      case DirectorChannel.email:
        final gateway = _emailGateway;
        if (gateway == null) {
          sendResult = const DirectorSendResult(
            success: false,
            message: 'Email is not configured (enable in Settings).',
            recipientCount: 0,
          );
          break;
        }
        final emailResult = await gateway.sendBulkAnnouncement(
          recipients: recipients.map((e) => e.address).toList(growable: false),
          subject: trimmedSubject.isEmpty ? 'Announcement' : trimmedSubject,
          body: trimmedMessage,
        );
        sendResult = DirectorSendResult(
          success: emailResult.success,
          message: emailResult.message,
          recipientCount: recipients.length,
        );
        break;
    }

    final newStatus = sendResult.success ? 'sent' : 'failed';

    await _db.batch((batch) {
      for (final id in insertedIds) {
        batch.update(
          _db.notifications,
          NotificationsCompanion(
            status: Value(newStatus),
            sentAt: sendResult.success ? Value(now) : const Value.absent(),
            externalId: externalId == null ? const Value.absent() : Value(externalId),
          ),
          where: (t) => t.id.equals(id),
        );
      }
    });

    return sendResult;
  }

  Future<DirectorSendResult> sendEmergencyAlert({
    required int createdByUserId,
    required DirectorChannel channel,
    required String message,
  }) async {
    final composedSubject = 'EMERGENCY ALERT';

    // Emergency alerts: send to both audiences.
    final parents = await sendBroadcast(
      createdByUserId: createdByUserId,
      audience: DirectorAudience.parents,
      channel: channel,
      subject: composedSubject,
      message: message,
    );

    final staff = await sendBroadcast(
      createdByUserId: createdByUserId,
      audience: DirectorAudience.staff,
      channel: channel,
      subject: composedSubject,
      message: message,
    );

    return DirectorSendResult(
      success: parents.success && staff.success,
      message: 'Parents: ${parents.message}. Staff: ${staff.message}.',
      recipientCount: parents.recipientCount + staff.recipientCount,
    );
  }

  Future<List<_ResolvedRecipient>> _resolveRecipients({
    required DirectorAudience audience,
    required DirectorChannel channel,
  }) async {
    switch (audience) {
      case DirectorAudience.parents:
        final rows = await (_db.select(_db.parentAccounts)..where((t) => t.isActive.equals(true))).get();
        return rows
            .map((p) {
              final address = channel == DirectorChannel.email ? p.email : p.phoneNumber;
              return _ResolvedRecipient(
                recipientId: p.id,
                recipientType: 'parent',
                address: address.trim(),
              );
            })
            .where((r) => r.address.isNotEmpty)
            .toList(growable: false);

      case DirectorAudience.staff:
        final rows = await (_db.select(_db.users)..where((t) => t.isActive.equals(true))).get();
        return rows
            .map((u) {
              final address = channel == DirectorChannel.email ? u.email : (u.phoneNumber ?? '');
              return _ResolvedRecipient(
                recipientId: u.id,
                recipientType: 'staff',
                address: address.trim(),
              );
            })
            .where((r) => r.address.isNotEmpty)
            .toList(growable: false);
    }
  }

  String _channelToken(DirectorChannel channel) {
    switch (channel) {
      case DirectorChannel.sms:
        return 'sms';
      case DirectorChannel.email:
        return 'email';
      case DirectorChannel.inApp:
        return 'in-app';
    }
  }
}

class _ResolvedRecipient {
  const _ResolvedRecipient({
    required this.recipientId,
    required this.recipientType,
    required this.address,
  });

  final int recipientId;
  final String recipientType;
  final String address;
}
