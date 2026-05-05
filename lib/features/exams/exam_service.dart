import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'dart:math';

class ExamService {
  final AppDatabase _database;

  ExamService(this._database);

  // --- Question Bank Operations ---

  Future<List<QuestionBankData>> getQuestions({
    int? subjectId,
    String? difficulty,
    String? type,
    String? subSubject,
  }) async {
    final query = _database.select(_database.questionBank);
    if (subjectId != null) query.where((q) => q.subjectId.equals(subjectId));
    if (difficulty != null) query.where((q) => q.difficulty.equals(difficulty));
    if (type != null) query.where((q) => q.questionType.equals(type));
    if (subSubject != null) query.where((q) => q.subSubject.equals(subSubject));
    return query.get();
  }

  Future<List<String>> getSubSubjects(int subjectId) async {
    final query = _database.selectOnly(_database.questionBank, distinct: true)
      ..addColumns([_database.questionBank.subSubject])
      ..where(_database.questionBank.subjectId.equals(subjectId));
    
    final results = await query.get();
    return results
      .map((r) => r.read(_database.questionBank.subSubject))
      .where((s) => s != null)
      .cast<String>()
      .toList();
  }

  Future<int> addQuestion(QuestionBankCompanion entry) async {
    return _database.into(_database.questionBank).insert(entry);
  }

  Future<void> bulkAddQuestions(List<QuestionBankCompanion> entries) async {
    await _database.batch((batch) {
      batch.insertAll(_database.questionBank, entries);
    });
  }

  Future<void> updateQuestion(QuestionBankCompanion entry) async {
    await _database.update(_database.questionBank).replace(entry);
  }

  Future<void> deleteQuestion(int id) async {
    await (_database.delete(_database.questionBank)..where((q) => q.id.equals(id))).go();
  }

  // --- Exam Generation Operations ---

  Future<List<QuestionBankData>> generateExamSelection({
    required int subjectId,
    required Map<String, int> difficultyCounts, // { 'easy': 10, 'medium': 5 }
    String? type,
    String? subSubject,
    Random? random,
  }) async {
    final sanitized = <String, int>{};
    for (final entry in difficultyCounts.entries) {
      final difficulty = entry.key;
      final count = entry.value;
      if (count < 0) {
        throw ArgumentError.value(count, 'difficultyCounts[$difficulty]', 'Must be >= 0');
      }
      if (count == 0) continue;
      sanitized[difficulty] = count;
    }

    if (sanitized.isEmpty) {
      return <QuestionBankData>[];
    }

    final allPossible = await getQuestions(subjectId: subjectId, type: type, subSubject: subSubject);
    final List<QuestionBankData> selected = [];

    final shortages = <String, ({int needed, int available})>{};

    for (final entry in sanitized.entries) {
      final difficulty = entry.key;
      final countNeeded = entry.value;
      final matching = allPossible.where((q) => q.difficulty == difficulty).toList();

      if (matching.length < countNeeded) {
        shortages[difficulty] = (needed: countNeeded, available: matching.length);
        continue;
      }

      matching.shuffle(random);
      selected.addAll(matching.take(countNeeded));
    }

    if (shortages.isNotEmpty) {
      final details = shortages.entries
          .map((e) => '${e.key}: need ${e.value.needed}, have ${e.value.available}')
          .join(', ');
      throw StateError('Not enough questions in bank to generate exam ($details).');
    }

    return selected;
  }

  Future<int> saveExamPaper(ExamPapersCompanion entry) async {
    return _database.into(_database.examPapers).insert(entry);
  }

  Future<List<ExamPaper>> getSavedExams({int? subjectId}) async {
    final query = _database.select(_database.examPapers);
    if (subjectId != null) query.where((e) => e.subjectId.equals(subjectId));
    return query.get();
  }

  Future<ExamPaper> getExamById(int id) async {
    return (_database.select(_database.examPapers)..where((e) => e.id.equals(id))).getSingle();
  }
}
