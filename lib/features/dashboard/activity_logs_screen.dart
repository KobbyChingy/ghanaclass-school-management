import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/providers/activity_providers.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:intl/intl.dart';

class ActivityLogsScreen extends ConsumerWidget {
  const ActivityLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(allActivityLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Logs / Audit Trail'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () => ref.refresh(allActivityLogsProvider),
          ),
        ],
      ),
      body: logsAsync.when(
        data: (logs) {
          if (logs.isEmpty) {
            return const Center(child: Text('No activity logs found.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (_, index) => const Divider(),
            itemBuilder: (context, index) {
              final log = logs[index];
              return _LogItem(log: log);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _LogItem extends StatelessWidget {
  final ActivityLog log;

  const _LogItem({required this.log});

  Color _getModuleColor() {
    switch (log.module) {
      case 'students': return Colors.blue;
      case 'finance': return Colors.green;
      case 'staff': return Colors.pink;
      case 'academic': return Colors.orange;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getModuleColor().withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getIconForModule(log.module),
              color: _getModuleColor(),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      log.actionType.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    Text(
                      DateFormat('MMM dd, yyyy HH:mm').format(log.createdAt),
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  log.description,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  'Performed by: ${log.actorName} (${log.actorRole})',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForModule(String module) {
    switch (module) {
      case 'students': return LucideIcons.graduationCap;
      case 'finance': return LucideIcons.banknote;
      case 'staff': return LucideIcons.userCheck;
      case 'academic': return LucideIcons.bookOpen;
      default: return LucideIcons.activity;
    }
  }
}
