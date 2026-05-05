import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghanaclass_school_management/core/providers/auth_providers.dart' show currentUserProvider, databaseProvider;
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';

import 'lesson_notes_service.dart';

final lessonNotesServiceProvider = Provider<LessonNotesService>((ref) {
  final db = ref.watch(databaseProvider);
  return LessonNotesService(db);
});

final teacherLessonNotesProvider = FutureProvider<List<LessonNote>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const <LessonNote>[];
  if (user.role != UserRole.teacher.name) return const <LessonNote>[];

  final service = ref.watch(lessonNotesServiceProvider);
  return service.listForTeacher(user.id);
});

final lessonNoteDetailProvider = FutureProvider.family<LessonNoteWithRows?, int>((ref, noteId) async {
  final service = ref.watch(lessonNotesServiceProvider);
  return service.getNoteWithRows(noteId);
});
