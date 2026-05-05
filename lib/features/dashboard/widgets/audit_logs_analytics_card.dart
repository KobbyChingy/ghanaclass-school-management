import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghanaclass_school_management/core/providers/activity_providers.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

/// Analytics card for audit logs summary
class AuditLogsAnalyticsCard extends ConsumerWidget {
  const AuditLogsAnalyticsCard({super.key});

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
              'Audit Logs Analytics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            logsAsync.when(
              data: (logs) {
                if (logs.isEmpty) {
                  return const Text('No audit logs found.');
                }
                final today = DateTime.now();
                final todayCount = logs.where((log) => log.createdAt.year == today.year && log.createdAt.month == today.month && log.createdAt.day == today.day).length;
                final byModule = <String, int>{};
                for (final log in logs) {
                  byModule[log.module] = (byModule[log.module] ?? 0) + 1;
                }
                final topModules = byModule.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Logs (last 100): ${logs.length}'),
                    Text('Today: $todayCount'),
                    const SizedBox(height: 8),
                    const Text('Top Modules:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ...topModules.take(3).map((e) => Text('${e.key}: ${e.value}')),
                    const SizedBox(height: 12),
                    const Text('Recent Actions:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ...logs.take(5).map((log) => ListTile(
                          dense: true,
                          leading: const Icon(LucideIcons.activity, size: 18),
                          title: Text(log.description),
                          subtitle: Text('${log.module} • ${DateFormat('MMM d, h:mm a').format(log.createdAt)}'),
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
