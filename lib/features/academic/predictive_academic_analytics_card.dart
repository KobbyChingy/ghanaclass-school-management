import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../academic/academic_providers.dart';

class PredictiveAcademicAnalyticsCard extends ConsumerWidget {
  const PredictiveAcademicAnalyticsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classSummariesAsync = ref.watch(classAssignmentSummariesProvider);
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Predictive Academic Analytics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            classSummariesAsync.when(
              data: (summaries) {
                if (summaries.isEmpty) {
                  return const Text('No academic data available.');
                }
                // Example: Show risk based on low subject/teacher ratio
                return Column(
                  children: summaries.entries.map((entry) {
                    final summary = entry.value;
                    final risk = summary.subjectsCount < 5 || summary.teachersCount < 3;
                    return ListTile(
                      leading: Icon(risk ? Icons.warning : Icons.check_circle,
                        color: risk ? Colors.red : Colors.green),
                      title: Text('Class ${entry.key}'),
                      subtitle: Text('Subjects: ${summary.subjectsCount}, Teachers: ${summary.teachersCount}'),
                      trailing: risk ? const Text('At Risk', style: TextStyle(color: Colors.red)) : const Text('OK', style: TextStyle(color: Colors.green)),
                    );
                  }).toList(),
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
