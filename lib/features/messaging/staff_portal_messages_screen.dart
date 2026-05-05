import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/core/providers/communication_providers.dart';
import 'package:ghanaclass_school_management/core/providers/staff_messaging_providers.dart';

class StaffPortalMessagesScreen extends ConsumerWidget {
  final String title;

  const StaffPortalMessagesScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final identityAsync = ref.watch(institutionalIdentityProvider);
    final smsAsync = ref.watch(smsServiceProvider);
    final emailAsync = ref.watch(emailServiceProvider);
    final unreadInboxAsync = ref.watch(staffUnreadInboxCountProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/inbox'),
            icon: const Icon(LucideIcons.inbox, size: 18),
            label: unreadInboxAsync.maybeWhen(
              data: (count) => Text(count > 0 ? 'Inbox ($count)' : 'Inbox'),
              orElse: () => const Text('Inbox'),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.send, color: AppTheme.actionIndigo),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('Send Message', style: TextStyle(fontWeight: FontWeight.bold))),
                      identityAsync.maybeWhen(
                        data: (i) {
                          final email = i?.officialEmail.trim() ?? '';
                          final phone = i?.phoneNumber?.trim() ?? '';
                          final hasAny = email.isNotEmpty || phone.isNotEmpty;
                          return Text(
                            hasAny ? '' : 'Not configured',
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                          );
                        },
                        orElse: () => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  identityAsync.maybeWhen(
                    data: (i) {
                      final email = i?.officialEmail.trim() ?? '';
                      final phone = i?.phoneNumber?.trim() ?? '';
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(LucideIcons.mail, size: 18),
                            label: Text(email.isEmpty ? 'Email (missing)' : 'Email Admin'),
                            onPressed: email.isEmpty
                                ? null
                                : () async {
                                    final res = await _compose(context, title: 'Email Admin', subjectHint: 'Subject', messageHint: 'Message');
                                    if (res == null) return;
                                    final gateway = emailAsync.asData?.value;
                                    if (gateway == null) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Email is not configured. Enable it in Settings.'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                    final result = await gateway.sendBulkAnnouncement(
                                      recipients: [email],
                                      subject: res.subject,
                                      body: res.message,
                                    );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(result.message),
                                        backgroundColor: result.success ? Colors.green : Colors.red,
                                      ),
                                    );
                                  },
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(LucideIcons.messageCircle, size: 18),
                            label: Text(phone.isEmpty ? 'SMS (missing)' : 'SMS Admin'),
                            onPressed: phone.isEmpty
                                ? null
                                : () async {
                                    final res = await _compose(context, title: 'SMS Admin', subjectHint: 'Optional subject', messageHint: 'Message');
                                    if (res == null) return;
                                    final gateway = smsAsync.asData?.value;
                                    if (gateway == null) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('SMS is not configured. Enable it in Settings.'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                    final result = await gateway.sendSms(phoneNumber: phone, message: res.message);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(result.message),
                                        backgroundColor: result.success ? Colors.green : Colors.red,
                                      ),
                                    );
                                  },
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(LucideIcons.inbox, size: 18),
                            label: const Text('In-App (to Admin)'),
                            onPressed: () async {
                              final res = await _compose(context, title: 'In-App Message', subjectHint: 'Subject', messageHint: 'Message');
                              if (res == null) return;
                              final svc = ref.read(staffMessagingServiceProvider);
                              final admin = await svc.getFirstAdminUser();
                              if (admin == null) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('No active admin user found.'), backgroundColor: Colors.red),
                                );
                                return;
                              }
                              await svc.sendInAppMessage(
                                fromUserId: user.id,
                                toUserId: admin.id,
                                subject: res.subject,
                                message: res.message,
                              );
                              ref.invalidate(staffInboxProvider);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('In-app message sent to Admin.'), backgroundColor: Colors.green),
                              );
                            },
                          ),
                        ],
                      );
                    },
                    orElse: () => const Text('Loading school contacts...', style: TextStyle(color: AppTheme.textMuted)),
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(LucideIcons.mailbox, color: AppTheme.authorityYellow),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('Inbox', style: TextStyle(fontWeight: FontWeight.bold))),
                      unreadInboxAsync.maybeWhen(
                        data: (count) => Text(
                          count > 0 ? '$count unread' : '',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    icon: const Icon(LucideIcons.inbox, size: 18),
                    label: const Text('Open Inbox'),
                    onPressed: () => context.go('/inbox'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposeResult {
  final String subject;
  final String message;

  const _ComposeResult({required this.subject, required this.message});
}

Future<_ComposeResult?> _compose(
  BuildContext context, {
  required String title,
  required String subjectHint,
  required String messageHint,
}) async {
  final subjectController = TextEditingController();
  final messageController = TextEditingController();

  try {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: subjectController,
                  decoration: InputDecoration(labelText: subjectHint, border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageController,
                  decoration: InputDecoration(labelText: messageHint, border: const OutlineInputBorder()),
                  minLines: 4,
                  maxLines: 8,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
          ],
        );
      },
    );

    if (ok != true) return null;

    final subject = subjectController.text.trim().isEmpty ? 'Message' : subjectController.text.trim();
    final message = messageController.text.trim();
    if (message.isEmpty) return null;

    return _ComposeResult(subject: subject, message: message);
  } finally {
    subjectController.dispose();
    messageController.dispose();
  }
}
