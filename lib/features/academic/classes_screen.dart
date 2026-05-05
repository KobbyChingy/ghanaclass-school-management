import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'academic_providers.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:drift/drift.dart' as drift;
import 'class_assignment_dialog.dart';
import 'package:ghanaclass_school_management/features/staff/staff_providers.dart';
import 'academic_service.dart';
import 'predictive_academic_analytics_card.dart';
import 'subject_teacher_trends_card.dart';
import 'attendance_correlation_card.dart';

class ClassesScreen extends ConsumerWidget {
  const ClassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(classesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Classes Management'),
        actions: [
          ElevatedButton.icon(
            onPressed: () => context.push('/classes/promotion'),
            icon: const Icon(LucideIcons.users, size: 18),
            label: const Text('Promotion Tool'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success.withValues(alpha: 0.1),
              foregroundColor: AppTheme.success,
              elevation: 0,
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => _showAddClassDialog(context, ref),
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text('Add Class'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.actionIndigo,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final classesBody = classesAsync.when(
            data: (classes) => classes.isEmpty
                ? _buildEmptyState(context, ref)
                : _buildClassesList(context, classes, ref),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          );

          final compactHeight = constraints.maxHeight < 900;
          if (compactHeight) {
            return ListView(
              children: [
                const PredictiveAcademicAnalyticsCard(),
                const SubjectTeacherTrendsCard(),
                const AttendanceCorrelationCard(),
                SizedBox(height: 460, child: classesBody),
              ],
            );
          }

          return Column(
            children: [
              const PredictiveAcademicAnalyticsCard(),
              const SubjectTeacherTrendsCard(),
              const AttendanceCorrelationCard(),
              Expanded(child: classesBody),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.school, size: 64, color: AppTheme.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'No classes created yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _showAddClassDialog(context, ref),
            child: const Text('Create First Class'),
          ),
        ],
      ),
    );
  }

  Widget _buildClassesList(BuildContext context, List<SchoolClassesData> classes, WidgetRef ref) {
    final teachers = ref.watch(teachersProvider).value ?? const <User>[];
    final assignmentSummaries = ref.watch(classAssignmentSummariesProvider).value ?? const <int, ClassAssignmentsSummary>{};

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 300,
          mainAxisExtent: 220,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: classes.length,
        itemBuilder: (context, index) {
          final cls = classes[index];

          User? headTeacher;
          final headTeacherId = cls.headTeacherId;
          if (headTeacherId != null) {
            for (final t in teachers) {
              if (t.id == headTeacherId) {
                headTeacher = t;
                break;
              }
            }
          }

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.actionIndigo.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(LucideIcons.school, color: AppTheme.actionIndigo, size: 20),
                      ),
                      Text(
                        'Year: ${cls.academicYear}',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    cls.className,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Code: ${cls.classCode}',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Class Teacher: ${headTeacher?.fullName ?? 'Not set'}',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Builder(
                    builder: (_) {
                      final summary = assignmentSummaries[cls.id];
                      final subjectsCount = summary?.subjectsCount ?? 0;
                      final teachersCount = summary?.teachersCount ?? 0;
                      final assignmentsCount = summary?.assignmentsCount ?? 0;

                      return Text(
                        'Assignments: $assignmentsCount • Subjects: $subjectsCount • Teachers: $teachersCount',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(LucideIcons.users, size: 14, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        'Max: ${cls.capacity}',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(LucideIcons.userPlus, size: 18, color: AppTheme.actionIndigo),
                        tooltip: 'Assign Teachers',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => ClassAssignmentDialog(schoolClass: cls),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddClassDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final capacityController = TextEditingController(text: '40');
    final yearController = TextEditingController(text: DateTime.now().year.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Class'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Class Name (e.g. Grade 1A)')),
            TextField(controller: codeController, decoration: const InputDecoration(labelText: 'Class Code (e.g. G1A)')),
            TextField(controller: capacityController, decoration: const InputDecoration(labelText: 'Max Capacity'), keyboardType: TextInputType.number),
            TextField(controller: yearController, decoration: const InputDecoration(labelText: 'Academic Year'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || codeController.text.isEmpty) return;
              
              await ref.read(academicServiceProvider).createClass(
                SchoolClassesCompanion.insert(
                  className: nameController.text,
                  classCode: codeController.text,
                  academicYear: int.parse(yearController.text),
                  capacity: drift.Value(int.parse(capacityController.text)),
                ),
              );
              ref.invalidate(classesProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
