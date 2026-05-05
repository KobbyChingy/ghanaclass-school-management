import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghanaclass_school_management/core/providers/activity_providers.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

/// Analytics card for data access patterns (from audit logs)
class DataAccessAnalyticsCard extends ConsumerWidget {
  const DataAccessAnalyticsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(allActivityLogsProvider);
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Data Access Analytics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            logsAsync.when(
              data: (logs) {
                if (logs.isEmpty) {
                  return const Text('No access logs found.');
                }
                final byUser = <String, int>{};
                final byRole = <String, int>{};
                for (final log in logs) {
                  byUser[log.actorName] = (byUser[log.actorName] ?? 0) + 1;
                  byRole[log.actorRole] = (byRole[log.actorRole] ?? 0) + 1;
                }
                final topUsers = byUser.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                final topRoles = byRole.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Unique Users: ${byUser.length}'),
                    Text('Unique Roles: ${byRole.length}'),
                    const SizedBox(height: 8),
                    const Text('Top Users:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ...topUsers.take(3).map((e) => Text('${e.key}: ${e.value} actions')),
                    const SizedBox(height: 8),
                    const Text('Top Roles:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ...topRoles.take(3).map((e) => Text('${e.key}: ${e.value} actions')),
                    const SizedBox(height: 12),
                    const Text('Recent Access:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ...logs.take(5).map((log) => ListTile(
                          dense: true,
                          leading: const Icon(LucideIcons.user, size: 18),
                          title: Text(log.actorName),
                          subtitle: Text('${log.actorRole} • ${DateFormat('MMM d, h:mm a').format(log.createdAt)}'),
                          trailing: Text(log.module),
                        )),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }
}
