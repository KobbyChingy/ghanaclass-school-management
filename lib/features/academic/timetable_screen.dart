import 'package:flutter/material.dart';
import 'timetable_model.dart';
import 'timetable_entry_form.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final List<TimetableEntry> _entries = <TimetableEntry>[];
  String _conflictMessage = '';

  void _addEntry(TimetableEntry entry) {
    // Conflict detection: teacher or class overlap
    final conflicts = _entries.where((e) =>
      e.day == entry.day &&
      ((e.teacher == entry.teacher && _overlaps(e, entry)) ||
       (e.className == entry.className && _overlaps(e, entry)))
    ).toList();

    if (conflicts.isNotEmpty) {
      setState(() {
        _conflictMessage = 'Conflict detected with ${conflicts.length} existing entry(ies).';
      });
      return;
    }
    setState(() {
      _entries.add(entry);
      _conflictMessage = '';
    });
  }

  bool _overlaps(TimetableEntry a, TimetableEntry b) {
    final aStart = a.startTime.hour * 60 + a.startTime.minute;
    final aEnd = a.endTime.hour * 60 + a.endTime.minute;
    final bStart = b.startTime.hour * 60 + b.startTime.minute;
    final bEnd = b.endTime.hour * 60 + b.endTime.minute;
    return (aStart < bEnd && bStart < aEnd);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Timetable')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TimetableEntryForm(onAddEntry: _addEntry),
            if (_conflictMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(_conflictMessage, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'].map((day) {
                  final dayEntries = _entries.where((e) => e.day == day).toList();
                  return ExpansionTile(
                    title: Text(day),
                    children: dayEntries.isEmpty
                      ? [const ListTile(title: Text('No entries'))]
                      : dayEntries.map((e) => ListTile(
                          title: Text('${e.subject} (${e.className})'),
                          subtitle: Text('Teacher: ${e.teacher}\n${e.startTime.format(context)} - ${e.endTime.format(context)}'),
                        )).toList(),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
