import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/features/academic/academic_providers.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'exam_providers.dart';
import 'question_editor_dialog.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/features/teachers/teacher_providers.dart';

class QuestionBankScreen extends ConsumerStatefulWidget {
  const QuestionBankScreen({super.key});

  @override
  ConsumerState<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends ConsumerState<QuestionBankScreen> {
  int? _selectedSubjectId;
  String _diffFilter = 'all';
  String _typeFilter = 'all';
  String? _subSubjectFilter;

  String? _normalizeType(String raw) {
    final v = raw.trim().toLowerCase();
    if (v.isEmpty) return null;
    if (v == 'objective' || v == 'obj' || v == 'mcq' || v == 'multiple choice' || v == 'multiple-choice') return 'objective';
    if (v == 'theory' || v == 'essay' || v == 'structured') return 'theory';
    return null;
  }

  String? _normalizeDifficulty(String raw) {
    final v = raw.trim().toLowerCase();
    if (v.isEmpty) return null;
    if (v == 'easy' || v == 'e' || v == '1') return 'easy';
    if (v == 'medium' || v == 'med' || v == 'm' || v == '2') return 'medium';
    if (v == 'hard' || v == 'h' || v == '3') return 'hard';
    return null;
  }

  List<String>? _parseOptionsToList(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // Prefer JSON array when provided.
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        final list = decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
        return list.isEmpty ? null : list;
      }
    } catch (_) {
      // fall back to delimiter-based parsing
    }

