import 'package:flutter/material.dart';

class TimetableEntry {
  final String subject;
  final String teacher;
  final String className;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String day;

  TimetableEntry({
    required this.subject,
    required this.teacher,
    required this.className,
    required this.startTime,
    required this.endTime,
    required this.day,
  });
}

class WeeklyTimetable {
  final List<TimetableEntry> entries;

  WeeklyTimetable({required this.entries});

  List<TimetableEntry> getEntriesForDay(String day) {
    return entries.where((e) => e.day == day).toList();
  }
}
