import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:go_router/go_router.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/core/providers/system_settings_providers.dart';
import 'package:ghanaclass_school_management/shared/widgets/portal_surface.dart';

class HeadmasterPortalScreen extends StatelessWidget {
  const HeadmasterPortalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = <_HeadPortalSection>[
      const _HeadPortalSection(
        category: 'Executive Dashboard',
        actions: [
          _PortalAction(label: 'Dashboard', routeName: 'dashboard', icon: Icons.dashboard_outlined),
          _PortalAction(label: 'Finance Analytics', routeName: 'finance_analytics', icon: Icons.query_stats_outlined),
          _PortalAction(label: 'Attendance', routeName: 'attendance', icon: Icons.fact_check_outlined),
          _PortalAction(label: 'Alarms', routeName: 'admin_alarms', icon: Icons.notifications_active_outlined),
        ],
      ),
      const _HeadPortalSection(
        category: 'Financial & Resource Oversight',
        actions: [
          _PortalAction(label: 'Fees', routeName: 'fees', icon: Icons.payments_outlined),
          _PortalAction(label: 'Payments', routeName: 'finance_payments', icon: Icons.receipt_long_outlined),
          _PortalAction(label: 'Expenses', routeName: 'expenses', icon: Icons.savings_outlined),
          _PortalAction(label: 'Payroll', routeName: 'payroll', icon: Icons.request_quote_outlined),
          _PortalAction(label: 'Finance Analytics', routeName: 'finance_analytics', icon: Icons.query_stats_outlined),
          _PortalAction(label: 'Shop Reports', routeName: 'shop_reports', icon: Icons.storefront_outlined),
          _PortalAction(label: 'Canteen Reports', routeName: 'chef_reports', icon: Icons.restaurant_outlined),
        ],
      ),
      const _HeadPortalSection(
        category: 'Academic & Quality Monitoring',
        actions: [
          _PortalAction(label: 'Teacher Reports', routeName: 'teacher_reports', icon: Icons.assessment_outlined),
          _PortalAction(label: 'Classes', routeName: 'classes', icon: Icons.class_outlined),
          _PortalAction(label: 'Subjects', routeName: 'subjects', icon: Icons.menu_book_outlined),
          _PortalAction(label: 'Library', routeName: 'library_portal', icon: Icons.local_library_outlined),
          _PortalAction(label: 'Science Lab', routeName: 'science_lab', icon: Icons.science_outlined),
          _PortalAction(label: 'Infirmary Reports', routeName: 'infirmary_reports', icon: Icons.monitor_heart_outlined),
        ],
      ),
      const _HeadPortalSection(
        category: 'Enrollment & Student Management',
        actions: [
          _PortalAction(label: 'Admissions', routeName: 'admissions', icon: Icons.how_to_reg_outlined),
          _PortalAction(label: 'Students', routeName: 'students', icon: Icons.groups_outlined),
          _PortalAction(label: 'ID Cards', routeName: 'id_cards', icon: Icons.badge_outlined),
        ],
      ),
      const _HeadPortalSection(
        category: 'Staff Leadership & HR',
        actions: [
          _PortalAction(label: 'Staff', routeName: 'staff', icon: Icons.badge_outlined),
          _PortalAction(label: 'Attendance', routeName: 'attendance', icon: Icons.fact_check_outlined),
          _PortalAction(label: 'Payroll', routeName: 'payroll', icon: Icons.request_quote_outlined),
        ],
      ),
      const _HeadPortalSection(
        category: 'Compliance, Safety & Reporting',
        actions: [
          _PortalAction(label: 'Security Incidents', routeName: 'security_incidents', icon: Icons.shield_outlined),
          _PortalAction(label: 'Infirmary Reports', routeName: 'infirmary_reports', icon: Icons.monitor_heart_outlined),
          _PortalAction(label: 'Science Lab Reports', routeName: 'science_lab_reports', icon: Icons.science_outlined),
          _PortalAction(label: 'ICT Lab Reports', routeName: 'ict_lab_reports', icon: Icons.computer_outlined),
          _PortalAction(label: 'Teacher Reports', routeName: 'teacher_reports', icon: Icons.assessment_outlined),
        ],
      ),
      const _HeadPortalSection(
        category: 'Approvals & Governance',
        actions: [
          _PortalAction(label: 'Admissions', routeName: 'admissions', icon: Icons.how_to_reg_outlined),
          _PortalAction(label: 'Expenses', routeName: 'expenses', icon: Icons.savings_outlined),
          _PortalAction(label: 'Fees', routeName: 'fees', icon: Icons.payments_outlined),
          _PortalAction(label: 'Staff', routeName: 'staff', icon: Icons.badge_outlined),
        ],
      ),
      const _HeadPortalSection(
        category: 'Alerts & Proactive Tools',
        actions: [
          _PortalAction(label: 'Alarms', routeName: 'admin_alarms', icon: Icons.notifications_active_outlined),
          _PortalAction(label: 'Inventory', routeName: 'shop_inventory', icon: Icons.inventory_2_outlined),
          _PortalAction(label: 'Canteen Orders', routeName: 'chef_orders', icon: Icons.shopping_bag_outlined),
          _PortalAction(label: 'Attendance', routeName: 'attendance', icon: Icons.fact_check_outlined),
        ],
      ),
      const _HeadPortalSection(
        category: 'Security & Audit',
        actions: [
          _PortalAction(label: 'Settings', routeName: 'settings', icon: Icons.settings_outlined),
          _PortalAction(label: 'Security/Compliance', routeName: 'accountant_security', icon: Icons.verified_user_outlined),
        ],
      ),
    ];

