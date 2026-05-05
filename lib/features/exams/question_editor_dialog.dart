import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'exam_providers.dart';

class QuestionEditorDialog extends ConsumerStatefulWidget {
  final int subjectId;
  final QuestionBankData? question;

  const QuestionEditorDialog({super.key, required this.subjectId, this.question});

  @override
  ConsumerState<QuestionEditorDialog> createState() => _QuestionEditorDialogState();
}

class _QuestionEditorDialogState extends ConsumerState<QuestionEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _questionController;
  late TextEditingController _subSubjectController;
  late TextEditingController _marksController;
  late List<TextEditingController> _optionControllers;
  
  String _difficulty = 'medium';
  String _type = 'objective';
  String? _correctAnswer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController(text: widget.question?.questionText);
    _subSubjectController = TextEditingController(text: widget.question?.subSubject);
    _marksController = TextEditingController(text: widget.question?.marks.toString() ?? '1.0');
    
    _difficulty = widget.question?.difficulty ?? 'medium';
    _type = widget.question?.questionType ?? 'objective';
    _correctAnswer = widget.question?.correctAnswer;

    _optionControllers = [];
    if (widget.question?.options != null) {
      final List<dynamic> options = jsonDecode(widget.question!.options!);
      for (var o in options) {
        _optionControllers.add(TextEditingController(text: o.toString()));
      }
    } else {
      _optionControllers = List.generate(4, (_) => TextEditingController());
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _subSubjectController.dispose();
    _marksController.dispose();
    for (var c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    setState(() {
      if (_optionControllers.length > 2) {
        _optionControllers.removeAt(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.question == null ? 'Add Question' : 'Edit Question'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _type,
                        decoration: const InputDecoration(labelText: 'Question Type'),
                        items: const [
                          DropdownMenuItem(value: 'objective', child: Text('Objective (MCQ)')),
                          DropdownMenuItem(value: 'theory', child: Text('Theory')),
                        ],
                        onChanged: (v) => setState(() => _type = v!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _difficulty,
                        decoration: const InputDecoration(labelText: 'Difficulty'),
                        items: const [
                          DropdownMenuItem(value: 'easy', child: Text('Easy')),
                          DropdownMenuItem(value: 'medium', child: Text('Medium')),
                          DropdownMenuItem(value: 'hard', child: Text('Hard')),
                        ],
                        onChanged: (v) => setState(() => _difficulty = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _questionController,
                  decoration: const InputDecoration(labelText: 'Question Text'),
                  maxLines: 4,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _subSubjectController,
                        decoration: const InputDecoration(labelText: 'Sub-Subject (Optional)'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _marksController,
                        decoration: const InputDecoration(labelText: 'Marks'),
                        keyboardType: TextInputType.number,
                        validator: (v) => v == null || double.tryParse(v) == null ? 'Invalid' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_type == 'objective') ...[
                  const Divider(),
                  const Text('Options', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._optionControllers.asMap().entries.map((entry) {
                    final int idx = entry.key;
                    final controller = entry.value;
                    final char = String.fromCharCode(65 + idx);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Radio<String>(
                            value: char,
                            // ignore: deprecated_member_use
                            groupValue: _correctAnswer,
                            // ignore: deprecated_member_use
                            onChanged: (v) => setState(() => _correctAnswer = v),
                          ),
                          Expanded(
                            child: TextFormField(
                              controller: controller,
                              decoration: InputDecoration(labelText: 'Option $char'),
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => _removeOption(idx),
                          ),
                        ],
                      ),
                    );
                  }),
                  TextButton.icon(
                    onPressed: _addOption,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Option'),
                  ),
                ],
                if (_type == 'theory') ...[
                  const Divider(),
                  TextFormField(
                    initialValue: _correctAnswer,
                    decoration: const InputDecoration(labelText: 'Model Answer / Keywords (Optional)'),
                    maxLines: 3,
                    onChanged: (v) => _correctAnswer = v,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading ? const CircularProgressIndicator() : const Text('Save Question'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_type == 'objective' && _correctAnswer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select the correct answer option')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = ref.read(currentUserProvider);
      final options = _type == 'objective' 
        ? jsonEncode(_optionControllers.map((c) => c.text).toList())
        : null;

      final entry = QuestionBankCompanion(
        subjectId: drift.Value(widget.subjectId),
        questionText: drift.Value(_questionController.text),
        questionType: drift.Value(_type),
        difficulty: drift.Value(_difficulty),
        subSubject: drift.Value(_subSubjectController.text.isEmpty ? null : _subSubjectController.text),
        marks: drift.Value(double.parse(_marksController.text)),
        options: drift.Value(options),
        correctAnswer: drift.Value(_correctAnswer),
        teacherId: drift.Value(user!.id),
      );

      if (widget.question == null) {
        await ref.read(examServiceProvider).addQuestion(entry);
      } else {
        await ref.read(examServiceProvider).updateQuestion(entry.copyWith(id: drift.Value(widget.question!.id)));
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
