import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/features/academic/academic_providers.dart';
import 'package:ghanaclass_school_management/features/id_cards/id_card_design.dart';
import 'package:ghanaclass_school_management/features/id_cards/id_cards_providers.dart';
import 'package:ghanaclass_school_management/features/staff/staff_providers.dart';
import 'package:ghanaclass_school_management/features/students/student_providers.dart';
import 'package:ghanaclass_school_management/shared/printing/pdf_preview_screen.dart';

class IdCardsScreen extends ConsumerStatefulWidget {
  const IdCardsScreen({super.key});

  @override
  ConsumerState<IdCardsScreen> createState() => _IdCardsScreenState();
}

class _IdCardsScreenState extends ConsumerState<IdCardsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _studentSearch = TextEditingController();
  final _staffSearch = TextEditingController();

  String _studentSearchQuery = '';
  String _staffSearchQuery = '';

  String _staffPositionFilter = 'All';

  int? _studentClassId;

  final Set<int> _selectedStudentIds = <int>{};
  final Set<int> _selectedStaffIds = <int>{};

  IdCardTemplate _template = IdCardTemplate.modern;
  int _primaryColor = 0xFF1E40AF;
  int _accentColor = 0xFF0EA5E9;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _studentSearch.dispose();
    _staffSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(classesProvider);
    final staffAsync = ref.watch(staffListProvider);

    final studentsAsync = ref.watch(
      studentsListProvider(
        StudentFilter(
          searchQuery: _studentSearchQuery,
          classId: _studentClassId,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('ID Card Center'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Students'),
            Tab(text: 'Staff'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStudentsTab(context, classesAsync, studentsAsync),
          _buildStaffTab(context, staffAsync),
        ],
      ),
    );
  }

  Widget _buildStudentsTab(
    BuildContext context,
    AsyncValue<List<SchoolClassesData>> classesAsync,
    AsyncValue<List<Student>> studentsAsync,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _designerPanel(),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 860;
                  final searchField = TextField(
                    controller: _studentSearch,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(LucideIcons.search),
                      hintText: 'Search students (name, ID, admission no...)',
                    ),
                    onChanged: (v) => setState(() => _studentSearchQuery = v),
                  );
                  final previewButton = ElevatedButton.icon(
                    onPressed: () async {
                      final ids = _selectedStudentIds.toList(growable: false);
                      if (ids.isEmpty) return;
                      await _previewStudentCards(ids);
                    },
                    icon: const Icon(LucideIcons.printer, size: 18),
                    label: Text('Preview & Print (${_selectedStudentIds.length})'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.actionIndigo, foregroundColor: Colors.white),
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        searchField,
                        const SizedBox(height: 12),
                        Align(alignment: Alignment.centerLeft, child: previewButton),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: searchField),
                      const SizedBox(width: 12),
                      previewButton,
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              classesAsync.when(
                data: (classes) {
                  final sorted = [...classes]..sort((a, b) => a.classCode.compareTo(b.classCode));
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('All Classes'),
                          selected: _studentClassId == null,
                          onSelected: (_) => setState(() => _studentClassId = null),
                        ),
                        const SizedBox(width: 8),
                        for (final c in sorted) ...[
                          ChoiceChip(
                            label: Text(c.classCode),
                            selected: _studentClassId == c.id,
                            onSelected: (_) => setState(() => _studentClassId = c.id),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox(height: 36, child: Align(alignment: Alignment.centerLeft, child: CircularProgressIndicator())),
                error: (e, _) => Text('Error loading classes: $e'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: studentsAsync.when(
            data: (students) => _studentsTable(students),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  Widget _studentsTable(List<Student> students) {
    if (students.isEmpty) {
      return const Center(child: Text('No students found.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(AppTheme.surfaceMuted),
          columns: const [
            DataColumn(label: Text('Select')),
            DataColumn(label: Text('Student ID')),
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Admission No')),
            DataColumn(label: Text('Guardian Phone')),
            DataColumn(label: Text('Status')),
          ],
          rows: students.map((s) {
            final checked = _selectedStudentIds.contains(s.id);
            return DataRow(
              selected: checked,
              onSelectChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selectedStudentIds.add(s.id);
                  } else {
                    _selectedStudentIds.remove(s.id);
                  }
                });
              },
              cells: [
                DataCell(Checkbox(
                  value: checked,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedStudentIds.add(s.id);
                      } else {
                        _selectedStudentIds.remove(s.id);
                      }
                    });
                  },
                )),
                DataCell(Text(s.studentId)),
                DataCell(Text('${s.firstName} ${s.lastName}'.trim())),
                DataCell(Text(s.admissionNumber)),
                DataCell(Text(s.guardianPhone)),
                DataCell(Text(s.status.toUpperCase())),
              ],
            );
          }).toList(growable: false),
        ),
      ),
    );
  }

  Widget _buildStaffTab(BuildContext context, AsyncValue<List<StaffData>> staffAsync) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _designerPanel(),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 980;
                  final searchField = TextField(
                    controller: _staffSearch,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(LucideIcons.search),
                      hintText: 'Search staff (name, staff ID, phone...)',
                    ),
                    onChanged: (v) => setState(() => _staffSearchQuery = v),
                  );
                  final positionFilter = SizedBox(
                    width: compact ? double.infinity : 220,
                    child: staffAsync.maybeWhen(
                      data: (staff) {
                        final positions = <String>{
                          for (final s in staff)
                            if (s.position.trim().isNotEmpty) s.position.trim(),
                        }.toList(growable: false)
                          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

                        final allPositionValues = <String>['All', ...positions];

                        if (_staffPositionFilter != 'All' && !positions.contains(_staffPositionFilter)) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            setState(() => _staffPositionFilter = 'All');
                          });
                        }

                        return DropdownButtonFormField<String>(
                          key: ValueKey(_staffPositionFilter),
                          initialValue: _staffPositionFilter,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Role/Position',
                            prefixIcon: Icon(LucideIcons.badgeCheck),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'All',
                              child: Text('All', overflow: TextOverflow.ellipsis, maxLines: 1),
                            ),
                            ...positions.map(
                              (p) => DropdownMenuItem(
                                value: p,
                                child: Text(p, overflow: TextOverflow.ellipsis, maxLines: 1),
                              ),
                            ),
                          ],
                          selectedItemBuilder: (context) {
                            return allPositionValues
                                .map((v) => Text(v, overflow: TextOverflow.ellipsis, maxLines: 1))
                                .toList(growable: false);
                          },
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _staffPositionFilter = v);
                          },
                        );
                      },
                      orElse: () => DropdownButtonFormField<String>(
                        key: ValueKey(_staffPositionFilter),
                        initialValue: _staffPositionFilter,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Role/Position',
                          prefixIcon: Icon(LucideIcons.badgeCheck),
                        ),
                        items: const [DropdownMenuItem(value: 'All', child: Text('All'))],
                        onChanged: null,
                      ),
                    ),
                  );
                  final previewButton = ElevatedButton.icon(
                    onPressed: () async {
                      final ids = _selectedStaffIds.toList(growable: false);
                      if (ids.isEmpty) return;
                      await _previewStaffCards(ids);
                    },
                    icon: const Icon(LucideIcons.printer, size: 18),
                    label: Text('Preview & Print (${_selectedStaffIds.length})'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.actionIndigo, foregroundColor: Colors.white),
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        searchField,
                        const SizedBox(height: 12),
                        positionFilter,
                        const SizedBox(height: 12),
                        Align(alignment: Alignment.centerLeft, child: previewButton),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: searchField),
                      const SizedBox(width: 12),
                      positionFilter,
                      const SizedBox(width: 12),
                      previewButton,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: staffAsync.when(
            data: (staff) {
              final q = _staffSearchQuery.trim().toLowerCase();
              final filtered = staff.where((s) {
                if (_staffPositionFilter != 'All' && s.position.trim() != _staffPositionFilter) return false;
                if (q.isEmpty) return true;
                final name = '${s.firstName} ${s.lastName}'.toLowerCase();
                return name.contains(q) || s.staffId.toLowerCase().contains(q) || s.phoneNumber.toLowerCase().contains(q);
              }).toList(growable: false);
              return _staffTable(filtered);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  Widget _staffTable(List<StaffData> staff) {
    if (staff.isEmpty) {
      return const Center(child: Text('No staff found.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(AppTheme.surfaceMuted),
          columns: const [
            DataColumn(label: Text('Select')),
            DataColumn(label: Text('Staff ID')),
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Position')),
            DataColumn(label: Text('Phone')),
            DataColumn(label: Text('Active')),
          ],
          rows: staff.map((s) {
            final checked = _selectedStaffIds.contains(s.id);
            return DataRow(
              selected: checked,
              onSelectChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selectedStaffIds.add(s.id);
                  } else {
                    _selectedStaffIds.remove(s.id);
                  }
                });
              },
              cells: [
                DataCell(Checkbox(
                  value: checked,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedStaffIds.add(s.id);
                      } else {
                        _selectedStaffIds.remove(s.id);
                      }
                    });
                  },
                )),
                DataCell(Text(s.staffId)),
                DataCell(Text('${s.firstName} ${s.lastName}'.trim())),
                DataCell(Text(s.position)),
                DataCell(Text(s.phoneNumber)),
                DataCell(Icon(s.isActive ? LucideIcons.checkCircle2 : LucideIcons.xCircle, size: 18, color: s.isActive ? AppTheme.success : AppTheme.error)),
              ],
            );
          }).toList(growable: false),
        ),
      ),
    );
  }

  IdCardStyle _currentStyle() {
    return IdCardStyle(
      template: _template,
      primaryColor: _primaryColor,
      accentColor: _accentColor,
    );
  }

  Widget _designerPanel() {
    final palette = <(String, Color)>[
      ('Indigo', const Color(0xFF1E40AF)),
      ('Blue', const Color(0xFF2563EB)),
      ('Teal', const Color(0xFF0F766E)),
      ('Emerald', const Color(0xFF047857)),
      ('Rose', const Color(0xFFBE123C)),
      ('Orange', const Color(0xFFEA580C)),
      ('Slate', const Color(0xFF334155)),
      ('Black', const Color(0xFF0B1220)),
    ];

    Widget colorChip({required String label, required int selectedValue, required ValueChanged<int> onSelect}) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in palette)
            ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: item.$2,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(item.$1),
                ],
              ),
              selected: selectedValue == item.$2.toARGB32(),
              onSelected: (_) => setState(() => onSelect(item.$2.toARGB32())),
            ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;
          final templatePicker = SizedBox(
            width: compact ? double.infinity : 190,
            child: DropdownMenu<IdCardTemplate>(
              initialSelection: _template,
              label: const Text('Template'),
              width: compact ? constraints.maxWidth : 190,
              dropdownMenuEntries: const [
                DropdownMenuEntry(value: IdCardTemplate.modern, label: 'Modern'),
                DropdownMenuEntry(value: IdCardTemplate.classic, label: 'Classic'),
                DropdownMenuEntry(value: IdCardTemplate.minimal, label: 'Minimal'),
              ],
              onSelected: (v) {
                if (v == null) return;
                setState(() => _template = v);
              },
            ),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact) ...[
                const Row(
                  children: [
                    Icon(LucideIcons.palette, size: 18, color: AppTheme.textMuted),
                    SizedBox(width: 8),
                    Text('Card Designer'),
                  ],
                ),
                const SizedBox(height: 12),
                templatePicker,
              ] else
                Row(
                  children: [
                    const Icon(LucideIcons.palette, size: 18, color: AppTheme.textMuted),
                    const SizedBox(width: 8),
                    Text('Card Designer', style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    templatePicker,
                  ],
                ),
              const SizedBox(height: 10),
              Text('Primary color', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
              const SizedBox(height: 8),
              colorChip(label: 'Primary', selectedValue: _primaryColor, onSelect: (v) => _primaryColor = v),
              const SizedBox(height: 12),
              Text('Accent color', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
              const SizedBox(height: 8),
              colorChip(label: 'Accent', selectedValue: _accentColor, onSelect: (v) => _accentColor = v),
            ],
          );
        },
      ),
    );
  }

  Future<void> _previewStudentCards(List<int> studentIds) async {
    final style = _currentStyle();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(
          title: 'Student ID Cards',
          pdfFileName: 'student-id-cards.pdf',
          canChangePageFormat: false,
          canChangeOrientation: false,
          buildPdf: (_) => ref.read(idCardPdfServiceProvider).buildStudentIdCardsPdf(studentIds: studentIds, style: style),
        ),
      ),
    );
  }

  Future<void> _previewStaffCards(List<int> staffIds) async {
    final style = _currentStyle();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(
          title: 'Staff ID Cards',
          pdfFileName: 'staff-id-cards.pdf',
          canChangePageFormat: false,
          canChangeOrientation: false,
          buildPdf: (_) => ref.read(idCardPdfServiceProvider).buildStaffIdCardsPdf(staffIds: staffIds, style: style),
        ),
      ),
    );
  }
}
