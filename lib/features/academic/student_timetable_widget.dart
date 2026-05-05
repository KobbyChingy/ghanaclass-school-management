import 'package:flutter/material.dart';
import 'timetable_model.dart';

class StudentTimetableWidget extends StatelessWidget {
  final WeeklyTimetable timetable;

  const StudentTimetableWidget({super.key, required this.timetable});

  @override
  Widget build(BuildContext context) {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    final periods = timetable.entries.map((e) => '${e.startTime.format(context)}-${e.endTime.format(context)}').toSet().toList();
    periods.sort();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text('Period')),
          ...days.map((d) => DataColumn(label: Text(d)))
        ],
        rows: periods.map((period) {
          return DataRow(
            cells: [
              DataCell(Text(period)),
              ...days.map((day) {
                TimetableEntry? entry;
                try {
                  entry = timetable.entries.firstWhere(
                    (e) => '${e.startTime.format(context)}-${e.endTime.format(context)}' == period && e.day == day,
                  );
                } catch (_) {
                  entry = null;
                }
                return entry == null
                  ? const DataCell(Text('-'))
                  : DataCell(Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.subject, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Teacher: ${entry.teacher}'),
                        Text('Class: ${entry.className}'),
                      ],
                    ));
              })
            ],
          );
        }).toList(),
      ),
    );
  }
}
