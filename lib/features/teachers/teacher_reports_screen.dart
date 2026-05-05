import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/features/teachers/teacher_providers.dart';
import 'package:ghanaclass_school_management/features/academic/academic_providers.dart';
import 'package:ghanaclass_school_management/features/assessments/student_report_screen.dart';
import 'package:ghanaclass_school_management/features/assessments/report_card_style.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TeacherReportsScreen extends ConsumerStatefulWidget {
  const TeacherReportsScreen({super.key});

  @override
  ConsumerState<TeacherReportsScreen> createState() => _TeacherReportsScreenState();
}

class _TeacherReportsScreenState extends ConsumerState<TeacherReportsScreen> {
  static const _prefTemplateKey = 'report_card_template';
  static const _prefColorKey = 'report_card_color';

  int? _selectedClassId;
  String _query = '';

  ReportCardTemplate _selectedTemplate = ReportCardTemplate.classic;
  ReportCardColorScheme _selectedColor = ReportCardColorScheme.indigo;

  @override
  void initState() {
    super.initState();
    _loadStylePrefs();
  }

  Future<void> _loadStylePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final style = ReportCardStyle.fromIds(
      templateId: prefs.getString(_prefTemplateKey),
      colorId: prefs.getString(_prefColorKey),
    );

    if (!mounted) return;
    setState(() {
      _selectedTemplate = style.template;
      _selectedColor = style.colorScheme;
    });
  }

  Future<void> _saveStylePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefTemplateKey, _selectedTemplate.name);
    await prefs.setString(_prefColorKey, _selectedColor.name);
  }

  @override
  Widget build(BuildContext context) {
    final classIdsAsync = ref.watch(teacherAccessibleClassIdsProvider);
    final classesAsync = ref.watch(classesProvider);
    final studentsAsync = ref.watch(teacherAccessibleStudentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Reports'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppTheme.surfaceMuted,
              border: Border.all(color: AppTheme.border),
            ),
            child: const Row(
              children: [
                Icon(LucideIcons.fileText, size: 18, color: AppTheme.textMuted),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Generate terminal report PDFs for your students.',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _styleSelectorCard(),
          const SizedBox(height: 16),

          classIdsAsync.when(
            data: (accessibleClassIds) {
              return classesAsync.when(
                data: (classes) {
                  final classNameById = <int, String>{
                    for (final c in classes) c.id: c.className,
                  };

                  final filterable = accessibleClassIds
                      .map((id) => (id: id, name: classNameById[id] ?? 'Class $id'))
                      .toList()
                    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                  if (_selectedClassId != null && !accessibleClassIds.contains(_selectedClassId)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      setState(() => _selectedClassId = null);
                    });
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          key: ValueKey(_selectedClassId),
                          initialValue: _selectedClassId,
                          decoration: const InputDecoration(
                            labelText: 'Class',
                            prefixIcon: Icon(LucideIcons.school),
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('All my classes'),
                            ),
                            ...filterable.map(
                              (c) => DropdownMenuItem<int?>(
                                value: c.id,
                                child: Text(c.name),
                              ),
                            ),
                          ],
                          onChanged: (v) => setState(() => _selectedClassId = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Search student',
                            prefixIcon: Icon(LucideIcons.search),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) => setState(() => _query = v),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox(height: 56, child: Center(child: CircularProgressIndicator())),
                error: (e, s) => _ErrorBanner(message: 'Error loading classes: $e'),
              );
            },
            loading: () => const SizedBox(height: 56, child: Center(child: CircularProgressIndicator())),
            error: (e, s) => _ErrorBanner(message: 'Error loading access: $e'),
          ),

          const SizedBox(height: 16),

          studentsAsync.when(
            data: (students) {
              final q = _query.trim().toLowerCase();
              final filtered = students.where((s) {
                if (_selectedClassId != null && s.classId != _selectedClassId) return false;
                if (q.isEmpty) return true;
                final name = '${s.firstName} ${s.lastName}'.toLowerCase();
                final id = s.studentId.toLowerCase();
                return name.contains(q) || id.contains(q);
              }).toList();

              if (filtered.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(LucideIcons.users, size: 48, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        const Text('No students match this filter.', style: TextStyle(color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Students (${filtered.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  ...filtered.map((student) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.actionIndigo.withValues(alpha: 0.1),
                          child: Text(
                            student.firstName.isEmpty ? '?' : student.firstName[0].toUpperCase(),
                            style: const TextStyle(color: AppTheme.actionIndigo),
                          ),
                        ),
                        title: Text('${student.firstName} ${student.lastName}'),
                        subtitle: Text('ID: ${student.studentId}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Terminal report',
                              icon: const Icon(LucideIcons.fileText, color: AppTheme.actionIndigo),
                              onPressed: () => _openTerminalReport(student),
                            ),
                            const Icon(LucideIcons.chevronRight, color: AppTheme.textMuted),
                          ],
                        ),
                        onTap: () => context.push('/students/${student.id}'),
                      ),
                    );
                  }),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, s) => _ErrorBanner(message: 'Error loading students: $e'),
          ),
        ],
      ),
    );
  }

  Widget _styleSelectorCard() {
    final previewColor = _selectedColor.flutterColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Report Card Style', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text(
            'Select the PDF template and accent color to use for terminal reports.',
            style: TextStyle(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<ReportCardTemplate>(
                  initialValue: _selectedTemplate,
                  decoration: const InputDecoration(
                    labelText: 'Template',
                    border: OutlineInputBorder(),
                  ),
                  items: ReportCardTemplate.values
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.label),
                        ),
                      )
                      .toList(),
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() => _selectedTemplate = v);
                    await _saveStylePrefs();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<ReportCardColorScheme>(
                  initialValue: _selectedColor,
                  decoration: const InputDecoration(
                    labelText: 'Accent Color',
                    border: OutlineInputBorder(),
                  ),
                  items: ReportCardColorScheme.values
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: c.flutterColor,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(c.label),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() => _selectedColor = v);
                    await _saveStylePrefs();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 36,
                height: 8,
                decoration: BoxDecoration(
                  color: previewColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${_selectedTemplate.label} • ${_selectedColor.label}',
                style: const TextStyle(color: AppTheme.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openTerminalReport(Student student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentReportScreen(studentId: student.id),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: AppTheme.error.withValues(alpha: 0.08),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.alertTriangle, size: 18, color: AppTheme.error),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: AppTheme.textMuted))),
        ],
      ),
    );
  }
}
