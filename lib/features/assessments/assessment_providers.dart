import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'assessment_service.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';

final assessmentServiceProvider = Provider<AssessmentService>((ref) {
  final db = ref.watch(databaseProvider);
  return AssessmentService(db);
});

final classAssessmentsProvider = FutureProvider.family<List<Assessment>, AssessmentQuery>((ref, query) async {
  return ref.watch(assessmentServiceProvider).getAssessments(query.classId, query.subjectId, query.term);
});

final gradingScaleProvider = FutureProvider.family<GradingScale?, AssessmentQuery>((ref, query) async {
  return ref.watch(assessmentServiceProvider).getGradingScale(query.classId, query.subjectId, query.term);
});

final assessmentGradesProvider = FutureProvider.family<List<StudentGrade>, int>((ref, assessmentId) async {
  return ref.watch(assessmentServiceProvider).getGradesForAssessment(assessmentId);
});

final studentTermResultsProvider = FutureProvider.family<List<TermResult>, int>((ref, studentId) async {
  return await (ref.watch(databaseProvider).select(ref.watch(databaseProvider).termResults)
        ..where((t) => t.studentId.equals(studentId)))
      .get();
});

class AssessmentQuery {
  final int classId;
  final int subjectId;
  final int term;

  AssessmentQuery({required this.classId, required this.subjectId, required this.term});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssessmentQuery &&
          runtimeType == other.runtimeType &&
          classId == other.classId &&
          subjectId == other.subjectId &&
          term == other.term;

  @override
  int get hashCode => classId.hashCode ^ subjectId.hashCode ^ term.hashCode;
}
