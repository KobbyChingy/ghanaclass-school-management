import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dashboard_widget_config_provider.dart';
import 'resource_utilization_card.dart';
import 'audit_logs_analytics_card.dart';
import 'data_access_analytics_card.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
// import removed: unnecessary

/// User-configurable dashboard that allows reordering/hiding widgets
class UserConfigurableDashboard extends ConsumerWidget {
  const UserConfigurableDashboard({super.key});

  Widget _widgetByName(String name) {
    switch (name) {
      case 'ResourceUtilizationCard':
        return const ResourceUtilizationCard();
      case 'AuditLogsAnalyticsCard':
        return const AuditLogsAnalyticsCard();
      case 'DataAccessAnalyticsCard':
        return const DataAccessAnalyticsCard();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(dashboardWidgetConfigProvider);
    return configAsync.when(
      data: (order) => ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        onReorder: (oldIndex, newIndex) async {
          if (oldIndex < newIndex) newIndex--;
          final newOrder = List<String>.from(order);
          final item = newOrder.removeAt(oldIndex);
          newOrder.insert(newIndex, item);
          final user = ref.read(currentUserProvider);
          final db = ref.read(databaseProvider);
          if (user != null) {
            await saveDashboardWidgetConfig(db, user.id, newOrder);
            ref.invalidate(dashboardWidgetConfigProvider);
          }
        },
        children: [
          for (final name in order)
            Padding(
              key: ValueKey(name),
              padding: const EdgeInsets.only(bottom: 24),
              child: _widgetByName(name),
            ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Text('Error: $e'),
    );
  }
}
