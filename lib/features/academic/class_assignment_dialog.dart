import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'academic_providers.dart';
import 'package:ghanaclass_school_management/features/staff/staff_providers.dart';
import 'package:drift/drift.dart' as drift;

class ClassAssignmentDialog extends ConsumerStatefulWidget {
  final SchoolClassesData schoolClass;

  const ClassAssignmentDialog({super.key, required this.schoolClass});

  @override
  ConsumerState<ClassAssignmentDialog> createState() => _ClassAssignmentDialogState();
}

class _ClassAssignmentDialogState extends ConsumerState<ClassAssignmentDialog> {
  SchoolSubject? _selectedSubject;
  User? _selectedTeacher;
  User? _selectedHeadTeacher;
  bool _headTeacherExplicitlySet = false;

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(subjectsProvider);
    final teachersAsync = ref.watch(teachersProvider);
    final mappingsAsync = ref.watch(classMappingsProvider(widget.schoolClass.id));

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Manage Assignments: ${widget.schoolClass.className}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 32),

              // Head/Class Teacher
              Text('Class Teacher (Head Teacher)', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              const SizedBox(height: 8),
              teachersAsync.when(
                data: (teachers) {
                  User? currentHead;
                  for (final t in teachers) {
                    if (t.id == widget.schoolClass.headTeacherId) {
                      currentHead = t;
                      break;
                    }
                  }

                  final initialValue = _headTeacherExplicitlySet ? _selectedHeadTeacher : currentHead;

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 640;

                      final classTeacherField = DropdownButtonFormField<User?>(
                        isExpanded: true,
                        initialValue: initialValue,
                        decoration: const InputDecoration(labelText: 'Select Class Teacher'),
                        items: [
                          const DropdownMenuItem<User?>(
                            value: null,
                            child: Text('— None —'),
                          ),
                          ...teachers.map(
                            (t) => DropdownMenuItem<User?>(
                              value: t,
                              child: Text(t.fullName, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() {
                          _selectedHeadTeacher = v;
                          _headTeacherExplicitlySet = true;
                        }),
                      );

                      final saveButton = ElevatedButton.icon(
                        onPressed: () {
                          final teacherToSave = _headTeacherExplicitlySet ? _selectedHeadTeacher : currentHead;
                          _saveHeadTeacher(teacherToSave);
                        },
                        icon: const Icon(LucideIcons.save, size: 18),
                        label: const Text('Save'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.actionIndigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        ),
                      );

                      final clearButton = TextButton(
                        onPressed: () => _saveHeadTeacher(null),
                        child: const Text('Clear'),
                      );

                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            classTeacherField,
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: saveButton),
                                const SizedBox(width: 12),
                                clearButton,
                              ],
                            ),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(child: classTeacherField),
                          const SizedBox(width: 16),
                          saveButton,
                          const SizedBox(width: 12),
                          clearButton,
                        ],
                      );
                    },
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, s) => Text('Error: $e'),
              ),
              
              // New Assignment Row
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 640;

                  final subjectField = subjectsAsync.when(
                    data: (subjects) => DropdownButtonFormField<SchoolSubject>(
                      isExpanded: true,
                      initialValue: _selectedSubject,
                      decoration: const InputDecoration(labelText: 'Select Subject'),
                      items: subjects
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.subjectName, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedSubject = v),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, s) => Text('Error: $e'),
                  );

                  final teacherField = teachersAsync.when(
                    data: (teachers) => DropdownButtonFormField<User>(
                      isExpanded: true,
                      initialValue: _selectedTeacher,
                      decoration: const InputDecoration(labelText: 'Select Teacher'),
                      items: teachers
                          .map(
                            (t) => DropdownMenuItem(
                              value: t,
                              child: Text(t.fullName, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedTeacher = v),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, s) => Text('Error: $e'),
                  );

                  final assignButton = ElevatedButton.icon(
                    onPressed: _selectedSubject == null || _selectedTeacher == null ? null : _addAssignment,
                    icon: const Icon(LucideIcons.plus),
                    label: const Text('Assign'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    ),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        subjectField,
                        const SizedBox(height: 12),
                        teacherField,
                        const SizedBox(height: 12),
                        assignButton,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: subjectField),
                      const SizedBox(width: 16),
                      Expanded(child: teacherField),
                      const SizedBox(width: 16),
                      assignButton,
                    ],
                  );
                },
              ),
              
              const SizedBox(height: 32),
              const Text(
                'Current Assignments',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              
              // List of Mappings
              Expanded(
                child: mappingsAsync.when(
                  data: (mappings) => mappings.isEmpty
                      ? const Center(child: Text('No subjects assigned yet.'))
                      : ListView.separated(
                          itemCount: mappings.length,
                          separatorBuilder: (_, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final m = mappings[index];
                            return _MappingRow(
                              mapping: m,
                              ref: ref,
                              classId: widget.schoolClass.id,
                            );
                          },
                        ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addAssignment() async {
    if (_selectedSubject == null || _selectedTeacher == null) return;

    try {
      await ref.read(academicServiceProvider).assignTeacher(
        ClassSubjectTeachersCompanion.insert(
          classId: widget.schoolClass.id,
          subjectId: _selectedSubject!.id,
          teacherId: _selectedTeacher!.id,
        ),
      );

      ref.invalidate(classMappingsProvider(widget.schoolClass.id));
      ref.invalidate(classAssignmentSummariesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assignment saved.')),
        );
      }

      setState(() {
        _selectedSubject = null;
        _selectedTeacher = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to assign teacher: $e')),
        );
      }
    }
  }

  Future<void> _saveHeadTeacher(User? teacher) async {
    await ref.read(academicServiceProvider).updateClass(
          SchoolClassesCompanion(
            id: drift.Value(widget.schoolClass.id),
            headTeacherId: drift.Value(teacher?.id),
          ),
        );

    ref.invalidate(classesProvider);
    if (mounted) {
      setState(() {
        _selectedHeadTeacher = teacher;
        _headTeacherExplicitlySet = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Class teacher updated.')),
      );
    }
  }
}

class _MappingRow extends StatelessWidget {
  final ClassSubjectTeacher mapping;
  final WidgetRef ref;
  final int classId;

  const _MappingRow({
    required this.mapping,
    required this.ref,
    required this.classId,
  });

  @override
  Widget build(BuildContext context) {
    // We need to fetch the subject and teacher names. 
    // In a production app, we might use a join query in the service.
    // For now, we'll fetch from the providers or DB directly if needed.
    // However, since we have subjectsProvider and teachersProvider, we can use their data.
    
    final subjects = ref.watch(subjectsProvider).value ?? [];
    final teachers = ref.watch(teachersProvider).value ?? [];

    SchoolSubject? subject;
    for (final s in subjects) {
      if (s.id == mapping.subjectId) {
        subject = s;
        break;
      }
    }

    User? teacher;
    for (final t in teachers) {
      if (t.id == mapping.teacherId) {
        teacher = t;
        break;
      }
    }

    return ListTile(
      leading: const Icon(LucideIcons.bookOpen, size: 20),
      title: Text(subject?.subjectName ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('Teacher: ${teacher?.fullName ?? 'Unknown'}'),
      trailing: IconButton(
        icon: const Icon(LucideIcons.trash2, size: 18, color: Colors.redAccent),
        onPressed: () async {
          await ref.read(academicServiceProvider).removeAssignment(mapping.id);
          ref.invalidate(classMappingsProvider(classId));
          ref.invalidate(classAssignmentSummariesProvider);
        },
      ),
    );
  }
}
