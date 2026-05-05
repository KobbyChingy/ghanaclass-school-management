import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/core/providers/system_settings_providers.dart';
import 'package:ghanaclass_school_management/features/academic/academic_providers.dart';
import 'package:ghanaclass_school_management/features/staff/staff_providers.dart';
import 'package:ghanaclass_school_management/features/teachers/teacher_providers.dart';
import 'package:ghanaclass_school_management/shared/widgets/portal_surface.dart';

class TeacherDashboardScreen extends ConsumerWidget {
  const TeacherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final academicYear = ref.watch(activeYearProvider);
    final term = ref.watch(activeTermProvider);
    final staffProfileAsync = ref.watch(currentStaffProfileProvider);
    final headStudentsAsync = ref.watch(headTeacherStudentsProvider);
    final accessibleStudentsAsync = ref.watch(teacherAccessibleStudentsProvider);
    final assignmentsAsync = ref.watch(teacherAssignmentsProvider);
    final classIdsAsync = ref.watch(teacherAccessibleClassIdsProvider);
    final headClassIdAsync = ref.watch(headOrClassTeacherClassIdProvider);
    final unreadMessagesAsync = ref.watch(teacherUnreadParentMessagesCountProvider);
    final isSubjectTeacherAsync = ref.watch(isSubjectTeacherProvider);
    final classesAsync = ref.watch(classesProvider);
    final canMarkAttendance = ref.watch(isHeadOrClassTeacherProvider).maybeWhen(
          data: (v) => v,
          orElse: () => false,
        );

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final staffSummary = staffProfileAsync.maybeWhen(
      data: (value) => value?.staff,
      orElse: () => null,
    );
    final headlineSubtitle = [
      if ((staffSummary?.position.trim().isNotEmpty ?? false)) staffSummary!.position.trim(),
      if ((staffSummary?.department?.trim().isNotEmpty ?? false)) staffSummary!.department!.trim(),
    ].join(' • ');

    final headClassName = headClassIdAsync.maybeWhen(
      data: (classId) {
        if (classId == null) return 'Not assigned';
        final classes = classesAsync.maybeWhen(
          data: (value) => value,
          orElse: () => const <SchoolClassesData>[],
        );
        final found = classes.where((item) => item.id == classId).firstOrNull;
        return found?.className ?? 'Class $classId';
      },
      orElse: () => 'Loading...',
    );

    final unreadMessages = unreadMessagesAsync.maybeWhen(
      data: (value) => value.toString(),
      orElse: () => '—',
    );

    final roleScope = _roleScopeLabel(
      canMarkAttendance: canMarkAttendance,
      isSubjectTeacher: isSubjectTeacherAsync.maybeWhen(data: (value) => value, orElse: () => false),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Portal'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          PortalHeroBanner(
            eyebrow: 'Teacher workspace',
            title: 'Welcome, ${user.fullName}',
            subtitle: headlineSubtitle.isEmpty
                ? 'Track classes, student workloads, assessments, and attendance from one teaching surface.'
                : '$headlineSubtitle • Track classes, student workloads, assessments, and attendance from one teaching surface.',
            icon: LucideIcons.school,
            primary: AppTheme.actionIndigo,
            accent: AppTheme.success,
            metrics: [
              PortalHeroMetric(label: 'Academic year', value: '$academicYear'),
              PortalHeroMetric(label: 'Active term', value: 'Term $term'),
              PortalHeroMetric(
                label: 'Students in scope',
                value: accessibleStudentsAsync.maybeWhen(data: (value) => value.length.toString(), orElse: () => '—'),
              ),
              PortalHeroMetric(label: 'Unread parent messages', value: unreadMessages),
            ],
          ),
          const SizedBox(height: 24),

