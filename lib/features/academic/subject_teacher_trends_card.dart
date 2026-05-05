import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../academic/academic_providers.dart';

class SubjectTeacherTrendsCard extends ConsumerWidget {
  const SubjectTeacherTrendsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsProvider);
    final classSummariesAsync = ref.watch(classAssignmentSummariesProvider);
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Subject-Level Trends & Teacher Effectiveness',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            subjectsAsync.when(
              data: (subjects) => classSummariesAsync.when(
                data: (summaries) {
                  if (subjects.isEmpty || summaries.isEmpty) {
                    return const Text('No subject or teacher data available.');
                  }
                  // Example: Show subject coverage and teacher ratio
                  return Column(
                    children: subjects.map((subject) {
                      int totalClasses = 0;
                      int totalTeachers = 0;
                      for (final summary in summaries.values) {
                        totalClasses += summary.subjectsCount;
                        totalTeachers += summary.teachersCount;
                      }
                      final coverage = totalClasses > 0 ? (1 / totalClasses) * 100 : 0;
                      final effectiveness = totalTeachers > 0 ? (totalTeachers / totalClasses) : 0;
                      return ListTile(
                        leading: const Icon(Icons.book, color: Colors.blue),
                        title: Text(subject.subjectName),
                        subtitle: Text('Coverage: ${coverage.toStringAsFixed(1)}% | Teacher Effectiveness: ${effectiveness.toStringAsFixed(2)}'),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Text('Error: $e'),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }
}
