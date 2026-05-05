import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/features/teachers/teacher_providers.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/features/academic/academic_providers.dart';
import 'package:ghanaclass_school_management/features/assessments/assessment_screen.dart';

class TeacherStudentsScreen extends ConsumerWidget {
  const TeacherStudentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headStudentsAsync = ref.watch(headTeacherStudentsProvider);
    final subjectStudentsAsync = ref.watch(subjectTeacherStudentsProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Students & Assessments'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Class List'),
              Tab(text: 'Subject List'),
              Tab(text: 'Assessments'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildStudentList(context, headStudentsAsync, 'No students in your assigned class'),
            _buildStudentList(context, subjectStudentsAsync, 'No students assigned to your subjects'),
            _buildAssignmentList(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentList(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(teacherAssignmentsProvider);
    final classesAsync = ref.watch(classesProvider);
    final subjectsAsync = ref.watch(subjectsProvider);

    return assignmentsAsync.when(
      data: (assignments) {
        if (assignments.isEmpty) {
          return const Center(child: Text('No subjects assigned to you for assessments.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: assignments.length,
          itemBuilder: (context, index) {
            final assignment = assignments[index];
            
            // Map names
            final className = classesAsync.whenData((list) => list.firstWhere((c) => c.id == assignment.classId).className).value ?? 'Class ${assignment.classId}';
            final subjectName = subjectsAsync.whenData((list) => list.firstWhere((s) => s.id == assignment.subjectId).subjectName).value ?? 'Subject ${assignment.subjectId}';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(LucideIcons.bookOpen, color: AppTheme.actionIndigo),
                title: Text(subjectName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(className),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AssessmentScreen(
                        classId: assignment.classId,
                        subjectId: assignment.subjectId,
                        className: className,
                        subjectName: subjectName,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildStudentList(BuildContext context, AsyncValue<List<Student>> studentsAsync, String emptyMsg) {
    return studentsAsync.when(
      data: (students) {
        if (students.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.users, size: 48, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text(emptyMsg, style: const TextStyle(color: AppTheme.textMuted)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: students.length,
          itemBuilder: (context, index) {
            final student = students[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.actionIndigo.withValues(alpha: 0.1),
                  child: Text(student.firstName[0].toUpperCase(), style: const TextStyle(color: AppTheme.actionIndigo)),
                ),
                title: Text('${student.firstName} ${student.lastName}'),
                subtitle: Text('ID: ${student.studentId}'),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => context.push('/students/${student.id}'),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}
