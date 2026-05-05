import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/core/providers/system_settings_providers.dart';
import 'package:ghanaclass_school_management/features/academic/academic_providers.dart';
import 'package:ghanaclass_school_management/features/staff/staff_providers.dart';
import 'package:ghanaclass_school_management/features/teachers/teacher_providers.dart';
import 'package:ghanaclass_school_management/features/teachers/teacher_service.dart';
import 'package:ghanaclass_school_management/shared/widgets/portal_surface.dart';

class TeacherProfileScreen extends ConsumerWidget {
  const TeacherProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final staffProfileAsync = ref.watch(currentStaffProfileProvider);
    final academicYear = ref.watch(activeYearProvider);
    final term = ref.watch(activeTermProvider);
    final assignmentsAsync = ref.watch(teacherAssignmentsProvider);
    final classesAsync = ref.watch(classesProvider);
    final subjectsAsync = ref.watch(subjectsProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final userRole = UserRole.values.firstWhere(
      (r) => r.name == user.role,
      orElse: () => UserRole.teacher,
    );

    final staffProfile = staffProfileAsync.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    final staff = staffProfile?.staff;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          PortalHeroBanner(
            eyebrow: 'Teacher profile',
            title: user.fullName,
            subtitle: 'Teaching identity, assignments, and account status for the active school cycle.',
            icon: LucideIcons.school,
            primary: AppTheme.actionIndigo,
            accent: AppTheme.success,
            metrics: [
              PortalHeroMetric(label: 'Academic year', value: '$academicYear'),
              PortalHeroMetric(label: 'Active term', value: 'Term $term'),
              PortalHeroMetric(label: 'Role', value: userRole.displayName),
              PortalHeroMetric(label: 'Staff ID', value: staff?.staffId ?? '—'),
            ],
          ),
          const SizedBox(height: 16),

          PortalSectionPanel(
            title: 'Account Summary',
            subtitle: 'Status, contact details, and access timing for this teacher account.',
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(LucideIcons.mail, color: AppTheme.textMuted),
                  title: const Text('Portal Email'),
                  subtitle: Text(user.email),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(LucideIcons.phone, color: AppTheme.textMuted),
                  title: const Text('Phone'),
                  subtitle: Text(_orDash(staff?.phoneNumber, fallback: user.phoneNumber)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(user.isActive ? LucideIcons.badgeCheck : LucideIcons.badgeX, color: user.isActive ? AppTheme.success : Colors.red),
                  title: const Text('Account Status'),
                  subtitle: Text(user.isActive ? 'Active' : 'Inactive'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(LucideIcons.clock, color: AppTheme.textMuted),
                  title: const Text('Last Login'),
                  subtitle: Text(_formatDateTime(user.lastLoginAt)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(LucideIcons.calendar, color: AppTheme.textMuted),
                  title: const Text('Joined'),
                  subtitle: Text(_formatDateTime(user.createdAt)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          PortalSectionPanel(
            title: 'Staff Details',
            subtitle: 'Full staff record linked to this teacher account.',
            child: staff == null
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No linked staff record was found for this account yet.',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  )
                : Column(
                    children: [
                      _DetailRow(
                        icon: LucideIcons.badge,
                        title: 'Staff ID',
                        value: staff.staffId,
                      ),
                      const Divider(height: 1),
                      _DetailRow(
                        icon: LucideIcons.user,
                        title: 'Full Name',
                        value: '${staff.firstName} ${staff.lastName}'.trim(),
                      ),
                      const Divider(height: 1),
                      _DetailRow(
                        icon: LucideIcons.briefcase,
                        title: 'Position',
                        value: _orDash(staff.position),
                      ),
                      const Divider(height: 1),
                      _DetailRow(
                        icon: LucideIcons.building2,
                        title: 'Department',
                        value: _orDash(staff.department),
                      ),
                      const Divider(height: 1),
                      _DetailRow(
                        icon: LucideIcons.users,
                        title: 'Gender',
                        value: _titleCase(staff.gender),
                      ),
                      const Divider(height: 1),
                      _DetailRow(
                        icon: LucideIcons.calendarDays,
                        title: 'Date of Birth',
                        value: _formatDate(staff.dateOfBirth),
                      ),
                      const Divider(height: 1),
                      _DetailRow(
                        icon: LucideIcons.mapPin,
                        title: 'Address',
                        value: _orDash(staff.address),
                      ),
                      const Divider(height: 1),
                      _DetailRow(
                        icon: LucideIcons.phoneCall,
                        title: 'Emergency Contact',
                        value: _orDash(staff.emergencyContact),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          PortalSectionPanel(
            title: 'Employment & Contract',
            subtitle: 'Employment status, salary, contract window, and qualifications.',
            child: staff == null
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Employment details will appear when the staff record is available.',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  )
                : Column(
                    children: [
                      _DetailRow(
                        icon: LucideIcons.calendar,
                        title: 'Hire Date',
                        value: _formatDate(staff.hireDate),
                      ),
                      const Divider(height: 1),
                      _DetailRow(
                        icon: LucideIcons.wallet,
                        title: 'Base Salary',
                        value: 'GHS ${staff.baseSalary.toStringAsFixed(2)}',
                      ),
                      const Divider(height: 1),
                      _DetailRow(
                        icon: LucideIcons.fileText,
                        title: 'Contract Type',
                        value: _orDash(staff.contractType),
                      ),
                      const Divider(height: 1),
                      _DetailRow(
                        icon: LucideIcons.calendarRange,
                        title: 'Contract Start',
                        value: _formatDate(staff.contractStartDate),
                      ),
                      const Divider(height: 1),
                      _DetailRow(
                        icon: LucideIcons.calendarClock,
                        title: 'Contract End',
                        value: _formatDate(staff.contractEndDate),
                      ),
                      const Divider(height: 1),
                      _DetailRow(
                        icon: LucideIcons.graduationCap,
                        title: 'Qualifications',
                        value: _orDash(staff.qualifications),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          PortalSectionPanel(
            title: 'Teaching Assignments',
            subtitle: 'Classes and subjects currently assigned to this teacher.',
            child: assignmentsAsync.when(
              data: (assignments) {
                if (assignments.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(LucideIcons.info, color: AppTheme.textMuted.withValues(alpha: 0.8)),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'No class or subject assignments found yet. Ask an admin to assign you.',
                            style: TextStyle(color: AppTheme.textMuted),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final byClass = <int, List<TeacherClassSubjectAccess>>{};
                for (final assignment in assignments) {
                  byClass.putIfAbsent(assignment.classId, () => []).add(assignment);
                }

                final classIds = byClass.keys.toList()..sort();

                return Column(
                  children: [
                    for (final classId in classIds) ...[
                      _AssignmentClassTile(
                        classId: classId,
                        items: byClass[classId] ?? const [],
                        classesAsync: classesAsync,
                        subjectsAsync: subjectsAsync,
                      ),
                      if (classId != classIds.last) const Divider(height: 1),
                    ],
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, s) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error loading assignments: $e'),
              ),
            ),
          ),

        ],
      ),
    );
  }

  static String _formatDateTime(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    final yyyy = local.year.toString().padLeft(4, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mi = local.minute.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd $hh:$mi';
  }

  static String _formatDate(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    final yyyy = local.year.toString().padLeft(4, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  static String _orDash(String? value, {String? fallback}) {
    final primary = value?.trim();
    if (primary != null && primary.isNotEmpty) return primary;
    final secondary = fallback?.trim();
    if (secondary != null && secondary.isNotEmpty) return secondary;
    return '—';
  }

  static String _titleCase(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '—';
    return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.textMuted),
      title: Text(title),
      subtitle: Text(value),
    );
  }
}

class _AssignmentClassTile extends StatelessWidget {
  final int classId;
  final List<TeacherClassSubjectAccess> items;
  final AsyncValue<List<SchoolClassesData>> classesAsync;
  final AsyncValue<List<SchoolSubject>> subjectsAsync;

  const _AssignmentClassTile({
    required this.classId,
    required this.items,
    required this.classesAsync,
    required this.subjectsAsync,
  });

  @override
  Widget build(BuildContext context) {
    final className = classesAsync.whenData((list) {
          final found = list.where((c) => c.id == classId).firstOrNull;
          return found?.className ?? 'Class $classId';
        }).value ??
        'Class $classId';

    final subjectChips = items.map((a) {
      final subjectName = subjectsAsync.whenData((list) {
            final found = list.where((s) => s.id == a.subjectId).firstOrNull;
            return found?.subjectName ?? 'Subject ${a.subjectId}';
          }).value ??
          'Subject ${a.subjectId}';

      return Chip(
        avatar: Icon(
          a.viaHeadTeacherRole ? LucideIcons.star : LucideIcons.bookOpen,
          size: 16,
          color: a.viaHeadTeacherRole ? AppTheme.success : AppTheme.actionIndigo,
        ),
        label: Text(subjectName),
        backgroundColor: (a.viaHeadTeacherRole ? AppTheme.success : AppTheme.actionIndigo).withValues(alpha: 0.08),
        side: BorderSide(color: (a.viaHeadTeacherRole ? AppTheme.success : AppTheme.actionIndigo).withValues(alpha: 0.20)),
      );
    }).toList(growable: false);

    return ListTile(
      leading: const Icon(LucideIcons.school, color: AppTheme.authorityYellow),
      title: Text(className, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Wrap(spacing: 8, runSpacing: 8, children: subjectChips),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
