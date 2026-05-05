import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../academic/academic_providers.dart';
import '../attendance/attendance_providers.dart';

class AttendanceCorrelationCard extends ConsumerWidget {
  const AttendanceCorrelationCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(classesProvider);
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attendance Correlation Analytics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            classesAsync.when(
              data: (classes) {
                if (classes.isEmpty) {
                  return const Text('No classes found.');
                }
                return Column(
                  children: classes.map((cls) {
                    return _AttendanceCorrelationTile(classId: cls.id, className: cls.className);
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

class _AttendanceCorrelationTile extends ConsumerWidget {
  final int classId;
  final String className;
  const _AttendanceCorrelationTile({required this.classId, required this.className});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(classStudentsProvider(classId));
    // Placeholder: In a real implementation, fetch academic performance and attendance, then correlate.
    return studentsAsync.when(
      data: (students) {
        final attendanceRate = students.isEmpty ? 0 : 0.95; // Dummy value
        final avgPerformance = students.isEmpty ? 0 : 75; // Dummy value
        return ListTile(
          leading: const Icon(Icons.bar_chart, color: Colors.purple),
          title: Text(className),
          subtitle: Text('Attendance Rate: ${(attendanceRate * 100).toStringAsFixed(1)}% | Avg Performance: $avgPerformance'),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, st) => Text('Error: $e'),
    );
  }
}