    final parts = trimmed
        .split(RegExp(r'[|;,]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts;
  }

  String? _normalizeCorrectAnswer(String? raw, List<String> options) {
    final v = raw?.trim();
    if (v == null || v.isEmpty) return null;

    // Accept A/B/C... (letter)
    final upper = v.toUpperCase();
    final letterMatch = RegExp(r'^[A-Z]$').firstMatch(upper);
    if (letterMatch != null) {
      final idx = upper.codeUnitAt(0) - 65;
      if (idx >= 0 && idx < options.length) return upper;
      return null;
    }

    // Accept 1-based index
    final asInt = int.tryParse(v);
    if (asInt != null) {
      final idx = asInt - 1;
      if (idx >= 0 && idx < options.length) {
        return String.fromCharCode(65 + idx);
      }
    }

    // Accept option text
    final optionIndex = options.indexWhere((o) => o.toLowerCase() == v.toLowerCase());
    if (optionIndex != -1) {
      return String.fromCharCode(65 + optionIndex);
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(subjectsProvider);
    final assignmentsAsync = ref.watch(teacherAssignmentsProvider);
    final isHeadAsync = ref.watch(isHeadOrClassTeacherProvider);

    final allowedSubjectIds = assignmentsAsync.maybeWhen(
      data: (assignments) => assignments.map((a) => a.subjectId).toSet(),
      orElse: () => null,
    );
    final effectiveSelectedSubjectId = (_selectedSubjectId != null && (allowedSubjectIds?.contains(_selectedSubjectId) ?? false))
        ? _selectedSubjectId
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Question Bank'),
        actions: [
          if (effectiveSelectedSubjectId != null) ...[
            ElevatedButton.icon(
              onPressed: () => _importCsv(context, effectiveSelectedSubjectId),
              icon: const Icon(LucideIcons.fileUp, size: 18),
              label: const Text('Bulk Upload'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => _showEditor(context, effectiveSelectedSubjectId),
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('Add Question'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.actionIndigo,
                foregroundColor: Colors.white,
              ),
            ),
          ],
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          // Sidebar: Subjects
          Container(
            width: 300,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border(right: BorderSide(color: AppTheme.border)),
            ),
            child: subjectsAsync.when(
              data: (subjects) => assignmentsAsync.when(
                data: (assignments) => isHeadAsync.when(
                  data: (isHeadOrClass) {
                    final assignedSubjectIds = assignments.map((a) => a.subjectId).toSet();
                    final filteredSubjects = subjects.where((s) => assignedSubjectIds.contains(s.id)).toList();

                    final selectedId = filteredSubjects.any((s) => s.id == _selectedSubjectId) ? _selectedSubjectId : null;

                    if (filteredSubjects.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'No assigned subjects. Ask the admin to assign you as a subject teacher.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textMuted),
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: filteredSubjects.length,
                      itemBuilder: (context, index) {
                        final subject = filteredSubjects[index];
                        final isSelected = selectedId == subject.id;
                        return ListTile(
                          selected: isSelected,
                          selectedTileColor: AppTheme.actionIndigo.withValues(alpha: 0.1),
                          leading: Icon(LucideIcons.book, color: isSelected ? AppTheme.actionIndigo : AppTheme.textMuted),
                          title: Text(subject.subjectName, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          onTap: () => setState(() {
                            _selectedSubjectId = subject.id;
                            _subSubjectFilter = null;
                          }),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => const Center(child: Text('Unable to load teacher assignments.')),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => const Center(child: Text('Unable to load teacher assignments.')),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),

          // Main Content: Questions
          Expanded(
            child: effectiveSelectedSubjectId == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.bookOpen, size: 64, color: AppTheme.textMuted),
                        SizedBox(height: 16),
                        Text('Select a subject to manage questions', style: TextStyle(color: AppTheme.textMuted, fontSize: 18)),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      _buildFilterBar(effectiveSelectedSubjectId),
                      Expanded(
                        child: _QuestionList(
                          subjectId: effectiveSelectedSubjectId,
                          diffFilter: _diffFilter,
                          typeFilter: _typeFilter,
                          subSubjectFilter: _subSubjectFilter,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _showEditor(BuildContext context, int subjectId, {QuestionBankData? question}) {
    showDialog(
      context: context,
      builder: (context) => QuestionEditorDialog(
        subjectId: subjectId,
        question: question,
      ),
    ).then((_) {
      ref.invalidate(questionsProvider(subjectId));
      ref.invalidate(subSubjectsProvider(subjectId));
    });
  }

  Widget _buildFilterBar(int subjectId) {
    final subSubjectsAsync = ref.watch(subSubjectsProvider(subjectId));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 12.0;
          const minFieldWidth = 220.0;
          const maxFieldWidth = 420.0;

          // Rough width estimate for the reset button so the dropdowns don't
          // get squeezed too hard on narrow windows.
          const resetEstimatedWidth = 120.0;

          final availableForFields =
              (constraints.maxWidth - resetEstimatedWidth - (spacing * 3));
          final computedFieldWidth = availableForFields / 3;
          final fieldWidth = computedFieldWidth
              .clamp(minFieldWidth, maxFieldWidth)
              .toDouble();

          Widget field(Widget child) => SizedBox(width: fieldWidth, child: child);

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              field(
                DropdownButtonFormField<String>(
                  initialValue: _diffFilter,
                  decoration: const InputDecoration(labelText: 'Difficulty', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Difficulties')),
                    DropdownMenuItem(value: 'easy', child: Text('Easy')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'hard', child: Text('Hard')),
                  ],
                  onChanged: (v) => setState(() => _diffFilter = v!),
                ),
              ),
              field(
                subSubjectsAsync.when(
                  data: (list) => DropdownButtonFormField<String?>(
                    initialValue: _subSubjectFilter,
                    decoration: const InputDecoration(labelText: 'Sub-Subject', isDense: true),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Sub-Subjects')),
                      ...list.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                    ],
                    onChanged: (v) => setState(() => _subSubjectFilter = v),
                  ),
                  loading: () => const SizedBox(
                    height: 44,
                    child: Center(child: LinearProgressIndicator()),
                  ),
                  error: (e, _) => const SizedBox(
                    height: 44,
                    child: Center(child: Icon(Icons.error)),
                  ),
                ),
              ),
              field(
                DropdownButtonFormField<String>(
                  initialValue: _typeFilter,
                  decoration: const InputDecoration(labelText: 'Type', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Types')),
                    DropdownMenuItem(value: 'objective', child: Text('Objective')),
                    DropdownMenuItem(value: 'theory', child: Text('Theory')),
                  ],
                  onChanged: (v) => setState(() => _typeFilter = v!),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _diffFilter = 'all';
                      _typeFilter = 'all';
                      _subSubjectFilter = null;
                    });
                  },
                  icon: const Icon(LucideIcons.rotateCcw, size: 16),
                  label: const Text('Reset'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _importCsv(BuildContext context, int subjectId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null) return;

    try {
      final pickedFile = result.files.single;
      final String input;

      if (pickedFile.bytes != null) {
        input = utf8.decode(pickedFile.bytes!);
      } else if (pickedFile.path != null) {
        input = await File(pickedFile.path!).readAsString();
      } else {
        throw 'Unable to read the selected CSV file.';
      }
      final List<List<dynamic>> rows = const CsvToListConverter().convert(input);

      if (rows.length < 2) {
        throw 'CSV file is empty or missing data.';
      }

      // Skip header row
      final dataRows = rows.skip(1).toList();
      final List<QuestionBankCompanion> entries = [];
      final List<String> errors = [];
      final teacherId = ref.read(currentUserProvider)!.id;

      for (var i = 0; i < dataRows.length; i++) {
        final row = dataRows[i];
        final rowNum = i + 2; // +1 for header, +1 for 1-based

        if (row.length < 5) {
          errors.add('Row $rowNum: expected >= 5 columns, got ${row.length}');
          continue;
        }

        final text = row[0].toString().trim();
        final type = _normalizeType(row[1].toString());
        final difficulty = _normalizeDifficulty(row[2].toString());
        final marksRaw = double.tryParse(row[3].toString());
        final marks = (marksRaw == null || marksRaw <= 0) ? 1.0 : marksRaw;
        final subSubject = row[4]?.toString().trim();
        final optionsRaw = row.length > 5 && row[5] != null ? row[5].toString() : null;
        final answerRaw = row.length > 6 && row[6] != null ? row[6].toString() : null;

        if (text.isEmpty) {
          errors.add('Row $rowNum: question text is empty');
          continue;
        }
        if (type == null) {
          errors.add('Row $rowNum: invalid question type (use objective/theory)');
          continue;
        }
        if (difficulty == null) {
          errors.add('Row $rowNum: invalid difficulty (use easy/medium/hard)');
          continue;
        }

        String? optionsJson;
        String? correctAnswer;

        if (type == 'objective') {
          final optionsList = optionsRaw == null ? null : _parseOptionsToList(optionsRaw);
          if (optionsList == null || optionsList.length < 2) {
            errors.add('Row $rowNum: objective question requires >= 2 options');
            continue;
          }
          correctAnswer = _normalizeCorrectAnswer(answerRaw, optionsList);
          if (correctAnswer == null) {
            errors.add('Row $rowNum: objective question requires valid correctAnswer (A/B/C..., 1/2/3..., or option text)');
            continue;
          }
          optionsJson = jsonEncode(optionsList);
        } else {
          // Theory: model answer optional
          correctAnswer = (answerRaw?.trim().isEmpty ?? true) ? null : answerRaw!.trim();
        }

        entries.add(
          QuestionBankCompanion(
            subjectId: drift.Value(subjectId),
            questionText: drift.Value(text),
            questionType: drift.Value(type),
            difficulty: drift.Value(difficulty),
            marks: drift.Value(marks),
            subSubject: drift.Value((subSubject == null || subSubject.isEmpty) ? null : subSubject),
            options: drift.Value(optionsJson),
            correctAnswer: drift.Value(correctAnswer),
            teacherId: drift.Value(teacherId),
          ),
        );
      }

      if (entries.isEmpty) {
        throw errors.isEmpty ? 'No valid rows found in CSV.' : 'No valid rows found. First error: ${errors.first}';
      }

      await ref.read(examServiceProvider).bulkAddQuestions(entries);
      
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errors.isEmpty
                ? 'Successfully imported ${entries.length} questions'
                : 'Imported ${entries.length} questions (skipped ${errors.length}).',
          ),
        ),
      );
      ref.invalidate(questionsProvider(subjectId));
      ref.invalidate(subSubjectsProvider(subjectId));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importing CSV: $e'), backgroundColor: AppTheme.error),
      );
    }
  }
}

class _QuestionList extends ConsumerWidget {
  final int subjectId;
  final String diffFilter;
  final String typeFilter;
  final String? subSubjectFilter;

  const _QuestionList({
    required this.subjectId,
    required this.diffFilter,
    required this.typeFilter,
    this.subSubjectFilter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questionsAsync = ref.watch(questionsProvider(subjectId));

    return questionsAsync.when(
      data: (allQuestions) {
        final questions = allQuestions.where((q) {
          if (diffFilter != 'all' && q.difficulty != diffFilter) return false;
          if (typeFilter != 'all' && q.questionType != typeFilter) return false;
          if (subSubjectFilter != null && q.subSubject != subSubjectFilter) return false;
          return true;
        }).toList();

        if (questions.isEmpty) {
          return const Center(child: Text('No questions matching current filters.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: questions.length,
          itemBuilder: (context, index) {
            final q = questions[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ExpansionTile(
                leading: _buildTypeBadge(q.questionType),
                title: Text(q.questionText, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text('Difficulty: ${q.difficulty.toUpperCase()} | Marks: ${q.marks}', style: const TextStyle(fontSize: 12)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.edit2, size: 18),
                      onPressed: () => _showEditor(context, ref, q),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.trash2, size: 18, color: AppTheme.error),
                      onPressed: () => _confirmDelete(context, ref, q),
                    ),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (q.subSubject != null) ...[
                          Text('Sub-Subject: ${q.subSubject}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                        ],
                        Text('Question:', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                        Text(q.questionText),
                        const SizedBox(height: 16),
                        if (q.options != null) ...[
                          Text('Options:', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                          ..._buildOptions(q.options!),
                          const SizedBox(height: 16),
                        ],
                        if (q.correctAnswer != null) ...[
                          Text('Correct Answer:', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                          Text(q.correctAnswer!, style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildTypeBadge(String type) {
    final isObj = type == 'objective';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isObj ? AppTheme.actionIndigo : Colors.orange).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        type.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isObj ? AppTheme.actionIndigo : Colors.orange),
      ),
    );
  }

  List<Widget> _buildOptions(String optionsJson) {
    try {
      final List<dynamic> options = jsonDecode(optionsJson);
      return options.map((o) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text('• $o'),
      )).toList();
    } catch (e) {
      return [const Text('Error parsing options')];
    }
  }

  void _showEditor(BuildContext context, WidgetRef ref, QuestionBankData question) {
    showDialog(
      context: context,
      builder: (context) => QuestionEditorDialog(
        subjectId: subjectId,
        question: question,
      ),
    ).then((_) => ref.refresh(questionsProvider(subjectId)));
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, QuestionBankData question) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Question'),
        content: const Text('Are you sure you want to delete this question? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await ref.read(examServiceProvider).deleteQuestion(question.id);
              if (context.mounted) {
                Navigator.pop(context);
                ref.invalidate(questionsProvider(subjectId));
              }
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}
