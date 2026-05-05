import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/features/academic/academic_providers.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/core/providers/system_settings_providers.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:drift/drift.dart' as drift;
import 'exam_providers.dart';
import 'exam_pdf_service.dart';
import 'package:ghanaclass_school_management/features/teachers/teacher_providers.dart';
import 'package:ghanaclass_school_management/features/teachers/teacher_service.dart';

class ExamGeneratorScreen extends ConsumerStatefulWidget {
  const ExamGeneratorScreen({super.key});

  @override
  ConsumerState<ExamGeneratorScreen> createState() => _ExamGeneratorScreenState();
}

class _ExamGeneratorScreenState extends ConsumerState<ExamGeneratorScreen> {
  int _currentStep = 0;
  
  // Step 1: Config
  int? _selectedSubjectId;
  int? _selectedClassId;
  String _title = 'Final Examination';
  DateTime _examDate = DateTime.now();
  String _teacherName = '';

  late final TextEditingController _teacherNameController;

  // Auto-pick controls
  late final TextEditingController _autoEasyController;
  late final TextEditingController _autoMediumController;
  late final TextEditingController _autoHardController;
  bool _isAutoPicking = false;
  
  // Step 2: Selection
  String _diffFilter = 'all';
  String _typeFilter = 'all';
  String? _subSubjectFilter;
  final Set<int> _selectedQuestionIds = {};
  List<QuestionBankData> _allQuestions = [];
  bool _isLoadingQuestions = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _teacherName = user?.fullName ?? '';
    _teacherNameController = TextEditingController(text: _teacherName);

