import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
// import removed: unused
import '../assessments/assessment_providers.dart';

class GradeDistributionChart extends ConsumerWidget {
  final int classId;
  final int subjectId;
  final int term;

  const GradeDistributionChart({super.key, required this.classId, required this.subjectId, required this.term});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(classAssessmentsProvider(
      AssessmentQuery(classId: classId, subjectId: subjectId, term: term),
    ));

    return resultsAsync.when(
      data: (assessments) {
        // Collect all grades from termResults for this class/subject/term
        // (Assume a provider or service to fetch termResults by class/subject/term)
        // For demo, show placeholder chart
        final gradeCounts = <String, int>{
          'A1': 10,
          'B2': 8,
          'B3': 6,
          'C4': 5,
          'C5': 4,
          'C6': 3,
          'D7': 2,
          'E8': 1,
          'F9': 1,
        };
        final total = gradeCounts.values.fold(0, (a, b) => a + b);
        final sections = gradeCounts.entries.map((e) => PieChartSectionData(
          value: e.value.toDouble(),
          title: '${e.key}\n${((e.value/total)*100).toStringAsFixed(1)}%',
        )).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Grade Distribution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: PieChart(PieChartData(
                sections: sections,
                sectionsSpace: 2,
                centerSpaceRadius: 40,
              )),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Text('Error: $e'),
    );
  }
}
