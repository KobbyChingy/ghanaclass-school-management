import 'package:flutter/material.dart';
import 'timetable_model.dart';

class TimetableEntryForm extends StatefulWidget {
  final void Function(TimetableEntry) onAddEntry;

  const TimetableEntryForm({super.key, required this.onAddEntry});

  @override
  @override
  State<TimetableEntryForm> createState() => _TimetableEntryFormState();
}

class _TimetableEntryFormState extends State<TimetableEntryForm> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _teacherController = TextEditingController();
  final _classNameController = TextEditingController();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String _selectedDay = 'Monday';

  @override
  void dispose() {
    _subjectController.dispose();
    _teacherController.dispose();
    _classNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _subjectController,
            decoration: const InputDecoration(labelText: 'Subject'),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _teacherController,
            decoration: const InputDecoration(labelText: 'Teacher'),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _classNameController,
            decoration: const InputDecoration(labelText: 'Class Name'),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedDay,
            items: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']
                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            onChanged: (v) => setState(() => _selectedDay = v ?? 'Monday'),
            decoration: const InputDecoration(labelText: 'Day'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Start Time'),
                  child: InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (picked != null) setState(() => _startTime = picked);
                    },
                    child: Text(_startTime == null ? 'Select' : _startTime!.format(context)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'End Time'),
                  child: InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (picked != null) setState(() => _endTime = picked);
                    },
                    child: Text(_endTime == null ? 'Select' : _endTime!.format(context)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              if (!(_formKey.currentState?.validate() ?? false)) return;
              if (_startTime == null || _endTime == null) return;
              final entry = TimetableEntry(
                subject: _subjectController.text.trim(),
                teacher: _teacherController.text.trim(),
                className: _classNameController.text.trim(),
                startTime: _startTime!,
                endTime: _endTime!,
                day: _selectedDay,
              );
              widget.onAddEntry(entry);
              _formKey.currentState?.reset();
              setState(() {
                _startTime = null;
                _endTime = null;
                _selectedDay = 'Monday';
              });
            },
            child: const Text('Add Entry'),
          ),
        ],
      ),
    );
  }
}
