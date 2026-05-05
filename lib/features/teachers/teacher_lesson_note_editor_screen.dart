import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';

import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/features/academic/academic_providers.dart';
import 'package:ghanaclass_school_management/features/teachers/lesson_notes_pdf_service.dart';
import 'package:ghanaclass_school_management/features/teachers/lesson_notes_providers.dart';
import 'package:ghanaclass_school_management/features/teachers/lesson_notes_service.dart';
import 'package:ghanaclass_school_management/features/teachers/teacher_providers.dart';
import 'package:ghanaclass_school_management/features/teachers/teacher_service.dart';
import 'package:ghanaclass_school_management/shared/printing/pdf_preview_screen.dart';

class TeacherLessonNoteEditorScreen extends ConsumerStatefulWidget {
  final int noteId;

  const TeacherLessonNoteEditorScreen({super.key, required this.noteId});

  @override
  ConsumerState<TeacherLessonNoteEditorScreen> createState() => _TeacherLessonNoteEditorScreenState();
}

class _TeacherLessonNoteEditorScreenState extends ConsumerState<TeacherLessonNoteEditorScreen> {
  final _titleController = TextEditingController();
  int _term = 1;
  int _year = DateTime.now().year;
  int? _classId;
  int? _subjectId;

  int? _loadedNoteId;
  bool _saving = false;

  final List<_RowControllers> _rows = [];

  final _pdfService = LessonNotesPdfService();

  @override
  void dispose() {
    _titleController.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _hydrateFromDb(LessonNoteWithRows data) {
    if (_loadedNoteId == widget.noteId) return;
    _loadedNoteId = widget.noteId;

    _titleController.text = data.note.title;
    _term = data.note.term;
    _year = data.note.academicYear;
    _classId = data.note.classId;
    _subjectId = data.note.subjectId;

    _rows.clear();
    for (final r in data.rows) {
      _rows.add(_RowControllers.fromDraft(LessonNoteRowDraft.fromRow(r)));
    }

    if (_rows.isEmpty) {
      for (var i = 0; i < 14; i++) {
        _rows.add(_RowControllers.fromDraft(LessonNoteRowDraft(week: i + 1)));
      }
    }
  }

  List<LessonNoteRowDraft> _collectDrafts() {
    int? parseWeek(String v) {
      final s = v.trim();
      if (s.isEmpty) return null;
      return int.tryParse(s);
    }

    return _rows
        .map(
          (r) => LessonNoteRowDraft(
            week: parseWeek(r.week.text),
            strand: r.strand.text,
            subStrand: r.subStrand.text,
            contentStandards: r.contentStandards.text,
            indicators: r.indicators.text,
            resources: r.resources.text,
          ),
        )
        .toList(growable: false);
  }

  Future<void> _save() async {
    if (_saving) return;

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final service = ref.read(lessonNotesServiceProvider);
      await service.updateNote(
        noteId: widget.noteId,
        title: title,
        term: _term,
        academicYear: _year,
        classId: _classId,
        subjectId: _subjectId,
      );

      await service.replaceRows(noteId: widget.noteId, rows: _collectDrafts());

      ref.invalidate(teacherLessonNotesProvider);
      ref.invalidate(lessonNoteDetailProvider(widget.noteId));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lesson note saved.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportCsv({required bool templateOnly}) async {
    final headers = const <String>[
      'Week',
      'Strand',
      'Sub-Strand',
      'Content Standards',
      'Indicator',
      'Resources',
    ];

    final rows = <List<dynamic>>[headers];
    if (!templateOnly) {
      for (final r in _collectDrafts()) {
        rows.add([
          r.week?.toString() ?? '',
          r.strand ?? '',
          r.subStrand ?? '',
          r.contentStandards ?? '',
          r.indicators ?? '',
          r.resources ?? '',
        ]);
      }
    }

    final csv = const ListToCsvConverter().convert(rows);

    final defaultName = templateOnly
        ? 'lesson_notes_template.csv'
      : 'lesson_notes_${widget.noteId}_term${_term}_$_year.csv';

    final targetPath = await FilePicker.platform.saveFile(
      dialogTitle: templateOnly ? 'Save template CSV' : 'Export lesson notes CSV',
      fileName: defaultName,
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (targetPath == null) return;

    final normalized = targetPath.endsWith('.csv') ? targetPath : '$targetPath.csv';
    await File(normalized).writeAsString(csv);
    await OpenFile.open(normalized);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(templateOnly ? 'Template saved.' : 'Exported.')),
    );
  }

  Future<void> _importCsv() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import lesson notes CSV',
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.single.bytes;
    final path = result.files.single.path;

    String content;
    if (bytes != null) {
      content = String.fromCharCodes(bytes);
    } else if (path != null) {
      content = await File(path).readAsString();
    } else {
      return;
    }

    final parsed = const CsvToListConverter(shouldParseNumbers: false, eol: '\n').convert(content);
    if (parsed.isEmpty) return;

    final headerRow = parsed.first.map((e) => e.toString().trim().toLowerCase()).toList();
    int idx(String name) {
      final i = headerRow.indexOf(name.toLowerCase());
      return i;
    }

    final weekI = idx('week');
    final strandI = idx('strand');
    final subStrandI = headerRow.indexWhere((h) => h == 'sub-strand' || h == 'substrand' || h == 'sub strand');
    final standardsI = headerRow.indexWhere((h) => h == 'content standards' || h == 'contentstandards');
    final indicatorI = headerRow.indexWhere((h) => h == 'indicator' || h == 'indicators');
    final resourcesI = idx('resources');

    if (weekI < 0 && strandI < 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV headers not recognized.'), backgroundColor: Colors.red),
      );
      return;
    }

