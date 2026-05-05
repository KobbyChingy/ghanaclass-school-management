import 'package:drift/drift.dart' as drift;

import 'package:ghanaclass_school_management/core/database/app_database.dart';

class LessonNoteWithRows {
  final LessonNote note;
  final List<LessonNoteRow> rows;

  const LessonNoteWithRows({
    required this.note,
    required this.rows,
  });
}

class LessonNotesService {
  final AppDatabase _db;

  LessonNotesService(this._db);

  Future<List<LessonNote>> listForTeacher(int userId) {
    return (_db.select(_db.lessonNotes)
          ..where((t) => t.createdByUserId.equals(userId))
          ..orderBy([
            (t) => drift.OrderingTerm(expression: t.updatedAt, mode: drift.OrderingMode.desc),
            (t) => drift.OrderingTerm(expression: t.id, mode: drift.OrderingMode.desc),
          ]))
        .get();
  }

  Future<LessonNoteWithRows?> getNoteWithRows(int noteId) async {
    final note = await (_db.select(_db.lessonNotes)..where((t) => t.id.equals(noteId))).getSingleOrNull();
    if (note == null) return null;
    final rows = await (_db.select(_db.lessonNoteRows)
          ..where((t) => t.noteId.equals(noteId))
          ..orderBy([(t) => drift.OrderingTerm(expression: t.rowIndex)]))
        .get();
    return LessonNoteWithRows(note: note, rows: rows);
  }

  Future<int> createNote({
    required int userId,
    required String title,
    required int term,
    required int academicYear,
    int? classId,
    int? subjectId,
    int defaultWeekRows = 14,
  }) async {
    return _db.transaction(() async {
      final noteId = await _db.into(_db.lessonNotes).insert(
            LessonNotesCompanion.insert(
              createdByUserId: userId,
              title: title,
              term: term,
              academicYear: academicYear,
              classId: drift.Value(classId),
              subjectId: drift.Value(subjectId),
            ),
          );

      if (defaultWeekRows > 0) {
        await _db.batch((b) {
          for (var i = 0; i < defaultWeekRows; i++) {
            b.insert(
              _db.lessonNoteRows,
              LessonNoteRowsCompanion.insert(
                noteId: noteId,
                rowIndex: i,
                week: drift.Value(i + 1),
              ),
            );
          }
        });
      }

      return noteId;
    });
  }

  Future<void> updateNote({
    required int noteId,
    required String title,
    required int term,
    required int academicYear,
    int? classId,
    int? subjectId,
  }) async {
    await (_db.update(_db.lessonNotes)..where((t) => t.id.equals(noteId))).write(
      LessonNotesCompanion(
        title: drift.Value(title),
        term: drift.Value(term),
        academicYear: drift.Value(academicYear),
        classId: drift.Value(classId),
        subjectId: drift.Value(subjectId),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  Future<void> replaceRows({
    required int noteId,
    required List<LessonNoteRowDraft> rows,
  }) async {
    await _db.transaction(() async {
      await (_db.delete(_db.lessonNoteRows)..where((t) => t.noteId.equals(noteId))).go();

      await _db.batch((b) {
        for (var i = 0; i < rows.length; i++) {
          final r = rows[i];
          b.insert(
            _db.lessonNoteRows,
            LessonNoteRowsCompanion.insert(
              noteId: noteId,
              rowIndex: i,
              week: drift.Value(r.week),
              strand: drift.Value(r.strand?.trim().isEmpty == true ? null : r.strand?.trim()),
              subStrand: drift.Value(r.subStrand?.trim().isEmpty == true ? null : r.subStrand?.trim()),
              contentStandards: drift.Value(r.contentStandards?.trim().isEmpty == true ? null : r.contentStandards?.trim()),
              indicators: drift.Value(r.indicators?.trim().isEmpty == true ? null : r.indicators?.trim()),
              resources: drift.Value(r.resources?.trim().isEmpty == true ? null : r.resources?.trim()),
              updatedAt: drift.Value(DateTime.now()),
            ),
          );
        }
      });
    });
  }

  Future<void> deleteNote(int noteId) async {
    await (_db.delete(_db.lessonNotes)..where((t) => t.id.equals(noteId))).go();
  }
}

class LessonNoteRowDraft {
  int? week;
  String? strand;
  String? subStrand;
  String? contentStandards;
  String? indicators;
  String? resources;

  LessonNoteRowDraft({
    this.week,
    this.strand,
    this.subStrand,
    this.contentStandards,
    this.indicators,
    this.resources,
  });

  factory LessonNoteRowDraft.fromRow(LessonNoteRow row) {
    return LessonNoteRowDraft(
      week: row.week,
      strand: row.strand,
      subStrand: row.subStrand,
      contentStandards: row.contentStandards,
      indicators: row.indicators,
      resources: row.resources,
    );
  }
}