          PortalSectionPanel(
            title: 'Teaching Pulse',
            subtitle: 'A compact summary of the workload, access, and communication that matters most this term.',
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _KpiCard(
                  icon: LucideIcons.users,
                  title: 'My Students',
                  value: accessibleStudentsAsync.maybeWhen(data: (value) => value.length.toString(), orElse: () => '—'),
                  subtitle: 'All students in your teaching scope',
                  color: AppTheme.actionIndigo,
                  onTap: () => context.push('/my-students'),
                ),
                _KpiCard(
                  icon: LucideIcons.school,
                  title: 'My Classes',
                  value: classIdsAsync.maybeWhen(data: (v) => v.length.toString(), orElse: () => '—'),
                  subtitle: 'Assigned classes',
                  color: AppTheme.authorityYellow,
                  onTap: () => context.push('/teacher/classes'),
                ),
                _KpiCard(
                  icon: LucideIcons.clipboardList,
                  title: 'Subject Load',
                  value: assignmentsAsync.maybeWhen(data: (v) => v.length.toString(), orElse: () => '—'),
                  subtitle: 'Class-subject assessment pairs',
                  color: AppTheme.success,
                  onTap: () => context.push('/my-students'),
                ),
                _KpiCard(
                  icon: LucideIcons.mail,
                  title: 'Parent Messages',
                  value: unreadMessages,
                  subtitle: 'Unread messages waiting for attention',
                  color: AppTheme.primarySlate,
                  onTap: () => context.push('/teacher/reports'),
                ),
                if (canMarkAttendance)
                  _KpiCard(
                    icon: LucideIcons.clipboardCheck,
                    title: 'Attendance',
                    value: 'Open',
                    subtitle: 'Mark class attendance',
                    color: AppTheme.primarySlate,
                    onTap: () => context.push('/attendance'),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 28),
          PortalSectionPanel(
            title: 'Important Summary',
            subtitle: 'Your access level, class responsibility, and staff identity at a glance.',
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(LucideIcons.briefcase, color: AppTheme.actionIndigo),
                  title: const Text('Teaching Scope'),
                  subtitle: Text(roleScope),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(LucideIcons.school2, color: AppTheme.authorityYellow),
                  title: const Text('Head/Class Teacher Responsibility'),
                  subtitle: Text(headClassName),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(LucideIcons.badgeCheck, color: AppTheme.success),
                  title: const Text('Staff Identity'),
                  subtitle: Text(
                    staffSummary == null
                        ? 'No linked staff record yet.'
                        : '${staffSummary.staffId} • ${staffSummary.position}${(staffSummary.department?.trim().isNotEmpty ?? false) ? ' • ${staffSummary.department!.trim()}' : ''}',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(LucideIcons.users2, color: AppTheme.textMuted),
                  title: const Text('Head Teacher Learners'),
                  subtitle: Text('${_count(headStudentsAsync)} students in your homeroom/class-teacher scope'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),
          PortalSectionPanel(
            title: 'Next Steps',
            subtitle: 'High-frequency teaching actions, reports, and classroom workflows.',
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(LucideIcons.users, color: AppTheme.actionIndigo),
                  title: const Text('Open My Students & Assessments'),
                  subtitle: const Text('View students and enter assessment scores.'),
                  trailing: const Icon(LucideIcons.chevronRight),
                  onTap: () => context.push('/my-students'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(LucideIcons.school, color: AppTheme.authorityYellow),
                  title: const Text('Browse My Classes'),
                  subtitle: const Text('Jump into a class and open a subject assessment.'),
                  trailing: const Icon(LucideIcons.chevronRight),
                  onTap: () => context.push('/teacher/classes'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(LucideIcons.fileBarChart2, color: AppTheme.textMuted),
                  title: const Text('Reports'),
                  subtitle: const Text('Terminal reports, summaries, exports.'),
                  trailing: const Icon(LucideIcons.chevronRight),
                  onTap: () => context.push('/teacher/reports'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _count<T>(AsyncValue<List<T>> value) {
    return value.maybeWhen(data: (v) => v.length, orElse: () => 0);
  }

  String _roleScopeLabel({required bool canMarkAttendance, required bool isSubjectTeacher}) {
    if (canMarkAttendance && isSubjectTeacher) {
      return 'Head/Class teacher and subject teacher access';
    }
    if (canMarkAttendance) {
      return 'Head/Class teacher access';
    }
    if (isSubjectTeacher) {
      return 'Subject teacher access';
    }
    return 'Teaching access is not fully configured yet';
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _KpiCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.16),
              color.withValues(alpha: 0.08),
              AppTheme.surface.withValues(alpha: 0.98),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: color.withValues(alpha: 0.18),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