    _autoEasyController = TextEditingController(text: '0');
    _autoMediumController = TextEditingController(text: '0');
    _autoHardController = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _teacherNameController.dispose();
    _autoEasyController.dispose();
    _autoMediumController.dispose();
    _autoHardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(subjectsProvider);
    final classesAsync = ref.watch(classesProvider);
    final assignmentsAsync = ref.watch(teacherAssignmentsProvider);
    final isHeadAsync = ref.watch(isHeadOrClassTeacherProvider);
    final headClassIdAsync = ref.watch(headOrClassTeacherClassIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Generator'),
      ),
      body: Stepper(
        type: StepperType.horizontal,
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep == 0) {
            final allowedSubjectIds = assignmentsAsync.maybeWhen(
              data: (assignments) => assignments.map((a) => a.subjectId).toSet(),
              orElse: () => null,
            );
            final effectiveSubjectId = (_selectedSubjectId != null && (allowedSubjectIds?.contains(_selectedSubjectId) ?? false))
                ? _selectedSubjectId
                : null;

            if (effectiveSubjectId == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a subject')));
              return;
            }
            _loadQuestionsForSubject(effectiveSubjectId);
          } else if (_currentStep == 1) {
            if (_selectedQuestionIds.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one question')));
              return;
            }
            setState(() => _currentStep++);
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) setState(() => _currentStep--);
        },
        steps: [
          Step(
            title: const Text('Config'),
            isActive: _currentStep >= 0,
            content: _buildConfigStep(
              subjectsAsync,
              classesAsync,
              assignmentsAsync,
              isHeadAsync,
              headClassIdAsync,
            ),
          ),
          Step(
            title: const Text('Selection'),
            isActive: _currentStep >= 1,
            content: _buildSelectionStep(),
          ),
          Step(
            title: const Text('Preview'),
            isActive: _currentStep >= 2,
            content: _buildPreviewStep(),
          ),
        ],
      ),
    );
  }

  Future<void> _loadQuestionsForSubject(int subjectId) async {
    setState(() {
      _selectedSubjectId = subjectId;
      _isLoadingQuestions = true;
    });
    try {
      final questions = await ref.read(examServiceProvider).getQuestions(subjectId: subjectId);
      if (!mounted) return;
      setState(() {
        _allQuestions = questions;
        _isLoadingQuestions = false;
        _currentStep = 1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingQuestions = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Widget _buildConfigStep(
    AsyncValue<List<SchoolSubject>> subjectsAsync,
    AsyncValue<List<SchoolClassesData>> classesAsync,
    AsyncValue<List<TeacherClassSubjectAccess>> assignmentsAsync,
    AsyncValue<bool> isHeadAsync,
    AsyncValue<int?> headClassIdAsync,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: subjectsAsync.when(
                data: (subjects) => assignmentsAsync.when(
                  data: (assignments) => isHeadAsync.when(
                    data: (isHeadOrClass) {
                        final assignedSubjectIds = assignments.map((a) => a.subjectId).toSet();
                        final filteredSubjects = subjects.where((s) => assignedSubjectIds.contains(s.id)).toList();

                      final effectiveSelectedSubjectId = filteredSubjects.any((s) => s.id == _selectedSubjectId) ? _selectedSubjectId : null;

                      if (filteredSubjects.isEmpty) {
                        return const InputDecorator(
                          decoration: InputDecoration(labelText: 'Subject'),
                          child: Text('No assigned subjects. Ask the admin to assign you as a subject teacher.'),
                        );
                      }

                      return DropdownButtonFormField<int>(
                        key: ValueKey<int?>(effectiveSelectedSubjectId),
                        initialValue: effectiveSelectedSubjectId,
                        decoration: const InputDecoration(labelText: 'Subject'),
                        items: filteredSubjects
                            .map((s) => DropdownMenuItem(value: s.id, child: Text(s.subjectName)))
                            .toList(),
                        onChanged: (v) => setState(() {
                          _selectedSubjectId = v;
                          _selectedQuestionIds.clear();
                          _allQuestions = [];
                        }),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => const Text('Unable to load teacher assignments.'),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => const Text('Unable to load teacher assignments.'),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: classesAsync.when(
                data: (classes) => assignmentsAsync.when(
                  data: (assignments) => headClassIdAsync.when(
                    data: (headClassId) {
                      final allowedClassIds = <int>{...assignments.map((a) => a.classId)};
                      if (headClassId != null) {
                        allowedClassIds.add(headClassId);
                      }
                      final filteredClasses = classes.where((c) => allowedClassIds.contains(c.id)).toList();

                      final effectiveSelectedClassId = filteredClasses.any((c) => c.id == _selectedClassId) ? _selectedClassId : null;

                      if (filteredClasses.isEmpty) {
                        return const InputDecorator(
                          decoration: InputDecoration(labelText: 'Target Class'),
                          child: Text('No assigned classes. Ask the admin to assign you to a class/subject.'),
                        );
                      }

                      return DropdownButtonFormField<int>(
                        key: ValueKey<int?>(effectiveSelectedClassId),
                        initialValue: effectiveSelectedClassId,
                        decoration: const InputDecoration(labelText: 'Target Class'),
                        items: filteredClasses
                            .map((c) => DropdownMenuItem(value: c.id, child: Text(c.className)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedClassId = v),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => const Text('Unable to load teacher class assignment.'),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => const Text('Unable to load teacher assignments.'),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _title,
          decoration: const InputDecoration(labelText: 'Exam Title (e.g. End of Term Exam)'),
          onChanged: (v) => _title = v,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ListTile(
                title: const Text('Exam Date'),
                subtitle: Text(DateFormat('dd MMM yyyy').format(_examDate)),
                trailing: const Icon(LucideIcons.calendar),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _examDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _examDate = picked);
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _teacherNameController,
                decoration: const InputDecoration(labelText: 'Subject Teacher Name'),
                onChanged: (v) => _teacherName = v,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectionStep() {
    if (_isLoadingQuestions) return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));

    if (_selectedSubjectId == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Please go back and select a subject first.'),
      );
    }

    final subSubjectsAsync = ref.watch(subSubjectsProvider(_selectedSubjectId!));
    
    final filtered = _allQuestions.where((q) {
      if (_diffFilter != 'all' && q.difficulty != _diffFilter) return false;
      if (_typeFilter != 'all' && q.questionType != _typeFilter) return false;
      if (_subSubjectFilter != null && q.subSubject != _subSubjectFilter) return false;
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Auto-pick
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(8),
            color: AppTheme.surfaceMuted,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.wand2, size: 18, color: AppTheme.actionIndigo),
                  const SizedBox(width: 8),
                  const Text('Auto-pick from bank', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _isAutoPicking ? null : _autoPick,
                    icon: _isAutoPicking
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(LucideIcons.sparkles, size: 18),
                    label: const Text('Auto Pick'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter how many questions to pick per difficulty. Uses your current Type/Sub-Subject filters.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _autoEasyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Easy', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _autoMediumController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Medium', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _autoHardController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Hard', isDense: true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Filters
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _diffFilter,
                decoration: const InputDecoration(labelText: 'Difficulty'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Difficulties')),
                  DropdownMenuItem(value: 'easy', child: Text('Easy')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'hard', child: Text('Hard')),
                ],
                onChanged: (v) => setState(() => _diffFilter = v!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: subSubjectsAsync.when(
                data: (list) => DropdownButtonFormField<String?>(
                  initialValue: _subSubjectFilter,
                  decoration: const InputDecoration(labelText: 'Sub-Subject'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Sub-Subjects')),
                    ...list.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                  ],
                  onChanged: (v) => setState(() => _subSubjectFilter = v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => const Icon(Icons.error),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _typeFilter,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Types')),
                  DropdownMenuItem(value: 'objective', child: Text('Objective')),
                  DropdownMenuItem(value: 'theory', child: Text('Theory')),
                ],
                onChanged: (v) => setState(() => _typeFilter = v!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Selected: ${_selectedQuestionIds.length} questions', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          height: 400,
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: filtered.isEmpty 
            ? const Center(child: Text('No questions matching filters.'))
            : ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final q = filtered[index];
                  final isSelected = _selectedQuestionIds.contains(q.id);
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selectedQuestionIds.add(q.id);
                        } else {
                          _selectedQuestionIds.remove(q.id);
                        }
                      });
                    },
                    title: Text(q.questionText, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${q.questionType.toUpperCase()} | ${q.difficulty.toUpperCase()} | ${q.subSubject ?? "General"}'),
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _buildPreviewStep() {
    final selectedQuestions = _allQuestions.where((q) => _selectedQuestionIds.contains(q.id)).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppTheme.surfaceMuted, borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              const Icon(LucideIcons.checkCircle2, color: AppTheme.success),
              const SizedBox(width: 12),
              Text('${selectedQuestions.length} questions selected for your paper.', style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _saveAndPrint(selectedQuestions),
                icon: const Icon(LucideIcons.printer),
                label: const Text('Print / Save PDF'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 420,
          child: ListView.builder(
            itemCount: selectedQuestions.length,
            itemBuilder: (context, index) {
              final q = selectedQuestions[index];
              return ListTile(
                leading: Text('${index + 1}.', style: const TextStyle(fontWeight: FontWeight.bold)),
                title: Text(q.questionText),
                subtitle: Text('${q.questionType.toUpperCase()} | ${q.difficulty.toUpperCase()}'),
              );
            },
          ),
        )
      ],
    );
  }

  Future<void> _autoPick() async {
    if (_selectedSubjectId == null) return;

    int parseCount(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;
    final easy = parseCount(_autoEasyController);
    final medium = parseCount(_autoMediumController);
    final hard = parseCount(_autoHardController);

    if (easy < 0 || medium < 0 || hard < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Counts must be 0 or greater.')));
      return;
    }

    if (easy == 0 && medium == 0 && hard == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter at least one count to auto-pick.')));
      return;
    }

    setState(() => _isAutoPicking = true);
    try {
      final type = _typeFilter == 'all' ? null : _typeFilter;
      final picked = await ref.read(examServiceProvider).generateExamSelection(
            subjectId: _selectedSubjectId!,
            type: type,
            subSubject: _subSubjectFilter,
            random: Random(),
            difficultyCounts: {
              'easy': easy,
              'medium': medium,
              'hard': hard,
            },
          );

      if (!mounted) return;
      setState(() {
        _selectedQuestionIds
          ..clear()
          ..addAll(picked.map((q) => q.id));
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _isAutoPicking = false);
    }
  }

  Future<void> _saveAndPrint(List<QuestionBankData> selectedQuestions) async {
    if (_selectedSubjectId == null) return;

    final term = ref.read(activeTermProvider);
    final year = ref.read(activeYearProvider);
    final schoolInfo = await ref.read(institutionalIdentityProvider.future);
    
    final subjects = await ref.read(subjectsProvider.future);
    final subjectMatches = subjects.where((s) => s.id == _selectedSubjectId).toList();
    if (subjectMatches.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selected subject not found.')));
      }
      return;
    }
    final subject = subjectMatches.first;
    
    final classes = await ref.read(classesProvider.future);
    final className = _selectedClassId == null
      ? 'N/A'
      : (classes.where((c) => c.id == _selectedClassId).isEmpty
        ? 'N/A'
        : classes.firstWhere((c) => c.id == _selectedClassId).className);

    final paper = ExamPapersCompanion(
      title: drift.Value(_title),
      subjectId: drift.Value(_selectedSubjectId!),
      classId: drift.Value(_selectedClassId),
      term: drift.Value(term),
      academicYear: drift.Value(year),
      questionsJson: drift.Value(jsonEncode(selectedQuestions.map((q) => q.toJson()).toList())),
      teacherId: drift.Value(ref.read(currentUserProvider)!.id),
      examDate: drift.Value(_examDate),
      teacherNameOverride: drift.Value(_teacherName),
    );

    await ref.read(examServiceProvider).saveExamPaper(paper);
    
    // Generate PDF
    if (schoolInfo == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('School identity is not configured yet.')));
      }
      return;
    }

    await ExamPdfService().generateAndPrintExam(
      title: _title,
      subjectName: subject.subjectName,
      className: className,
      examDate: _examDate,
      teacherName: _teacherName,
      questions: selectedQuestions,
      schoolInfo: schoolInfo,
    );
  }
}

