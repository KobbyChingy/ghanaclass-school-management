import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/features/attendance/staff_attendance_providers.dart';
import 'package:ghanaclass_school_management/features/staff/staff_providers.dart';

class StaffAttendanceScreen extends ConsumerStatefulWidget {
  const StaffAttendanceScreen({super.key});

  @override
  ConsumerState<StaffAttendanceScreen> createState() => _StaffAttendanceScreenState();
}

class _StaffAttendanceScreenState extends ConsumerState<StaffAttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedPeriod = 'Morning';

  String _positionFilter = 'All';
  String _searchQuery = '';

  Map<int, String> _attendanceMap = {}; // staffId -> status
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(staffListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Attendance'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final listChild = staffAsync.when(
            data: (staff) {
              if (staff.isEmpty) {
                return const Center(child: Text('No staff members found.'));
              }

              final positions = <String>{
                for (final s in staff)
                  if (s.position.trim().isNotEmpty) s.position.trim(),
              }.toList(growable: false)
                ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

              if (_positionFilter != 'All' && !positions.contains(_positionFilter)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() => _positionFilter = 'All');
                });
              }

              final q = _searchQuery.trim().toLowerCase();
              final filtered = staff.where((s) {
                if (_positionFilter != 'All' && s.position.trim() != _positionFilter) return false;
                if (q.isEmpty) return true;
                final name = '${s.firstName} ${s.lastName}'.toLowerCase();
                return name.contains(q) || s.staffId.toLowerCase().contains(q) || s.phoneNumber.toLowerCase().contains(q);
              }).toList(growable: false);

              return _StaffAttendanceList(
                staff: filtered,
                date: _selectedDate,
                period: _selectedPeriod,
                onMapChanged: (map) => _attendanceMap = map,
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error: $e')),
          );

          final actionBar = Container(
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

          final compactHeight = constraints.maxHeight < 820;
          if (compactHeight) {
            return ListView(
              children: [
                _buildFilterBar(staffAsync),
                SizedBox(height: 360, child: listChild),
                actionBar,
              ],
            );
          }

          return Column(
            children: [
              _buildFilterBar(staffAsync),
              Expanded(child: listChild),
              actionBar,
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterBar(AsyncValue<List<StaffData>> staffAsync) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 980;

          final searchField = TextField(
            decoration: const InputDecoration(
              labelText: 'Search',
              prefixIcon: Icon(LucideIcons.search, size: 18),
              hintText: 'Name, staff ID, phone…',
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          );

          final dateField = InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() {
                  _selectedDate = picked;
                  _attendanceMap = {};
                });
              }
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Date'),
              child: Row(
                children: [
                  const Icon(LucideIcons.calendar, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      DateFormat('MMM dd, yyyy').format(_selectedDate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );

          final periodField = DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _selectedPeriod,
            decoration: const InputDecoration(labelText: 'Period'),
            items: const [
              DropdownMenuItem(value: 'Morning', child: Text('Morning')),
              DropdownMenuItem(value: 'Afternoon', child: Text('Afternoon')),
            ],
            onChanged: (val) {
              setState(() {
                _selectedPeriod = val;
                _attendanceMap = {};
              });
            },
          );

          Widget positionFieldFrom(List<StaffData> staff) {
            final positions = <String>{
              for (final s in staff)
                if (s.position.trim().isNotEmpty) s.position.trim(),
            }.toList(growable: false)
              ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

            final values = <String>['All', ...positions];

            return DropdownButtonFormField<String>(
              key: ValueKey(_positionFilter),
              isExpanded: true,
              initialValue: _positionFilter,
              decoration: const InputDecoration(labelText: 'Role/Position'),
              selectedItemBuilder: (context) {
                return values
                    .map(
                      (v) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          v,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false);
              },
              items: values
                  .map(
                    (p) => DropdownMenuItem(
                      value: p,
                      child: Text(p, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  _positionFilter = val;
                  _attendanceMap = {};
                });
              },
            );
          }

          final positionField = staffAsync.maybeWhen(
            data: (staff) => positionFieldFrom(staff),
            orElse: () => DropdownButtonFormField<String>(
              key: ValueKey(_positionFilter),
              isExpanded: true,
              initialValue: _positionFilter,
              decoration: const InputDecoration(labelText: 'Role/Position'),
              items: const [
                DropdownMenuItem(value: 'All', child: Text('All')),
              ],
              onChanged: null,
            ),
          );

          final staffCount = staffAsync.maybeWhen(
            data: (list) => Text(
              '${list.length} staff',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textMuted),
            ),
            orElse: () => const SizedBox.shrink(),
          );

          if (isWide) {
            return Row(
              children: [
                Expanded(flex: 2, child: searchField),
                const SizedBox(width: 16),
                Expanded(child: dateField),
                const SizedBox(width: 16),
                Expanded(child: periodField),
                const SizedBox(width: 16),
                Expanded(child: positionField),
                const SizedBox(width: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 80),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: staffCount,
                  ),
                ),
              ],
            );
          }

          double widthOrMax(double preferred) {
            return constraints.maxWidth < preferred ? constraints.maxWidth : preferred;
          }

          return Wrap(
            spacing: 16,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(width: widthOrMax(420), child: searchField),
              SizedBox(width: widthOrMax(260), child: dateField),
              SizedBox(width: widthOrMax(260), child: periodField),
              SizedBox(width: widthOrMax(260), child: positionField),
              staffCount,
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveAttendance() async {
    if (_attendanceMap.isEmpty) return;

    setState(() => _isSaving = true);
    final service = ref.read(staffAttendanceServiceProvider);

    try {
      var session = await service.getSession(_selectedDate, period: _selectedPeriod);
      if (session == null) {
        await service.createSession(
          StaffAttendanceSessionsCompanion.insert(
            date: _selectedDate,
            period: drift.Value(_selectedPeriod),
          ),
        );
        session = await service.getSession(_selectedDate, period: _selectedPeriod);
      }

      if (session == null) throw Exception('Failed to create/fetch session');

      final records = _attendanceMap.entries
          .map(
            (e) => StaffAttendanceRecordsCompanion.insert(
              sessionId: session!.id,
              staffId: e.key,
              status: e.value,
            ),
          )
          .toList();

      await service.saveRecords(records);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff attendance saved successfully!'), backgroundColor: Colors.green),
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

class _StaffAttendanceList extends ConsumerStatefulWidget {
  final List<StaffData> staff;
  final DateTime date;
  final String? period;
  final Function(Map<int, String>) onMapChanged;

  const _StaffAttendanceList({
    required this.staff,
    required this.date,
    required this.period,
    required this.onMapChanged,
  });

  @override
  ConsumerState<_StaffAttendanceList> createState() => _StaffAttendanceListState();
}

class _StaffAttendanceListState extends ConsumerState<_StaffAttendanceList> {
  Map<int, String> _localMap = {};
  bool _initialized = false;

  @override
  void didUpdateWidget(_StaffAttendanceList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date || oldWidget.period != widget.period || oldWidget.staff.length != widget.staff.length) {
      _initialized = false;
      _localMap = {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = StaffAttendanceQuery(date: widget.date, period: widget.period);
    final sessionAsync = ref.watch(staffAttendanceSessionProvider(query));

    return sessionAsync.when(
      data: (session) {
        if (session != null) {
          final recordsAsync = ref.watch(staffAttendanceRecordsProvider(session.id));
          return recordsAsync.when(
            data: (records) {
              if (!_initialized) {
                final map = <int, String>{
                  for (final s in widget.staff) s.id: 'present',
                };
                for (final r in records) {
                  map[r.staffId] = r.status;
                }
                _localMap = map;
                _initialized = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  widget.onMapChanged(_localMap);
                });
              }
              return _buildList(context);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error: $e')),
          );
        }

        if (!_initialized) {
          final map = <int, String>{
            for (final s in widget.staff) s.id: 'present',
          };
          _localMap = map;
          _initialized = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onMapChanged(_localMap);
          });
        }

        return _buildList(context);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.staff.length,
      itemBuilder: (context, index) {
        final staff = widget.staff[index];
        final status = _localMap[staff.id] ?? 'present';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.actionIndigo.withValues(alpha: 0.1),
              child: Text(
                staff.firstName.isNotEmpty ? staff.firstName[0].toUpperCase() : '?',
                style: const TextStyle(color: AppTheme.actionIndigo),
              ),
            ),
            title: Text('${staff.firstName} ${staff.lastName}'),
            subtitle: Text('${staff.position} • ${staff.staffId}'),
            trailing: DropdownButton<String>(
              value: status,
              items: const [
                DropdownMenuItem(value: 'present', child: Text('Present')),
                DropdownMenuItem(value: 'absent', child: Text('Absent')),
                DropdownMenuItem(value: 'late', child: Text('Late')),
                DropdownMenuItem(value: 'excused', child: Text('Excused')),
                DropdownMenuItem(value: 'on_leave', child: Text('On Leave')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _localMap[staff.id] = v;
                });
                widget.onMapChanged(_localMap);
              },
            ),
          ),
        );
      },
    );
  }
}
