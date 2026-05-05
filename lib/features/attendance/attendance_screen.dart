import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/features/academic/academic_providers.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';
import 'package:ghanaclass_school_management/features/teachers/teacher_providers.dart';
import 'package:ghanaclass_school_management/features/attendance/staff_attendance_screen.dart';
import 'attendance_providers.dart';
import 'package:drift/drift.dart' as drift;

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  SchoolClassesData? _selectedClass;
  DateTime _selectedDate = DateTime.now();
  String? _selectedPeriod = 'Morning';
  
  Map<int, String> _attendanceMap = {}; // studentId -> status
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final roleName = currentUser?.role;

    // Enforce: Admins do NOT mark student attendance.
    if (roleName == UserRole.admin.name) {
      return const StaffAttendanceScreen();
    }

    // Only teachers (head/class teachers) should mark student attendance.
    if (roleName != null && roleName != UserRole.teacher.name) {
      return Scaffold(
        appBar: AppBar(title: const Text('Attendance Management')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.lock, size: 48, color: AppTheme.textMuted.withValues(alpha: 0.6)),
                const SizedBox(height: 12),
                const Text('Access restricted', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                const Text(
                  'Only head/class teachers can mark student attendance.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isHeadOrClassAsync = ref.watch(isHeadOrClassTeacherProvider);
    final headClassIdAsync = ref.watch(headOrClassTeacherClassIdProvider);
    final classesAsync = ref.watch(classesProvider);

    if (roleName == UserRole.teacher.name) {
      final isAllowed = isHeadOrClassAsync.asData?.value;
      if (isAllowed == false) {
        return Scaffold(
          appBar: AppBar(title: const Text('Attendance Management')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.lock, size: 48, color: AppTheme.textMuted.withValues(alpha: 0.6)),
                  const SizedBox(height: 12),
                  const Text('Access restricted', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 8),
                  const Text(
                    'Only head/class teachers can mark student attendance.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Management'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final classField = classesAsync.when(
            data: (classes) {
              final headClassId = headClassIdAsync.asData?.value;
              final filtered = (roleName == UserRole.teacher.name && headClassId != null)
                  ? classes.where((c) => c.id == headClassId).toList()
                  : classes;

              if (_selectedClass == null && roleName == UserRole.teacher.name && headClassId != null) {
                final match = filtered.isNotEmpty ? filtered.first : null;
                if (match != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    setState(() {
                      _selectedClass = match;
                      _attendanceMap = {};
                    });
                  });
                }
              }

              return DropdownButtonFormField<SchoolClassesData>(
                initialValue: _selectedClass,
                decoration: const InputDecoration(labelText: 'Select Class'),
                items: filtered
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.className),
                        ))
                    .toList(),
                onChanged: filtered.length <= 1
                    ? null
                    : (val) {
                        setState(() {
                          _selectedClass = val;
                          _attendanceMap = {};
                        });
                      },
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, s) => Text('Error loading classes: $e'),
          );

          final dateField = InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Date'),
              child: Row(
                children: [
                  const Icon(LucideIcons.calendar, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(DateFormat('MMM dd, yyyy').format(_selectedDate))),
                ],
              ),
            ),
          );

          final periodField = DropdownButtonFormField<String>(
            initialValue: _selectedPeriod,
            decoration: const InputDecoration(labelText: 'Period'),
            items: const [
              DropdownMenuItem(value: 'Morning', child: Text('Morning')),
              DropdownMenuItem(value: 'Afternoon', child: Text('Afternoon')),
            ],
            onChanged: (val) => setState(() => _selectedPeriod = val),
          );

          final filterBar = Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            ),
            child: LayoutBuilder(
              builder: (context, filterConstraints) {
                final stacked = filterConstraints.maxWidth < 900;
                if (stacked) {
                  return Column(
                    children: [
                      classField,
                      const SizedBox(height: 12),
                      dateField,
                      const SizedBox(height: 12),
                      periodField,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: classField),
                    const SizedBox(width: 16),
                    Expanded(child: dateField),
                    const SizedBox(width: 16),
                    Expanded(child: periodField),
                  ],
                );
              },
            ),
          );

          final attendanceList = _selectedClass == null
              ? const Center(child: Text('Select a class to mark attendance'))
              : _AttendanceList(
                  classId: _selectedClass!.id,
                  date: _selectedDate,
                  period: _selectedPeriod,
                  onMapChanged: (map) {
                    _attendanceMap = map;
                  },
                );

          final actionBar = _selectedClass == null
              ? const SizedBox.shrink()
              : Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveAttendance,
                      icon: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(LucideIcons.save),
                      label: Text(_isSaving ? 'SAVING...' : 'SAVE ATTENDANCE'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.actionIndigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                      ),
                    ),
                  ),
                );

          final compactHeight = constraints.maxHeight < 840;
          if (compactHeight) {
            return ListView(
              children: [
                filterBar,
                SizedBox(height: 360, child: attendanceList),
                actionBar,
              ],
            );
          }

          return Column(
            children: [
              filterBar,
              Expanded(child: attendanceList),
              actionBar,
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveAttendance() async {
    if (_selectedClass == null || _attendanceMap.isEmpty) return;

    setState(() => _isSaving = true);
    final service = ref.read(attendanceServiceProvider);

    try {
      // 1. Ensure internal session exists
      var session = await service.getSession(_selectedClass!.id, _selectedDate, period: _selectedPeriod);
      if (session == null) {
        await service.createSession(
          AttendanceSessionsCompanion.insert(
            classId: _selectedClass!.id,
            date: _selectedDate,
            period: drift.Value(_selectedPeriod),
          ),
        );
        // Refresh session
        session = await service.getSession(_selectedClass!.id, _selectedDate, period: _selectedPeriod);
      }

      if (session == null) throw Exception('Failed to create/fetch session');

      // 2. Map records
      final records = _attendanceMap.entries.map((e) => AttendanceRecordsCompanion.insert(
        sessionId: session!.id,
        studentId: e.key,
        status: e.value,
      )).toList();

      await service.saveAttendanceRecords(records);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance saved successfully!'), backgroundColor: Colors.green),
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

class _AttendanceList extends ConsumerStatefulWidget {
  final int classId;
  final DateTime date;
  final String? period;
  final Function(Map<int, String>) onMapChanged;

  const _AttendanceList({
    required this.classId,
    required this.date,
    required this.period,
    required this.onMapChanged,
  });

  @override
  ConsumerState<_AttendanceList> createState() => _AttendanceListState();
}

class _AttendanceListState extends ConsumerState<_AttendanceList> {
  Map<int, String> _localMap = {};
  bool _initialized = false;

  @override
  void didUpdateWidget(_AttendanceList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classId != widget.classId || oldWidget.date != widget.date || oldWidget.period != widget.period) {
      _initialized = false;
      _localMap = {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(classStudentsProvider(widget.classId));
    final sessionAsync = ref.watch(attendanceSessionProvider(AttendanceQuery(
      classId: widget.classId,
      date: widget.date,
      period: widget.period,
    )));

    return studentsAsync.when(
      data: (students) {
        if (students.isEmpty) return const Center(child: Text('No students in this class.'));

        return sessionAsync.when(
          data: (session) {
            if (session != null && !_initialized) {
               ref.read(sessionRecordsProvider(session.id)).whenData((records) {
                 final map = {for (var r in records) r.studentId: r.status};
                 setState(() {
                   _localMap = map;
                   _initialized = true;
                   widget.onMapChanged(_localMap);
                 });
               });
            } else if (session == null && !_initialized) {
               // Default to 'present' if new session
               final map = {for (var s in students) s.id: 'present'};
               setState(() {
                 _localMap = map;
                 _initialized = true;
                 widget.onMapChanged(_localMap);
               });
            }

            return ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: students.length,
              itemBuilder: (context, index) {
                final student = students[index];
                final status = _localMap[student.id] ?? 'present';

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text('${student.firstName} ${student.lastName}'),
                    subtitle: Text(student.studentId),
                    trailing: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'present', label: Text('P'), tooltip: 'Present'),
                        ButtonSegment(value: 'absent', label: Text('A'), tooltip: 'Absent'),
                        ButtonSegment(value: 'late', label: Text('L'), tooltip: 'Late'),
                      ],
                      selected: {status},
                      onSelectionChanged: (set) {
                        setState(() {
                          _localMap[student.id] = set.first;
                          widget.onMapChanged(_localMap);
                        });
                      },
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Text('Error loading session: $e'),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Text('Error loading students: $e'),
    );
  }
}
