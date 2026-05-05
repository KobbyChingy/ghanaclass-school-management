import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'assessment_providers.dart';
import 'grade_distribution_chart.dart';
import 'grading_scale_dialog.dart';
import 'score_entry_screen.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:drift/drift.dart' as drift;
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';

class AssessmentScreen extends ConsumerStatefulWidget {
  final int classId;
  final int subjectId;
  final String className;
  final String subjectName;

  const AssessmentScreen({
    super.key,
    required this.classId,
    required this.subjectId,
    required this.className,
    required this.subjectName,
  });

  @override
  ConsumerState<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends ConsumerState<AssessmentScreen> {
  int _selectedTerm = 1;
  bool _isCalculatingFinalScores = false;

  @override
  Widget build(BuildContext context) {
    final query = AssessmentQuery(
      classId: widget.classId,
      subjectId: widget.subjectId,
      term: _selectedTerm,
    );
    
    final assessmentsAsync = ref.watch(classAssessmentsProvider(query));
    final scaleAsync = ref.watch(gradingScaleProvider(query));

    final bodyContent = LayoutBuilder(
      builder: (context, constraints) {
        final scaleCard = scaleAsync.when(
          data: (scale) => Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.actionIndigo.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.actionIndigo.withValues(alpha: 0.2)),
            ),
            child: LayoutBuilder(
              builder: (context, cardConstraints) {
                final stacked = cardConstraints.maxWidth < 760;
                final titleText = Text(
                  'Grading Scale: CA (${scale?.caWeight.toStringAsFixed(0) ?? "30"}%) + Exam (${scale?.examWeight.toStringAsFixed(0) ?? "70"}%)',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.actionIndigo),
                );

                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(LucideIcons.info, color: AppTheme.actionIndigo, size: 20),
                      const SizedBox(height: 12),
                      titleText,
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _isCalculatingFinalScores ? null : () => _calculateFinalScores(context),
                          child: _isCalculatingFinalScores
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Calculate Term Results'),
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    const Icon(LucideIcons.info, color: AppTheme.actionIndigo, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: titleText),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: _isCalculatingFinalScores ? null : () => _calculateFinalScores(context),
                      child: _isCalculatingFinalScores
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Calculate Term Results'),
                    ),
                  ],
                );
              },
            ),
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, s) => const SizedBox.shrink(),
        );

        final chart = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: GradeDistributionChart(
            classId: widget.classId,
            subjectId: widget.subjectId,
            term: _selectedTerm,
          ),
        );

        final assessmentsList = assessmentsAsync.when(
          data: (assessments) => assessments.isEmpty
              ? _buildEmptyState(context)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: assessments.length,
                  itemBuilder: (context, index) {
                    final a = assessments[index];
                    return _AssessmentCard(assessment: a);
                  },
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error: $e')),
        );

        final compactHeight = constraints.maxHeight < 760;
        if (compactHeight) {
          return ListView(
            children: [
              scaleCard,
              chart,
              SizedBox(height: 340, child: assessmentsList),
            ],
          );
        }

        return Column(
          children: [
            scaleCard,
            chart,
            Expanded(child: assessmentsList),
          ],
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.subjectName} - ${widget.className}'),
        actions: [
          _buildTermSelector(),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(LucideIcons.settings2),
            tooltip: 'Grading Scale',
            onPressed: () => _showGradingScale(context),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: [
          bodyContent,
          if (_isCalculatingFinalScores)
            Positioned.fill(
              child: AbsorbPointer(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.12),
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                        SizedBox(width: 12),
                        Text('Calculating term results...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAssessmentDialog(context),
        backgroundColor: AppTheme.actionIndigo,
        icon: const Icon(LucideIcons.plus),
        label: const Text('New Assessment'),
      ),
    );
  }

  Widget _buildTermSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<int>(
        value: _selectedTerm,
        underline: const SizedBox(),
        items: [1, 2, 3].map((t) => DropdownMenuItem(
          value: t,
          child: Text('Term $t'),
        )).toList(),
        onChanged: (val) {
          if (val != null) setState(() => _selectedTerm = val);
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.clipboardList, size: 64, color: AppTheme.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text('No assessments created for this term.'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _showAddAssessmentDialog(context),
            child: const Text('Create First Assessment'),
          ),
        ],
      ),
    );
  }

  void _showGradingScale(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => GradingScaleDialog(
        classId: widget.classId,
        subjectId: widget.subjectId,
        term: _selectedTerm,
      ),
    );
  }

  void _showAddAssessmentDialog(BuildContext context) {
    final titleController = TextEditingController();
    String type = 'homework';
    final maxScoreController = TextEditingController(text: '100');
    final scaledMaxController = TextEditingController(text: '100');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New Assessment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'homework', child: Text('Homework')),
                  DropdownMenuItem(value: 'test', child: Text('Class Test')),
                  DropdownMenuItem(value: 'exercise', child: Text('Exercise')),
                  DropdownMenuItem(value: 'group_work', child: Text('Group Work')),
                  DropdownMenuItem(value: 'mock', child: Text('Mock Exam')),
                  DropdownMenuItem(value: 'exam', child: Text('Main Exam')),
                ],
                onChanged: (val) => setState(() => type = val!),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: maxScoreController,
                decoration: const InputDecoration(labelText: 'Max Score'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: scaledMaxController,
                decoration: const InputDecoration(
                  labelText: 'Scaled Max (CA/Exam contribution)',
                  hintText: 'Defaults to Max Score',
                ),
                keyboardType: TextInputType.number,
              ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty) return;
                final maxScore = double.tryParse(maxScoreController.text) ?? 100.0;
                final scaledMax = double.tryParse(scaledMaxController.text);
                final effectiveScaledMax = (scaledMax == null || scaledMax <= 0) ? maxScore : scaledMax;
                
                final currentUser = ref.read(currentUserProvider);
                if (currentUser == null) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('You are not logged in.'), backgroundColor: Colors.red),
                    );
                  }
                  return;
                }

                final role = currentUser.role;
                final canCreate = role == UserRole.teacher.name || role == UserRole.admin.name;
                if (!canCreate) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Only teachers can add assessments.'), backgroundColor: Colors.red),
                    );
                  }
                  return;
                }

                try {
                  await ref.read(assessmentServiceProvider).createAssessment(
                    AssessmentsCompanion.insert(
                      title: titleController.text,
                      assessmentType: type,
                      classId: widget.classId,
                      subjectId: widget.subjectId,
                      teacherId: currentUser.id,
                      maxScore: drift.Value(maxScore),
                      weightage: drift.Value(effectiveScaledMax),
                      term: drift.Value(_selectedTerm),
                      date: DateTime.now(),
                    ),
                  );
                  ref.invalidate(classAssessmentsProvider);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to create assessment: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _calculateFinalScores(BuildContext context) async {
    if (_isCalculatingFinalScores) return;

    setState(() => _isCalculatingFinalScores = true);

    try {
      await ref.read(assessmentServiceProvider).calculateTermResults(
        widget.classId,
        widget.subjectId,
        _selectedTerm,
      );
      ref.invalidate(classAssessmentsProvider);

      if (mounted) {
        setState(() => _isCalculatingFinalScores = false);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Term results calculated successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCalculatingFinalScores = false);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _AssessmentCard extends StatelessWidget {
  final Assessment assessment;

  const _AssessmentCard({required this.assessment});

  @override
  Widget build(BuildContext context) {
    final isExam = assessment.assessmentType == 'exam';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isExam ? AppTheme.authorityYellow : AppTheme.primarySlate).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isExam ? LucideIcons.graduationCap : LucideIcons.fileText,
            color: isExam ? AppTheme.authorityYellow : AppTheme.textMuted,
            size: 20
          ),
        ),
        title: Text(assessment.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          'Type: ${assessment.assessmentType.toUpperCase()} • Max: ${assessment.maxScore.toStringAsFixed(0)} • ${DateFormat('MMM dd').format(assessment.date)}',
        ),
        trailing: const Icon(LucideIcons.chevronRight),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ScoreEntryScreen(assessment: assessment),
            ),
          );
        },
      ),
    );
  }
}
