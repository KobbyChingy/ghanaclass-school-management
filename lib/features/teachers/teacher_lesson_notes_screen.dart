import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:open_file/open_file.dart';

import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart' show currentUserProvider;
import 'package:ghanaclass_school_management/features/teachers/lesson_notes_providers.dart';

class TeacherLessonNotesScreen extends ConsumerWidget {
  const TeacherLessonNotesScreen({super.key});

  static const _headers = <String>[
    'Week',
    'Strand',
    'Sub-Strand',
    'Content Standards',
    'Indicator',
    'Resources',
  ];

  Future<void> _downloadTemplate(BuildContext context) async {
    final csv = const ListToCsvConverter().convert([
      _headers,
    ]);

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save lesson notes template',
      fileName: 'lesson_notes_template.csv',
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (path == null) return;

    final normalized = path.endsWith('.csv') ? path : '$path.csv';
    await File(normalized).writeAsString(csv);
    await OpenFile.open(normalized);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Template saved.')),
    );
  }

  Future<void> _createNew(BuildContext context, WidgetRef ref) async {
    try {
      final now = DateTime.now();
      final service = ref.read(lessonNotesServiceProvider);

      final id = await service.createNote(
        userId: ref.read(currentUserProvider)!.id,
        title: 'Termly Scheme of Learning',
        term: 1,
        academicYear: now.year,
        defaultWeekRows: 14,
      );

      ref.invalidate(teacherLessonNotesProvider);
      if (!context.mounted) return;
      context.go('/teacher/lesson-notes/$id');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(teacherLessonNotesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lesson Notes'),
        actions: [
          TextButton.icon(
            onPressed: () => _downloadTemplate(context),
            icon: const Icon(LucideIcons.download, size: 18),
            label: const Text('Download Template'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _createNew(context, ref),
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text('New'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppTheme.surfaceMuted,
              border: Border.all(color: AppTheme.border),
            ),
            child: const Row(
              children: [
                Icon(LucideIcons.bookOpen, size: 18, color: AppTheme.textMuted),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Create your Termly Scheme of Learning, import a template CSV, or download a CSV to share/print.',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          notesAsync.when(
            data: (notes) {
              if (notes.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                    color: Colors.white,
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.inbox, size: 36, color: AppTheme.textMuted),
                      SizedBox(height: 8),
                      Text('No lesson notes yet', style: TextStyle(fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('Click New to create one.', style: TextStyle(color: AppTheme.textMuted)),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  for (final n in notes)
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppTheme.border),
                      ),
                      child: ListTile(
                        title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('Term ${n.term} • ${n.academicYear}'),
                        trailing: const Icon(LucideIcons.chevronRight),
                        onTap: () => context.go('/teacher/lesson-notes/${n.id}'),
                      ),
                    ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Text('Error loading lesson notes: $e'),
            ),
          ),
        ],
      ),
    );
  }
}
