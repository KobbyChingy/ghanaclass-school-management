import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/features/staff/staff_providers.dart';
import 'package:ghanaclass_school_management/core/router/role_routes.dart';

import 'academic_providers.dart';

class TeacherAssignmentsScreen extends ConsumerStatefulWidget {
  const TeacherAssignmentsScreen({super.key});

  @override
  ConsumerState<TeacherAssignmentsScreen> createState() => _TeacherAssignmentsScreenState();
}

class _TeacherAssignmentsScreenState extends ConsumerState<TeacherAssignmentsScreen> {
  int? _selectedTeacherId;

  // Head/Class teacher assignment (left)
  int? _selectedHeadClassId;

  // Subject teacher assignment (right)
  int? _selectedSubjectClassId;
  int? _selectedSubjectId;

  final TextEditingController _subjectTeacherSearchController = TextEditingController();
  String _subjectTeacherSearchQuery = '';

  @override
  void dispose() {
    _subjectTeacherSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final roleName = currentUser?.role ?? '';
    final canManageAssignments = roleNameIsOneOf(
      roleName,
      const [
        UserRole.admin,
        UserRole.headmaster,
        UserRole.headmistress,
        UserRole.deputyheadmaster,
        UserRole.deputyheadmistress,
      ],
    );

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!canManageAssignments) {
      return const Scaffold(
        body: Center(
          child: Text('Access restricted.'),
        ),
      );
    }

    final teachersAsync = ref.watch(teachersProvider);
    final classesAsync = ref.watch(classesProvider);
    final subjectsAsync = ref.watch(subjectsProvider);

    final offeredSubjectsAsync = _selectedSubjectClassId == null
      ? subjectsAsync
      : ref.watch(subjectsForClassProvider(_selectedSubjectClassId!));

    final selectedTeacherId = _selectedTeacherId;
    final selectedSubjectClassId = _selectedSubjectClassId;
    final selectedSubjectId = _selectedSubjectId;