    return _HeadmasterPortalLayout(sections: sections);
  }
}

class _HeadmasterPortalLayout extends ConsumerStatefulWidget {
  const _HeadmasterPortalLayout({required this.sections});

  final List<_HeadPortalSection> sections;

  @override
  ConsumerState<_HeadmasterPortalLayout> createState() => _HeadmasterPortalLayoutState();
}

class _HeadmasterPortalLayoutState extends ConsumerState<_HeadmasterPortalLayout> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final sections = widget.sections;
    final selected = sections[_selectedIndex.clamp(0, sections.length - 1)];
    final currentUser = ref.watch(currentUserProvider);
    final academicYear = ref.watch(activeYearProvider);
    final term = ref.watch(activeTermProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1140),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 980;
                final navigationPanel = PortalSectionPanel(
                  title: 'Leadership Lanes',
                  subtitle: 'Select the operating lane to open its leadership actions.',
                  child: Column(
                    children: [
                      for (var index = 0; index < sections.length; index++) ...[
                        if (index != 0) const Divider(height: 1),
                        Builder(
                          builder: (context) {
                            final section = sections[index];
                            final isSelected = index == _selectedIndex;
                            return ListTile(
                              title: Text(
                                section.category,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                ),
                              ),
                              selected: isSelected,
                              selectedTileColor: AppTheme.actionIndigo.withValues(alpha: 0.10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              onTap: () => setState(() => _selectedIndex = index),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                );
                final actionPanel = PortalSectionPanel(
                  title: selected.category,
                  subtitle: 'Leadership actions for this area of responsibility.',
                  child: LayoutBuilder(
                    builder: (context, innerConstraints) {
                      double cardWidth = (innerConstraints.maxWidth - 16) / 2;
                      if (innerConstraints.maxWidth < 620) {
                        cardWidth = innerConstraints.maxWidth;
                      }
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          for (var index = 0; index < selected.actions.length; index++)
                            SizedBox(
                              width: cardWidth,
                              height: 168,
                              child: PortalActionCard(
                                title: selected.actions[index].label,
                                subtitle: 'Open ${selected.actions[index].label.toLowerCase()} workflows and reports.',
                                icon: selected.actions[index].icon,
                                onTap: () {
                                  try {
                                    context.goNamed(selected.actions[index].routeName);
                                  } catch (_) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('This module is not available yet.'),
                                        backgroundColor: Colors.orange,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                                primary: const Color(0xFF7C3AED),
                                accent: index.isEven ? const Color(0xFF0EA5E9) : const Color(0xFFF59E0B),
                                badge: 'Leadership',
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PortalHeroBanner(
                      eyebrow: 'Headmaster portal',
                      title: 'Academic Leadership & School Operations',
                      subtitle: '${currentUser?.fullName ?? 'School leader'} is coordinating academics, staffing, enrollment, safety, and governance for the active school term.',
                      icon: Icons.workspace_premium_outlined,
                      primary: const Color(0xFF7C3AED),
                      accent: const Color(0xFF0EA5E9),
                      metrics: [
                        PortalHeroMetric(label: 'Academic year', value: '$academicYear'),
                        PortalHeroMetric(label: 'Active term', value: 'Term $term'),
                        PortalHeroMetric(label: 'Leadership lanes', value: '${sections.length}'),
                      ],
                    ),
                    const SizedBox(height: 24),
                    stacked
                        ? Column(
                            children: [
                              navigationPanel,
                              const SizedBox(height: 16),
                              actionPanel,
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 320, child: navigationPanel),
                              const SizedBox(width: 16),
                              Expanded(child: actionPanel),
                            ],
                          ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HeadPortalSection {
  final String category;
  final List<_PortalAction> actions;

  const _HeadPortalSection({
    required this.category,
    this.actions = const [],
  });
}

class _PortalAction {
  final String label;
  final String routeName;
  final IconData icon;

  const _PortalAction({
    required this.label,
    required this.routeName,
    required this.icon,
  });
}