    int? parseWeek(dynamic v) {
      final s = v?.toString().trim() ?? '';
      if (s.isEmpty) return null;
      return int.tryParse(s);
    }

    final imported = <LessonNoteRowDraft>[];
    for (var i = 1; i < parsed.length; i++) {
      final row = parsed[i];
      if (row.isEmpty) continue;

      String readAt(int index) {
        if (index < 0 || index >= row.length) return '';
        return row[index]?.toString() ?? '';
      }

      final draft = LessonNoteRowDraft(
        week: weekI >= 0 ? parseWeek(row[weekI]) : null,
        strand: strandI >= 0 ? readAt(strandI) : '',
        subStrand: subStrandI >= 0 ? readAt(subStrandI) : '',
        contentStandards: standardsI >= 0 ? readAt(standardsI) : '',
        indicators: indicatorI >= 0 ? readAt(indicatorI) : '',
        resources: resourcesI >= 0 ? readAt(resourcesI) : '',
      );

      final isEmpty = (draft.week == null) &&
          (draft.strand?.trim().isEmpty ?? true) &&
          (draft.subStrand?.trim().isEmpty ?? true) &&
          (draft.contentStandards?.trim().isEmpty ?? true) &&
          (draft.indicators?.trim().isEmpty ?? true) &&
          (draft.resources?.trim().isEmpty ?? true);
      if (isEmpty) continue;

      imported.add(draft);
    }

