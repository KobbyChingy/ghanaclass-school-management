import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'assessment_providers.dart';
import 'package:ghanaclass_school_management/features/attendance/attendance_providers.dart';
import 'package:drift/drift.dart' as drift;

class ScoreEntryScreen extends ConsumerStatefulWidget {
  final Assessment assessment;

  const ScoreEntryScreen({super.key, required this.assessment});

  @override
  ConsumerState<ScoreEntryScreen> createState() => _ScoreEntryScreenState();
}

class _ScoreEntryScreenState extends ConsumerState<ScoreEntryScreen> {
  final Map<int, TextEditingController> _scoreControllers = {};
  final Map<int, TextEditingController> _remarkControllers = {};
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void dispose() {
    for (var c in _scoreControllers.values) {
      c.dispose();
    }
    for (var c in _remarkControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(classStudentsProvider(widget.assessment.classId));
    final gradesAsync = ref.watch(assessmentGradesProvider(widget.assessment.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('Score Entry: ${widget.assessment.title}'),
        actions: [
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveGrades,
            icon: _isSaving 
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(LucideIcons.save, size: 18),
            label: const Text('Save Scores'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
      body: studentsAsync.when(
        data: (students) {
          if (students.isEmpty) return const Center(child: Text('No students in this class.'));

          return gradesAsync.when(
            data: (grades) {
              if (!_initialized) {
                for (var student in students) {
                  final existingGrade = grades.where((g) => g.studentId == student.id).firstOrNull;
                  _scoreControllers[student.id] = TextEditingController(
                    text: existingGrade?.score.toStringAsFixed(1) ?? '',
                  );
                  _remarkControllers[student.id] = TextEditingController(
                    text: existingGrade?.remarks ?? '',
                  );
                }
                _initialized = true;
              }

              return Column(
                children: [
                   // Instructions
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: AppTheme.surfaceMuted,
                    child: Row(
                      children: [
                        const Icon(LucideIcons.info, size: 16, color: AppTheme.textMuted),
                        const SizedBox(width: 8),
                        Text(
                          'Entering scores for ${students.length} students. Raw max: ${widget.assessment.maxScore} • Scaled max: ${widget.assessment.weightage}',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  
                  // Spreadsheet Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: const Row(
                      children: [
                        Expanded(flex: 3, child: Text('Student Name', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('Student ID', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('Score', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 4, child: Text('Remarks', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                  
                  // Spreadsheet Rows
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: students.length,
                      separatorBuilder: (_, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final student = students[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(flex: 3, child: Text('${student.firstName} ${student.lastName}')),
                              Expanded(flex: 2, child: Text(student.studentId, style: const TextStyle(color: AppTheme.textMuted))),
                              Expanded(
                                flex: 2,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 16),
                                  child: TextField(
                                    controller: _scoreControllers[student.id],
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      hintText: '0 - ${widget.assessment.maxScore}',
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    onChanged: (val) {
                                      final score = double.tryParse(val) ?? 0;
                                      if (score > widget.assessment.maxScore) {
                                        _scoreControllers[student.id]!.text = widget.assessment.maxScore.toString();
                                        _scoreControllers[student.id]!.selection = TextSelection.fromPosition(
                                          TextPosition(offset: _scoreControllers[student.id]!.text.length),
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: TextField(
                                  controller: _remarkControllers[student.id],
                                  decoration: const InputDecoration(
                                    hintText: 'Optional remarks...',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error loading grades: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _saveGrades() async {
    setState(() => _isSaving = true);
    
    final grades = <StudentGradesCompanion>[];
    for (final entry in _scoreControllers.entries) {
      final studentId = entry.key;
      final scoreStr = entry.value.text;
      final remark = _remarkControllers[studentId]?.text;

      if (scoreStr.isNotEmpty) {
        final score = double.tryParse(scoreStr) ?? 0;
        grades.add(StudentGradesCompanion.insert(
          assessmentId: widget.assessment.id,
          studentId: studentId,
          score: score,
          remarks: drift.Value(remark),
          updatedAt: drift.Value(DateTime.now()),
        ));
      }
    }

    try {
      await ref.read(assessmentServiceProvider).saveGrades(grades);
      ref.invalidate(assessmentGradesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scores saved successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
