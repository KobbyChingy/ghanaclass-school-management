import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'exam_service.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';

final examServiceProvider = Provider<ExamService>((ref) {
  final db = ref.watch(databaseProvider);
  return ExamService(db);
});

final questionsProvider = FutureProvider.family<List<QuestionBankData>, int?>((ref, subjectId) {
  return ref.watch(examServiceProvider).getQuestions(subjectId: subjectId);
});

final savedExamsProvider = FutureProvider.family<List<ExamPaper>, int?>((ref, subjectId) {
  return ref.watch(examServiceProvider).getSavedExams(subjectId: subjectId);
});

final subSubjectsProvider = FutureProvider.family<List<String>, int>((ref, subjectId) {
  return ref.watch(examServiceProvider).getSubSubjects(subjectId);
});
