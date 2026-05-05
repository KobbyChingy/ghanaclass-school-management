import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/providers/staff_messaging_providers.dart';

class StaffInboxScreen extends ConsumerWidget {
  const StaffInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inboxAsync = ref.watch(staffInboxProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
      ),
      body: inboxAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.inbox, size: 56, color: AppTheme.textMuted.withValues(alpha: 0.6)),
                  const SizedBox(height: 14),
                  const Text('No messages yet.'),
                  const SizedBox(height: 6),
                  const Text('Messages sent to you will appear here.', style: TextStyle(color: AppTheme.textMuted)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              final n = item.notification;
              final senderName = item.sender?.fullName ?? 'System';
              final subject = (n.subject ?? '').trim().isEmpty ? 'Message' : n.subject!.trim();
              final when = _formatDateTime(n.createdAt);

              return Card(
                child: ListTile(
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: (item.isUnread ? AppTheme.authorityYellow : AppTheme.actionIndigo).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.isUnread ? LucideIcons.mailOpen : LucideIcons.mail, color: item.isUnread ? AppTheme.authorityYellow : AppTheme.actionIndigo),
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(subject, style: TextStyle(fontWeight: item.isUnread ? FontWeight.w800 : FontWeight.w600))),
                      if (item.isUnread)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.authorityYellow.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppTheme.authorityYellow.withValues(alpha: 0.35)),
                          ),
                          child: const Text('NEW', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                        ),
                    ],
                  ),
                  subtitle: Text('From: $senderName • $when', style: const TextStyle(color: AppTheme.textMuted)),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18, color: AppTheme.textMuted),
                  onTap: () async {
                    await showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(subject),
                        content: SizedBox(
                          width: 560,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('From: $senderName', style: const TextStyle(color: AppTheme.textMuted)),
                              const SizedBox(height: 12),
                              Text(n.message),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                        ],
                      ),
                    );

                    if (item.isUnread) {
                      final svc = ref.read(staffMessagingServiceProvider);
                      await svc.markRead(n.id);
                      ref.invalidate(staffInboxProvider);
                      ref.invalidate(staffUnreadInboxCountProvider);
                    }
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  static String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final yyyy = local.year.toString().padLeft(4, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mi = local.minute.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd $hh:$mi';
  }
}
