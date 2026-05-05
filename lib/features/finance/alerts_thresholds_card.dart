import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'finance_analytics_providers.dart';

class AlertsThresholdsCard extends ConsumerWidget {
  const AlertsThresholdsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(alertsThresholdsProvider);
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Alerts & Thresholds',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            alertsAsync.when(
              data: (alerts) {
                if (alerts.isEmpty) {
                  return const Text('No alerts. All metrics are within thresholds.');
                }
                return Column(
                  children: alerts.map((a) => ListTile(
                    leading: Icon(Icons.warning, color: a.isCritical ? Colors.red : Colors.orange),
                    title: Text(a.message),
                    subtitle: Text(a.suggestion),
                  )).toList(),
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