    if (imported.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No rows found to import.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      for (final r in _rows) {
        r.dispose();
      }
      _rows
        ..clear()
        ..addAll(imported.map(_RowControllers.fromDraft));
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Imported ${imported.length} rows.')),
    );
  }

  Future<void> _deleteNote() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete lesson note?'),
        content: const Text('This will permanently remove this lesson note and its rows.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await ref.read(lessonNotesServiceProvider).deleteNote(widget.noteId);
      ref.invalidate(teacherLessonNotesProvider);
      if (!mounted) return;
      context.go('/teacher/lesson-notes');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deleted.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
    }
  }

  String? _findClassName(List<SchoolClassesData> classes) {
    final id = _classId;
    if (id == null) return null;
    for (final c in classes) {
      if (c.id == id) return c.className;
    }
    return null;
  }

  String? _findSubjectName(List<SchoolSubject> subjects) {
    final id = _subjectId;
    if (id == null) return null;
    for (final s in subjects) {
      if (s.id == id) return s.subjectName;
    }
    return null;
  }

  Future<Uint8List> _buildPdfBytes(PdfPageFormat format, {String? className, String? subjectName}) {
    return _pdfService.buildLessonNotesPdf(
      title: _titleController.text.trim(),
      term: _term,
      academicYear: _year,
      className: className,
      subjectName: subjectName,
      rows: _collectDrafts(),
      pageFormat: format,
    );
  }

  Future<void> _previewPdf({String? className, String? subjectName}) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required before generating PDF.'), backgroundColor: Colors.red),
      );
      return;
    }

    final fileName = 'lesson_notes_${widget.noteId}_term${_term}_$_year.pdf';

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(
          title: 'Lesson Notes PDF',
          subtitle: 'Term $_term · Academic Year $_year',
          pdfFileName: fileName,
          canChangeOrientation: true,
          canChangePageFormat: true,
          buildPdf: (format) => _buildPdfBytes(format, className: className, subjectName: subjectName),
        ),
      ),
    );
  }

  Future<void> _exportPdf({String? className, String? subjectName}) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required before exporting PDF.'), backgroundColor: Colors.red),
      );
      return;
    }

    final defaultName = 'lesson_notes_${widget.noteId}_term${_term}_$_year.pdf';
    final targetPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save lesson notes PDF',
      fileName: defaultName,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (targetPath == null) return;

    final normalized = targetPath.endsWith('.pdf') ? targetPath : '$targetPath.pdf';
    final bytes = await _buildPdfBytes(
      PdfPageFormat.a4.landscape,
      className: className,
      subjectName: subjectName,
    );
    await File(normalized).writeAsBytes(bytes);
    await OpenFile.open(normalized);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF saved.')),
    );
  }

  void _addRow() {
    setState(() {
      _rows.add(_RowControllers.fromDraft(LessonNoteRowDraft()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(lessonNoteDetailProvider(widget.noteId));
    final classesAsync = ref.watch(classesProvider);
    final subjectsAsync = ref.watch(subjectsProvider);
    final assignmentsAsync = ref.watch(teacherAssignmentsProvider);
    final headClassIdAsync = ref.watch(headOrClassTeacherClassIdProvider);

    final className = classesAsync.maybeWhen(data: _findClassName, orElse: () => null);
    final subjectName = subjectsAsync.maybeWhen(data: _findSubjectName, orElse: () => null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lesson Notes'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _importCsv,
            icon: const Icon(LucideIcons.upload, size: 18),
            label: const Text('Import CSV'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _saving ? null : () => _exportCsv(templateOnly: false),
            icon: const Icon(LucideIcons.download, size: 18),
            label: const Text('Export CSV'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _saving ? null : () => _exportCsv(templateOnly: true),
            icon: const Icon(LucideIcons.fileDown, size: 18),
            label: const Text('Template'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _saving ? null : () => _previewPdf(className: className, subjectName: subjectName),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const Text('PDF'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _saving ? null : () => _exportPdf(className: className, subjectName: subjectName),
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Save PDF'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _saving ? null : _addRow,
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text('Add Row'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(LucideIcons.save, size: 18),
            label: const Text('Save'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: detailAsync.when(
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Lesson note not found.'));
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _hydrateFromDb(data);
          });

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _metaCard(
                context,
                classesAsync: classesAsync,
                subjectsAsync: subjectsAsync,
                assignmentsAsync: assignmentsAsync,
                headClassIdAsync: headClassIdAsync,
              ),
              const SizedBox(height: 16),
              _tableCard(context),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _saving ? null : _deleteNote,
                  icon: const Icon(LucideIcons.trash2, color: Colors.red),
                  label: const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _metaCard(
    BuildContext context, {
    required AsyncValue<List<SchoolClassesData>> classesAsync,
    required AsyncValue<List<SchoolSubject>> subjectsAsync,
    required AsyncValue<List<TeacherClassSubjectAccess>> assignmentsAsync,
    required AsyncValue<int?> headClassIdAsync,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Details', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title',
              prefixIcon: Icon(LucideIcons.type),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: ValueKey('term-$_term'),
                  initialValue: _term,
                  decoration: const InputDecoration(
                    labelText: 'Term',
                    prefixIcon: Icon(LucideIcons.calendar),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Term 1')),
                    DropdownMenuItem(value: 2, child: Text('Term 2')),
                    DropdownMenuItem(value: 3, child: Text('Term 3')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _term = v);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  key: ValueKey('year-$_year'),
                  initialValue: _year.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Academic Year',
                    prefixIcon: Icon(LucideIcons.graduationCap),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onFieldSubmitted: (v) {
                    final parsed = int.tryParse(v.trim());
                    if (parsed == null) return;
                    setState(() => _year = parsed);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          assignmentsAsync.when(
            data: (assignments) {
              return headClassIdAsync.when(
                data: (headClassId) {
                  return classesAsync.when(
                    data: (classes) {
                      final allowedClassIds = <int>{...assignments.map((a) => a.classId)};
                      if (headClassId != null) allowedClassIds.add(headClassId);

                      final filteredClasses = classes.where((c) => allowedClassIds.contains(c.id)).toList()
                        ..sort((a, b) => a.className.toLowerCase().compareTo(b.className.toLowerCase()));

                      if (_classId != null && !allowedClassIds.contains(_classId)) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          setState(() {
                            _classId = null;
                            _subjectId = null;
                          });
                        });
                      }

                      return Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int?>(
                              key: ValueKey('class-$_classId'),
                              initialValue: _classId,
                              decoration: const InputDecoration(
                                labelText: 'Class (optional)',
                                prefixIcon: Icon(LucideIcons.school),
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem<int?>(value: null, child: Text('Not selected')),
                                ...filteredClasses.map(
                                  (c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.className)),
                                ),
                              ],
                              onChanged: (v) {
                                setState(() {
                                  _classId = v;
                                  _subjectId = null;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: subjectsAsync.when(
                              data: (subjects) {
                                final allowedSubjectIds = _classId == null
                                    ? assignments.map((a) => a.subjectId).toSet()
                                    : assignments.where((a) => a.classId == _classId).map((a) => a.subjectId).toSet();

                                final filteredSubjects = subjects.where((s) => allowedSubjectIds.contains(s.id)).toList()
                                  ..sort((a, b) => a.subjectName.toLowerCase().compareTo(b.subjectName.toLowerCase()));

                                final effectiveSubjectId = filteredSubjects.any((s) => s.id == _subjectId) ? _subjectId : null;
                                if (effectiveSubjectId != _subjectId) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (!mounted) return;
                                    setState(() => _subjectId = effectiveSubjectId);
                                  });
                                }

                                return DropdownButtonFormField<int?>(
                                  key: ValueKey('subject-$effectiveSubjectId'),
                                  initialValue: effectiveSubjectId,
                                  decoration: const InputDecoration(
                                    labelText: 'Subject (optional)',
                                    prefixIcon: Icon(LucideIcons.bookOpen),
                                    border: OutlineInputBorder(),
                                  ),
                                  items: [
                                    const DropdownMenuItem<int?>(value: null, child: Text('Not selected')),
                                    ...filteredSubjects.map(
                                      (s) => DropdownMenuItem<int?>(value: s.id, child: Text(s.subjectName)),
                                    ),
                                  ],
                                  onChanged: (v) => setState(() => _subjectId = v),
                                );
                              },
                              loading: () => const SizedBox(height: 56, child: Center(child: CircularProgressIndicator())),
                              error: (e, _) => Text('Error loading subjects: $e'),
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const SizedBox(height: 56, child: Center(child: CircularProgressIndicator())),
                    error: (e, _) => Text('Error loading classes: $e'),
                  );
                },
                loading: () => const SizedBox(height: 56, child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Text('Error loading teacher access: $e'),
              );
            },
            loading: () => const SizedBox(height: 56, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('Error loading teacher access: $e'),
          ),
        ],
      ),
    );
  }

  Widget _tableCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Termly Scheme of Learning', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Week')),
                DataColumn(label: Text('Strand')),
                DataColumn(label: Text('Sub-Strand')),
                DataColumn(label: Text('Content Standards')),
                DataColumn(label: Text('Indicator')),
                DataColumn(label: Text('Resources')),
                DataColumn(label: Text('')),
              ],
              rows: [
                for (var i = 0; i < _rows.length; i++) _buildDataRow(i),
              ],
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildDataRow(int index) {
    final r = _rows[index];

    Widget cellField(TextEditingController c, {double width = 220, int maxLines = 3}) {
      return SizedBox(
        width: width,
        child: TextField(
          controller: c,
          minLines: 1,
          maxLines: maxLines,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          ),
        ),
      );
    }

    return DataRow(
      cells: [
        DataCell(SizedBox(
          width: 80,
          child: TextField(
            controller: r.week,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            ),
          ),
        )),
        DataCell(cellField(r.strand, width: 220)),
        DataCell(cellField(r.subStrand, width: 220)),
        DataCell(cellField(r.contentStandards, width: 260)),
        DataCell(cellField(r.indicators, width: 240)),
        DataCell(cellField(r.resources, width: 220)),
        DataCell(
          IconButton(
            tooltip: 'Remove row',
            onPressed: _saving
                ? null
                : () {
                    setState(() {
                      final removed = _rows.removeAt(index);
                      removed.dispose();
                    });
                  },
            icon: const Icon(LucideIcons.x, color: Colors.red),
          ),
        ),
      ],
    );
  }
}

class _RowControllers {
  final TextEditingController week;
  final TextEditingController strand;
  final TextEditingController subStrand;
  final TextEditingController contentStandards;
  final TextEditingController indicators;
  final TextEditingController resources;

  _RowControllers({
    required this.week,
    required this.strand,
    required this.subStrand,
    required this.contentStandards,
    required this.indicators,
    required this.resources,
  });

  factory _RowControllers.fromDraft(LessonNoteRowDraft d) {
    return _RowControllers(
      week: TextEditingController(text: d.week?.toString() ?? ''),
      strand: TextEditingController(text: d.strand ?? ''),
      subStrand: TextEditingController(text: d.subStrand ?? ''),
      contentStandards: TextEditingController(text: d.contentStandards ?? ''),
      indicators: TextEditingController(text: d.indicators ?? ''),
      resources: TextEditingController(text: d.resources ?? ''),
    );
  }

  void dispose() {
    week.dispose();
    strand.dispose();
    subStrand.dispose();
    contentStandards.dispose();
    indicators.dispose();
    resources.dispose();
  }
}