    final classMappingsAsync = (selectedSubjectClassId == null)
      ? const AsyncValue<List<ClassSubjectTeacher>>.data([])
      : ref.watch(classMappingsProvider(selectedSubjectClassId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Assignments'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Head/Class teacher assignment
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Head/Class Teacher', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Icon(LucideIcons.userCheck, color: AppTheme.actionIndigo.withValues(alpha: 0.9)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Assign a teacher as Class Teacher (Head Teacher) for a class.',
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                            teachersAsync.when(
                              data: (teachers) {
                                final onlyTeachers = teachers.where((t) => t.role == UserRole.teacher.name).toList();
                                final selected = onlyTeachers.where((t) => t.id == _selectedTeacherId).cast<User?>().firstWhere(
                                      (t) => t != null,
                                      orElse: () => null,
                                    );

                                return DropdownButtonFormField<User>(
                                  isExpanded: true,
                                  initialValue: selected,
                                  decoration: const InputDecoration(labelText: 'Teacher'),
                                  items: onlyTeachers
                                      .map((t) => DropdownMenuItem<User>(
                                            value: t,
                                            child: Text(
                                              '${t.fullName} (${t.email})',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (v) {
                                    setState(() {
                                      _selectedTeacherId = v?.id;
                                      _selectedHeadClassId = null;
                                    });
                                  },
                                );
                              },
                              loading: () => const LinearProgressIndicator(),
                              error: (e, s) => Text('Error loading teachers: $e'),
                            ),
                            const SizedBox(height: 12),

                            Expanded(
                              child: classesAsync.when(
                                data: (classes) {
                                  final teacherId = selectedTeacherId;
                                  final headClasses = (teacherId == null)
                                      ? const <SchoolClassesData>[]
                                      : classes.where((c) => c.headTeacherId == teacherId).toList();

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      DropdownButtonFormField<int>(
                                        isExpanded: true,
                                        initialValue: _selectedHeadClassId,
                                        decoration: const InputDecoration(labelText: 'Class'),
                                        items: classes
                                            .map((c) => DropdownMenuItem<int>(
                                                  value: c.id,
                                                  child: Text(c.className, overflow: TextOverflow.ellipsis),
                                                ))
                                            .toList(),
                                        onChanged: (v) => setState(() => _selectedHeadClassId = v),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: (selectedTeacherId == null || _selectedHeadClassId == null)
                                                  ? null
                                                  : () => _assignHeadTeacher(selectedTeacherId, _selectedHeadClassId!),
                                              icon: const Icon(LucideIcons.plus, size: 18),
                                              label: const Text('Set as Class Teacher'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppTheme.actionIndigo,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      const Divider(),
                                      const SizedBox(height: 8),
                                      const Text('Classes currently assigned:', style: TextStyle(fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 8),
                                      if (selectedTeacherId == null)
                                        Text('Select a teacher first.', style: TextStyle(color: AppTheme.textMuted))
                                      else if (headClasses.isEmpty)
                                        Text('None', style: TextStyle(color: AppTheme.textMuted))
                                      else
                                        Expanded(
                                          child: ListView.separated(
                                            itemCount: headClasses.length,
                                            separatorBuilder: (context, index) => const Divider(height: 1),
                                            itemBuilder: (context, idx) {
                                              final cls = headClasses[idx];
                                              return ListTile(
                                                dense: true,
                                                title: Text(cls.className, overflow: TextOverflow.ellipsis),
                                                subtitle: Text('Code: ${cls.classCode}'),
                                                trailing: TextButton(
                                                  onPressed: () => _clearHeadTeacher(cls.id),
                                                  child: const Text('Remove'),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                    ],
                                  );
                                },
                                loading: () => const Center(child: LinearProgressIndicator()),
                                error: (e, s) => Center(child: Text('Error loading classes: $e')),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Right: Subject teacher assignments
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Subject Teacher Assignments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Icon(LucideIcons.bookOpen, color: AppTheme.success.withValues(alpha: 0.9)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Pick a class + subject, then assign/unassign teachers below.',
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                            ),
                            const SizedBox(height: 12),

                            // Responsive filter controls (prevents overflow banners)
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 560;

                                final classField = classesAsync.when(
                                  data: (classes) => DropdownButtonFormField<int>(
                                    isExpanded: true,
                                    initialValue: _selectedSubjectClassId,
                                    decoration: const InputDecoration(labelText: 'Class'),
                                    items: classes
                                        .map((c) => DropdownMenuItem<int>(
                                              value: c.id,
                                              child: Text(c.className, overflow: TextOverflow.ellipsis),
                                            ))
                                        .toList(),
                                    onChanged: (v) => setState(() {
                                      _selectedSubjectClassId = v;
                                      _selectedSubjectId = null;
                                    }),
                                  ),
                                  loading: () => const LinearProgressIndicator(),
                                  error: (e, s) => Text('Error loading classes: $e'),
                                );

                                final subjectField = offeredSubjectsAsync.when(
                                  data: (subjects) => DropdownButtonFormField<int>(
                                    isExpanded: true,
                                    initialValue: _selectedSubjectId,
                                    decoration: const InputDecoration(labelText: 'Subject'),
                                    items: subjects
                                        .map((s) => DropdownMenuItem<int>(
                                              value: s.id,
                                              child: Text(s.subjectName, overflow: TextOverflow.ellipsis),
                                            ))
                                        .toList(),
                                    onChanged: (v) => setState(() => _selectedSubjectId = v),
                                  ),
                                  loading: () => const LinearProgressIndicator(),
                                  error: (e, s) => Text('Error loading subjects: $e'),
                                );

                                if (isNarrow) {
                                  return Column(
                                    children: [
                                      classField,
                                      const SizedBox(height: 12),
                                      subjectField,
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(child: classField),
                                    const SizedBox(width: 12),
                                    Expanded(child: subjectField),
                                  ],
                                );
                              },
                            ),

                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 8),

                            Expanded(
                              child: (selectedSubjectClassId == null || selectedSubjectId == null)
                                  ? Center(
                                      child: Text(
                                        'Select a class and subject to manage assignments.',
                                        style: TextStyle(color: AppTheme.textMuted),
                                      ),
                                    )
                                  : teachersAsync.when(
                                      data: (teachers) {
                                        return classMappingsAsync.when(
                                          data: (mappings) {
                                            final relevant = mappings.where((m) => m.subjectId == selectedSubjectId).toList();
                                            final assignedTeacherIds = relevant.map((m) => m.teacherId).toSet();

                                            final allAssignedTeachers = teachers.where((t) => assignedTeacherIds.contains(t.id)).toList();
                                            final allUnassignedTeachers = teachers.where((t) => !assignedTeacherIds.contains(t.id)).toList();

                                            final query = _subjectTeacherSearchQuery.trim().toLowerCase();
                                            bool matchesQuery(User teacher) {
                                              if (query.isEmpty) return true;
                                              final name = (teacher.fullName).toLowerCase();
                                              final email = (teacher.email).toLowerCase();
                                              return name.contains(query) || email.contains(query);
                                            }

                                            final assignedTeachers = allAssignedTeachers.where(matchesQuery).toList();
                                            final unassignedTeachers = allUnassignedTeachers.where(matchesQuery).toList();

                                            Widget buildTeacherTile({
                                              required User teacher,
                                              required Widget trailing,
                                            }) {
                                              return ListTile(
                                                dense: true,
                                                title: Text(teacher.fullName, overflow: TextOverflow.ellipsis),
                                                subtitle: Text(teacher.email, overflow: TextOverflow.ellipsis),
                                                trailing: trailing,
                                              );
                                            }

                                            Widget buildListCard({
                                              required String title,
                                              required IconData icon,
                                              required Color iconColor,
                                              required List<User> teachers,
                                              required int totalCount,
                                              required Widget Function(User) actionBuilder,
                                              required String emptyText,
                                            }) {
                                              return Card(
                                                elevation: 0,
                                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                child: Padding(
                                                  padding: const EdgeInsets.all(12),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Icon(icon, size: 18, color: iconColor),
                                                          const SizedBox(width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              query.isEmpty
                                                                  ? '$title (${teachers.length})'
                                                                  : '$title (${teachers.length} of $totalCount)',
                                                              style: const TextStyle(fontWeight: FontWeight.w700),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 8),
                                                      const Divider(height: 1),
                                                      const SizedBox(height: 8),
                                                      Expanded(
                                                        child: teachers.isEmpty
                                                            ? Center(child: Text(emptyText, style: TextStyle(color: AppTheme.textMuted)))
                                                            : ListView.separated(
                                                                itemCount: teachers.length,
                                                                separatorBuilder: (context, index) => const Divider(height: 1),
                                                                itemBuilder: (context, index) {
                                                                  final t = teachers[index];
                                                                  return buildTeacherTile(
                                                                    teacher: t,
                                                                    trailing: actionBuilder(t),
                                                                  );
                                                                },
                                                              ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }

                                            return LayoutBuilder(
                                              builder: (context, constraints) {
                                                final isNarrow = constraints.maxWidth < 560;
                                                return Column(
                                                  children: [
                                                    TextField(
                                                      controller: _subjectTeacherSearchController,
                                                      decoration: InputDecoration(
                                                        labelText: 'Search teachers (name or email)',
                                                        prefixIcon: const Icon(LucideIcons.search, size: 18),
                                                        suffixIcon: _subjectTeacherSearchQuery.trim().isEmpty
                                                            ? null
                                                            : IconButton(
                                                                tooltip: 'Clear',
                                                                icon: const Icon(LucideIcons.x, size: 18),
                                                                onPressed: () {
                                                                  _subjectTeacherSearchController.clear();
                                                                  setState(() => _subjectTeacherSearchQuery = '');
                                                                },
                                                              ),
                                                      ),
                                                      onChanged: (v) => setState(() => _subjectTeacherSearchQuery = v),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Expanded(
                                                      child: isNarrow
                                                          ? Column(
                                                              children: [
                                                                Expanded(
                                                                  child: buildListCard(
                                                                    title: 'Assigned Teachers',
                                                                    icon: LucideIcons.userCheck,
                                                                    iconColor: AppTheme.success,
                                                                    teachers: assignedTeachers,
                                                                    totalCount: allAssignedTeachers.length,
                                                                    emptyText: query.isEmpty
                                                                        ? 'No assigned teachers yet.'
                                                                        : 'No matches.',
                                                                    actionBuilder: (t) {
                                                                      final mapping = relevant.where((m) => m.teacherId == t.id).cast<ClassSubjectTeacher?>().firstWhere(
                                                                            (m) => m != null,
                                                                            orElse: () => null,
                                                                          );
                                                                      return IconButton(
                                                                        tooltip: 'Unassign',
                                                                        icon: const Icon(LucideIcons.userX, color: Colors.redAccent),
                                                                        onPressed: mapping == null
                                                                            ? null
                                                                            : () => _removeSubjectAssignment(
                                                                                  mappingId: mapping.id,
                                                                                  classId: selectedSubjectClassId,
                                                                                  teacherId: t.id,
                                                                                ),
                                                                      );
                                                                    },
                                                                  ),
                                                                ),
                                                                const SizedBox(height: 12),
                                                                Expanded(
                                                                  child: buildListCard(
                                                                    title: 'Unassigned Teachers',
                                                                    icon: LucideIcons.userPlus,
                                                                    iconColor: AppTheme.actionIndigo,
                                                                    teachers: unassignedTeachers,
                                                                    totalCount: allUnassignedTeachers.length,
                                                                    emptyText: query.isEmpty
                                                                        ? 'Everyone is already assigned.'
                                                                        : 'No matches.',
                                                                    actionBuilder: (t) {
                                                                      return ElevatedButton(
                                                                        onPressed: () => _assignSubjectTeacher(
                                                                          teacherId: t.id,
                                                                          classId: selectedSubjectClassId,
                                                                          subjectId: selectedSubjectId,
                                                                        ),
                                                                        style: ElevatedButton.styleFrom(
                                                                          backgroundColor: AppTheme.success,
                                                                          foregroundColor: Colors.white,
                                                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                                        ),
                                                                        child: const Text('Assign'),
                                                                      );
                                                                    },
                                                                  ),
                                                                ),
                                                              ],
                                                            )
                                                          : Row(
                                                              children: [
                                                                Expanded(
                                                                  child: buildListCard(
                                                                    title: 'Assigned Teachers',
                                                                    icon: LucideIcons.userCheck,
                                                                    iconColor: AppTheme.success,
                                                                    teachers: assignedTeachers,
                                                                    totalCount: allAssignedTeachers.length,
                                                                    emptyText: query.isEmpty
                                                                        ? 'No assigned teachers yet.'
                                                                        : 'No matches.',
                                                                    actionBuilder: (t) {
                                                                      final mapping = relevant.where((m) => m.teacherId == t.id).cast<ClassSubjectTeacher?>().firstWhere(
                                                                            (m) => m != null,
                                                                            orElse: () => null,
                                                                          );
                                                                      return IconButton(
                                                                        tooltip: 'Unassign',
                                                                        icon: const Icon(LucideIcons.userX, color: Colors.redAccent),
                                                                        onPressed: mapping == null
                                                                            ? null
                                                                            : () => _removeSubjectAssignment(
                                                                                  mappingId: mapping.id,
                                                                                  classId: selectedSubjectClassId,
                                                                                  teacherId: t.id,
                                                                                ),
                                                                      );
                                                                    },
                                                                  ),
                                                                ),
                                                                const SizedBox(width: 12),
                                                                Expanded(
                                                                  child: buildListCard(
                                                                    title: 'Unassigned Teachers',
                                                                    icon: LucideIcons.userPlus,
                                                                    iconColor: AppTheme.actionIndigo,
                                                                    teachers: unassignedTeachers,
                                                                    totalCount: allUnassignedTeachers.length,
                                                                    emptyText: query.isEmpty
                                                                        ? 'Everyone is already assigned.'
                                                                        : 'No matches.',
                                                                    actionBuilder: (t) {
                                                                      return ElevatedButton(
                                                                        onPressed: () => _assignSubjectTeacher(
                                                                          teacherId: t.id,
                                                                          classId: selectedSubjectClassId,
                                                                          subjectId: selectedSubjectId,
                                                                        ),
                                                                        style: ElevatedButton.styleFrom(
                                                                          backgroundColor: AppTheme.success,
                                                                          foregroundColor: Colors.white,
                                                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                                        ),
                                                                        child: const Text('Assign'),
                                                                      );
                                                                    },
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                          },
                                          loading: () => const Center(child: CircularProgressIndicator()),
                                          error: (e, s) => Center(child: Text('Error loading assignments: $e')),
                                        );
                                      },
                                      loading: () => const Center(child: CircularProgressIndicator()),
                                      error: (e, s) => Center(child: Text('Error loading teachers: $e')),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assignHeadTeacher(int teacherId, int classId) async {
    try {
      await ref.read(academicServiceProvider).updateClass(
            SchoolClassesCompanion(
              id: drift.Value(classId),
              headTeacherId: drift.Value(teacherId),
            ),
          );

      ref.invalidate(classesProvider);
      ref.invalidate(classAssignmentSummariesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Class teacher updated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update class teacher: $e')),
        );
      }
    }
  }

  Future<void> _clearHeadTeacher(int classId) async {
    try {
      await ref.read(academicServiceProvider).updateClass(
            SchoolClassesCompanion(
              id: drift.Value(classId),
              headTeacherId: const drift.Value(null),
            ),
          );

      ref.invalidate(classesProvider);
      ref.invalidate(classAssignmentSummariesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Class teacher cleared.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear class teacher: $e')),
        );
      }
    }
  }

  Future<void> _assignSubjectTeacher({
    required int teacherId,
    required int classId,
    required int subjectId,
  }) async {
    try {
      await ref.read(academicServiceProvider).assignTeacher(
            ClassSubjectTeachersCompanion.insert(
              classId: classId,
              subjectId: subjectId,
              teacherId: teacherId,
            ),
          );

      ref.invalidate(teacherMappingsProvider(teacherId));
      ref.invalidate(classMappingsProvider(classId));
      ref.invalidate(classAssignmentSummariesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subject assignment saved.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to assign subject: $e')),
        );
      }
    }
  }

  Future<void> _removeSubjectAssignment({
    required int mappingId,
    required int classId,
    required int teacherId,
  }) async {
    try {
      await ref.read(academicServiceProvider).removeAssignment(mappingId);

      ref.invalidate(teacherMappingsProvider(teacherId));
      ref.invalidate(classMappingsProvider(classId));
      ref.invalidate(classAssignmentSummariesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assignment removed.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove assignment: $e')),
        );
      }
    }
  }
}
