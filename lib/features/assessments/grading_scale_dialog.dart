import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'assessment_providers.dart';
import 'package:drift/drift.dart' as drift;

class GradingScaleDialog extends ConsumerStatefulWidget {
  final int classId;
  final int subjectId;
  final int term;

  const GradingScaleDialog({
    super.key,
    required this.classId,
    required this.subjectId,
    required this.term,
  });

  @override
  ConsumerState<GradingScaleDialog> createState() => _GradingScaleDialogState();
}

class _GradingScaleDialogState extends ConsumerState<GradingScaleDialog> {
  final _caController = TextEditingController();
  final _examController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _caController.text = '30';
    _examController.text = '70';
  }

  @override
  void dispose() {
    _caController.dispose();
    _examController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scaleAsync = ref.watch(gradingScaleProvider(AssessmentQuery(
      classId: widget.classId,
      subjectId: widget.subjectId,
      term: widget.term,
    )));

    return AlertDialog(
      title: const Row(
        children: [
          Icon(LucideIcons.settings2, color: AppTheme.actionIndigo),
          SizedBox(width: 12),
          Text('Configure Grading Scale'),
        ],
      ),
      content: scaleAsync.when(
        data: (scale) {
          if (scale != null && _caController.text == '30' && _examController.text == '70') {
             _caController.text = scale.caWeight.toStringAsFixed(0);
             _examController.text = scale.examWeight.toStringAsFixed(0);
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Define how total scores are calculated for this term.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _caController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'CA Weight (%)',
                        hintText: 'e.g. 30',
                      ),
                      onChanged: (val) {
                        final ca = double.tryParse(val) ?? 0;
                        if (ca <= 100) {
                          _examController.text = (100 - ca).toStringAsFixed(0);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _examController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Exam Weight (%)',
                        hintText: 'e.g. 70',
                      ),
                      onChanged: (val) {
                        final exam = double.tryParse(val) ?? 0;
                        if (exam <= 100) {
                          _caController.text = (100 - exam).toStringAsFixed(0);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Total must equal 100%',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Text('Error: $e'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveScale,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.actionIndigo),
          child: Text(_isSaving ? 'Saving...' : 'Save Configuration'),
        ),
      ],
    );
  }

  Future<void> _saveScale() async {
    final ca = double.tryParse(_caController.text) ?? 0;
    final exam = double.tryParse(_examController.text) ?? 0;

    if (ca + exam != 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Total weight must be 100%'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(assessmentServiceProvider).upsertGradingScale(
        GradingScalesCompanion.insert(
          classId: widget.classId,
          subjectId: widget.subjectId,
          term: widget.term,
          caWeight: drift.Value(ca),
          examWeight: drift.Value(exam),
          updatedAt: drift.Value(DateTime.now()),
        ),
      );
      ref.invalidate(gradingScaleProvider);
      if (mounted) Navigator.pop(context);
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
