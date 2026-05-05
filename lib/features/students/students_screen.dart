import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/features/students/student_providers.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/features/students/student_import_service.dart';
import 'package:ghanaclass_school_management/features/students/student_import_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';
import 'student_edit_screen.dart';
import 'package:ghanaclass_school_management/features/academic/academic_providers.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';

class StudentsScreen extends ConsumerStatefulWidget {
  const StudentsScreen({super.key});

  @override
  ConsumerState<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends ConsumerState<StudentsScreen> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all';

  bool _selectionMode = false;
  final Set<int> _selectedStudentTableIds = {};
  List<Student> _lastFilteredStudents = [];

  int? _selectedClassId;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(classesProvider);
    final currentUser = ref.watch(currentUserProvider);
    final isAdmin = currentUser?.role == UserRole.admin.name;
    
    final studentsAsync = ref.watch(studentsListProvider(
      StudentFilter(
        searchQuery: _searchQuery, 
        statusFilter: _selectedFilter == 'all' ? null : _selectedFilter,
        classId: _selectedClassId,
      ),
    ));

    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 1180;
                final actionButtons = Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (_selectionMode) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                        child: Text('${_selectedStudentTableIds.length} selected', style: const TextStyle(color: AppTheme.textMuted)),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _selectionMode = false;
                          _selectedStudentTableIds.clear();
                        }),
                        icon: const Icon(LucideIcons.x, size: 18),
                        label: const Text('Cancel'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: isAdmin ? _selectAllFiltered : null,
                        icon: const Icon(LucideIcons.checkCheck, size: 18),
                        label: const Text('Select All'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: (isAdmin && _selectedStudentTableIds.isNotEmpty) ? _confirmBulkDeactivate : null,
                        icon: const Icon(LucideIcons.shield, size: 18),
                        label: const Text('Deactivate'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: (isAdmin && _selectedStudentTableIds.isNotEmpty) ? _confirmBulkDelete : null,
                        icon: const Icon(LucideIcons.trash2, size: 18),
                        label: const Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                    ] else ...[
                      if (isAdmin)
                        OutlinedButton.icon(
                          onPressed: () => setState(() => _selectionMode = true),
                          icon: const Icon(LucideIcons.checkSquare, size: 18),
                          label: const Text('Bulk Actions'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: () => _handleExport(ref),
                        icon: const Icon(LucideIcons.download, size: 18),
                        label: const Text('Export'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final path = await StudentImportExportService().exportTemplateToExcel();
                          if (path != null) {
                            await OpenFile.open(path);
                          }
                        },
                        icon: const Icon(LucideIcons.fileDown, size: 18),
                        label: const Text('Export Template'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _showImportDialog,
                        icon: const Icon(LucideIcons.upload, size: 18),
                        label: const Text('Import'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => context.push('/students/admission'),
                        icon: const Icon(LucideIcons.userPlus),
                        label: const Text('New Admission'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.actionIndigo,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        ),
                      ),
                    ],
                  ],
                );

                final headerText = Row(
                  children: [
                    const Icon(LucideIcons.users, color: AppTheme.actionIndigo, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Student Registry',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Manage student records and admissions',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      headerText,
                      const SizedBox(height: 16),
                      actionButtons,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: headerText),
                    const SizedBox(width: 16),
                    Flexible(child: actionButtons),
                  ],
                );
              },
            ),
          ),

          // Class filter buttons
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            child: classesAsync.when(
              data: (classes) {
                final sorted = [...classes]
                  ..sort((a, b) => a.classCode.compareTo(b.classCode));

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('All Classes'),
                        selected: _selectedClassId == null,
                        onSelected: (_) => setState(() => _selectedClassId = null),
                        selectedColor: AppTheme.actionIndigo.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: _selectedClassId == null ? AppTheme.actionIndigo : AppTheme.textMuted,
                          fontWeight: _selectedClassId == null ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      for (final c in sorted) ...[
                        ChoiceChip(
                          label: Text(c.classCode),
                          selected: _selectedClassId == c.id,
                          onSelected: (_) => setState(() => _selectedClassId = c.id),
                          selectedColor: AppTheme.actionIndigo.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: _selectedClassId == c.id ? AppTheme.actionIndigo : AppTheme.textMuted,
                            fontWeight: _selectedClassId == c.id ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                );
              },
              loading: () => const SizedBox(
                height: 44,
                child: Align(alignment: Alignment.centerLeft, child: CircularProgressIndicator()),
              ),
              error: (err, _) => Text('Error loading classes: $err'),
            ),
          ),

          // Search and Filters
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final searchField = TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, student ID...',
                    prefixIcon: const Icon(LucideIcons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(LucideIcons.x),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                );

                if (constraints.maxWidth < 760) {
                  return Column(
                    children: [
                      searchField,
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildFilterChip('Active', 'active'),
                          _buildFilterChip('Inactive', 'inactive'),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: searchField),
                    const SizedBox(width: 16),
                    _buildFilterChip('Active', 'active'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Inactive', 'inactive'),
                  ],
                );
              },
            ),
          ),

          // Student List
          Expanded(
            child: studentsAsync.when(
              data: (students) => _buildStudentList(students),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedFilter = selected ? value : 'all');
      },
      selectedColor: AppTheme.actionIndigo.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.actionIndigo : AppTheme.textMuted,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (context) => const StudentImportDialog(),
    );
  }

  Future<void> _handleExport(WidgetRef ref) async {
    final studentsAsync = ref.read(studentsListProvider(
      StudentFilter(searchQuery: _searchQuery, statusFilter: _selectedFilter == 'all' ? null : _selectedFilter),
    ));

    studentsAsync.whenData((students) async {
      final service = StudentImportExportService();
      final path = await service.exportToExcel(students);
      
      if (mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registry exported successfully to $path'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
                                  label: 'Open',
                                  onPressed: () {
                                    OpenFile.open(path);
                                  },
                                ),
          ),
        );
      }
    });
  }

  StudentFilter _currentFilter() {
    return StudentFilter(
      searchQuery: _searchQuery,
      statusFilter: _selectedFilter == 'all' ? null : _selectedFilter,
      classId: _selectedClassId,
    );
  }

  void _selectAllFiltered() {
    setState(() {
      _selectedStudentTableIds
        ..clear()
        ..addAll(_lastFilteredStudents.map((s) => s.id));
    });
  }

  Future<void> _confirmBulkDeactivate() async {
    final count = _selectedStudentTableIds.length;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate students?'),
        content: Text('This will deactivate $count student(s). You can re-activate them later.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final service = ref.read(studentServiceProvider);
      final result = await service.bulkDeactivateStudents(_selectedStudentTableIds.toList());
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text('Deactivated ${result.affected} student(s).'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _selectionMode = false;
        _selectedStudentTableIds.clear();
      });
      ref.invalidate(studentsListProvider(_currentFilter()));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Bulk deactivate failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _confirmBulkDelete() async {
    final count = _selectedStudentTableIds.length;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete students?'),
        content: Text(
          'This will attempt to delete $count student(s). Students with linked records (attendance, grades, payments, reports, parent records) will be skipped.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final service = ref.read(studentServiceProvider);
      final result = await service.bulkDeleteStudents(_selectedStudentTableIds.toList());
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text('Deleted ${result.affected} student(s). Skipped ${result.skippedStudentTableIds.length}.'),
          backgroundColor: result.skippedStudentTableIds.isEmpty ? Colors.green : Colors.orange,
        ),
      );

      if (result.errors.isNotEmpty) {
        if (!context.mounted) return;
        final shown = result.errors.take(10).toList();
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Some students were skipped'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Deleted: ${result.affected}'),
                  Text('Skipped: ${result.skippedStudentTableIds.length}'),
                  const SizedBox(height: 12),
                  const Text('First reasons:'),
                  const SizedBox(height: 8),
                  ...shown.map((e) => Text('• $e')),
                ],
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ),
        );
      }

      setState(() {
        _selectionMode = false;
        _selectedStudentTableIds.clear();
      });
      ref.invalidate(studentsListProvider(_currentFilter()));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Bulk delete failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildStudentList(List<Student> students) {
    _lastFilteredStudents = students;
    if (students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.users, size: 64, color: AppTheme.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No students found',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 18),
            ),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: SingleChildScrollView(
        child: DataTable(
          showCheckboxColumn: _selectionMode,
          headingRowColor: WidgetStateProperty.all(
            AppTheme.surfaceMuted,
          ),
          columns: const [
            DataColumn(label: Text('Student ID')),
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Guardian')),
            DataColumn(label: Text('Phone')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: students.map((Student student) {
            final isActive = student.status == 'active';
            final isSelected = _selectedStudentTableIds.contains(student.id);
            return DataRow(
              selected: _selectionMode ? isSelected : false,
              onSelectChanged: !_selectionMode
                  ? null
                  : (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedStudentTableIds.add(student.id);
                        } else {
                          _selectedStudentTableIds.remove(student.id);
                        }
                      });
                    },
              cells: [
                DataCell(Text(student.studentId)),
                DataCell(Text('${student.firstName} ${student.lastName}')),
                DataCell(Text(student.guardianName)),
                DataCell(Text(student.guardianPhone)),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.success.withValues(alpha: 0.1)
                          : AppTheme.textMuted.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      student.status.toUpperCase(),
                      style: TextStyle(
                        color: isActive ? AppTheme.success : AppTheme.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(LucideIcons.eye, size: 18),
                        onPressed: _selectionMode ? null : () => context.push('/students/${student.id}'),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.edit, size: 18),
                        onPressed: _selectionMode
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => StudentEditScreen(student: student)),
                                ).then((_) => ref.refresh(studentsListProvider(_currentFilter())));
                              },
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
