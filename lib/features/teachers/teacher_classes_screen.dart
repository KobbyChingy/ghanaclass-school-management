import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/features/academic/academic_providers.dart';
import 'package:ghanaclass_school_management/features/assessments/assessment_screen.dart';
import 'package:ghanaclass_school_management/features/teachers/teacher_providers.dart';
import 'package:ghanaclass_school_management/features/teachers/teacher_service.dart';

class TeacherClassesScreen extends ConsumerWidget {
  const TeacherClassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classIdsAsync = ref.watch(teacherAccessibleClassIdsProvider);
    final assignmentsAsync = ref.watch(teacherAssignmentsProvider);
    final classesAsync = ref.watch(classesProvider);
    final subjectsAsync = ref.watch(subjectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Classes'),
      ),
      body: classIdsAsync.when(
        data: (classIds) {
          if (classIds.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.school, size: 56, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text('No classes assigned yet.'),
                  const SizedBox(height: 6),
                  const Text('Ask an admin to assign you as class/subject teacher.', style: TextStyle(color: AppTheme.textMuted)),
                ],
              ),
            );
          }

          return assignmentsAsync.when(
            data: (assignments) {
              final byClass = <int, List<TeacherClassSubjectAccess>>{};
              for (final a in assignments) {
                byClass.putIfAbsent(a.classId, () => []).add(a);
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: classIds.length,
                itemBuilder: (context, index) {
                  final classId = classIds[index];

                  final className = classesAsync.whenData((list) {
                    final found = list.where((c) => c.id == classId).firstOrNull;
                    return found?.className ?? 'Class $classId';
                  }).value ?? 'Class $classId';

                  final subjectsForClass = (byClass[classId] ?? const <TeacherClassSubjectAccess>[]);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(LucideIcons.school, color: AppTheme.actionIndigo, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  className,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                              if (subjectsForClass.any((s) => s.viaHeadTeacherRole))
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.success.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppTheme.success.withValues(alpha: 0.25)),
                                  ),
                                  child: const Text('Head/Class Teacher', style: TextStyle(color: AppTheme.success, fontSize: 12)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text('Subjects', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                          const SizedBox(height: 8),

                          if (subjectsForClass.isEmpty)
                            const Text('No subject access found for this class.', style: TextStyle(color: AppTheme.textMuted))
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: subjectsForClass.map((a) {
                                final subjectName = subjectsAsync.whenData((list) {
                                  final found = list.where((s) => s.id == a.subjectId).firstOrNull;
                                  return found?.subjectName ?? 'Subject ${a.subjectId}';
                                }).value ?? 'Subject ${a.subjectId}';

                                return ActionChip(
                                  avatar: const Icon(LucideIcons.bookOpen, size: 16, color: AppTheme.actionIndigo),
                                  label: Text(subjectName),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AssessmentScreen(
                                          classId: classId,
                                          subjectId: a.subjectId,
                                          className: className,
                                          subjectName: subjectName,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
