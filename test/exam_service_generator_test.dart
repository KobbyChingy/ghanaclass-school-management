import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/features/exams/exam_service.dart';

void main() {
  group('ExamService.generateExamSelection', () {
    late AppDatabase db;
    late ExamService service;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      service = ExamService(db);
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> insertTeacher() async {
      return db.into(db.users).insert(
            UsersCompanion.insert(
              fullName: 'Teacher One',
              email: 'teacher@example.com',
              passwordHash: 'hash',
              role: 'teacher',
            ),
          );
    }

    Future<int> insertSubject() async {
      return db.into(db.schoolSubjects).insert(
            SchoolSubjectsCompanion.insert(
              subjectName: 'Mathematics',
              subjectCode: 'MATH',
            ),
          );
    }

    Future<void> seedQuestions({
      required int subjectId,
      required int teacherId,
      required String difficulty,
      required int count,
      String type = 'objective',
      String? subSubject,
    }) async {
      final entries = List.generate(
        count,
        (i) => QuestionBankCompanion.insert(
          subjectId: subjectId,
          teacherId: teacherId,
          difficulty: difficulty,
          questionText: 'Q-$difficulty-$i',
          questionType: type,
          subSubject: subSubject == null ? const Value.absent() : Value(subSubject),
          options: type == 'objective' ? Value('["A","B","C","D"]') : const Value.absent(),
          correctAnswer: type == 'objective' ? const Value('A') : const Value.absent(),
          marks: const Value(1.0),
        ),
      );

      await db.batch((b) {
        b.insertAll(db.questionBank, entries);
      });
    }

    test('returns exact requested counts per difficulty', () async {
      final teacherId = await insertTeacher();
      final subjectId = await insertSubject();

      await seedQuestions(subjectId: subjectId, teacherId: teacherId, difficulty: 'easy', count: 5);
      await seedQuestions(subjectId: subjectId, teacherId: teacherId, difficulty: 'medium', count: 5);
      await seedQuestions(subjectId: subjectId, teacherId: teacherId, difficulty: 'hard', count: 5);

      final picked = await service.generateExamSelection(
        subjectId: subjectId,
        difficultyCounts: {'easy': 2, 'medium': 3, 'hard': 1},
        random: Random(1),
      );

      expect(picked, hasLength(6));
      expect(picked.where((q) => q.difficulty == 'easy'), hasLength(2));
      expect(picked.where((q) => q.difficulty == 'medium'), hasLength(3));
      expect(picked.where((q) => q.difficulty == 'hard'), hasLength(1));
    });

    test('throws when bank does not have enough questions', () async {
      final teacherId = await insertTeacher();
      final subjectId = await insertSubject();

      await seedQuestions(subjectId: subjectId, teacherId: teacherId, difficulty: 'easy', count: 1);

      expect(
        () => service.generateExamSelection(
          subjectId: subjectId,
          difficultyCounts: {'easy': 2},
          random: Random(1),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('supports subSubject filtering', () async {
      final teacherId = await insertTeacher();
      final subjectId = await insertSubject();

      await seedQuestions(subjectId: subjectId, teacherId: teacherId, difficulty: 'easy', count: 2, subSubject: 'Algebra');
      await seedQuestions(subjectId: subjectId, teacherId: teacherId, difficulty: 'easy', count: 2, subSubject: 'Geometry');

      final picked = await service.generateExamSelection(
        subjectId: subjectId,
        subSubject: 'Algebra',
        difficultyCounts: {'easy': 2},
        random: Random(1),
      );

      expect(picked, hasLength(2));
      expect(picked.every((q) => q.subSubject == 'Algebra'), isTrue);
    });
  });
}
