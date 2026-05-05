import 'widgets/data_access_analytics_card.dart';
import 'widgets/audit_logs_analytics_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:go_router/go_router.dart';
import 'package:ghanaclass_school_management/core/providers/activity_providers.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';
import 'package:ghanaclass_school_management/core/router/role_routes.dart';
import 'widgets/stat_card.dart';
import 'widgets/revenue_chart.dart';
import 'widgets/resource_utilization_card.dart';
import 'widgets/user_configurable_dashboard.dart';
import 'package:ghanaclass_school_management/core/providers/admin_oversight_providers.dart';
import 'package:ghanaclass_school_management/core/providers/system_settings_providers.dart';
import 'activity_logs_screen.dart';
import 'package:ghanaclass_school_management/shared/widgets/portal_surface.dart';


class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(recentActivitiesProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(24.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildHeader(context, ref),
                const SizedBox(height: 24),
                _buildQuickActions(context),
                const SizedBox(height: 32),
                _buildStatsGrid(context, ref),
                const SizedBox(height: 32),
                // --- Resource Utilization Analytics Card ---
                const ResourceUtilizationCard(),
                const SizedBox(height: 32),
                // --- Audit Logs Analytics Card ---
                const AuditLogsAnalyticsCard(),
                const SizedBox(height: 32),
                // --- Data Access Analytics Card ---
                const DataAccessAnalyticsCard(),
                const SizedBox(height: 32),
                // --- End Data Access Analytics Card ---
                _buildMainContent(context, activitiesAsync),
              ]),
            ),
          ),
        ],
      ),
    );
  }

// ...existing code...
  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final roleName = currentUser?.role ?? '';
    final academicYear = ref.watch(activeYearProvider);
    final term = ref.watch(activeTermProvider);

    String overviewTitle() {
      if (roleNameIsOneOf(roleName, const [UserRole.headmaster, UserRole.headmistress])) {
        return 'Headmaster/Headmistress Overview';
      }
      if (roleNameIsOneOf(roleName, const [UserRole.deputyheadmaster, UserRole.deputyheadmistress])) {
        return 'Deputy Master/Mistress Overview';
      }
      return 'Admin Overview';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PortalHeroBanner(
          eyebrow: roleNameIsOneOf(roleName, const [UserRole.headmaster, UserRole.headmistress])
              ? 'School leadership portal'
              : 'Administrative command center',
          title: overviewTitle(),
          subtitle: '${currentUser?.fullName ?? 'Signed-in user'} is viewing live school operations, finance, and compliance for the active academic cycle.',
          icon: LucideIcons.layoutDashboard,
          primary: const Color(0xFF4F46E5),
          accent: const Color(0xFFF59E0B),
          metrics: [
            PortalHeroMetric(label: 'Academic year', value: '$academicYear'),
            PortalHeroMetric(label: 'Active term', value: 'Term $term'),
            PortalHeroMetric(label: 'Portal role', value: roleName.isEmpty ? 'Admin' : roleName),
          ],
        ),
        const SizedBox(height: 16),
        const PortalSectionPanel(
          title: 'Workspace Modules',
          subtitle: 'Pinned operational widgets, KPIs, and analytics tailored to this portal.',
          child: UserConfigurableDashboard(),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _QuickActionButton(
            icon: LucideIcons.userPlus,
            label: 'Register Student',
            onTap: () => context.go('/students/admission'),
          ),
          const SizedBox(width: 12),
          _QuickActionButton(
            icon: LucideIcons.userCheck,
            label: 'Register Staff',
            onTap: () => context.go('/staff/admission'),
          ),
          const SizedBox(width: 12),
          _QuickActionButton(
            icon: LucideIcons.banknote,
            label: 'Define Fees',
            onTap: () => context.go('/finance/fees'),
          ),
          const SizedBox(width: 12),
          _QuickActionButton(
            icon: LucideIcons.creditCard,
            label: 'ID Card Center',
            onTap: () => context.go('/id-cards'),
          ),
          const SizedBox(width: 12),
          _QuickActionButton(
            icon: LucideIcons.fileText,
            label: 'Generate Exam',
            onTap: () => context.go('/exams/generate'),
          ),
          const SizedBox(width: 12),
          _QuickActionButton(
            icon: LucideIcons.settings,
            label: 'System Settings',
            onTap: () => context.go('/settings'),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 200.ms).slideY(begin: 0.05);
  }

  Widget _buildStatsGrid(BuildContext context, WidgetRef ref) {
    final kpisAsync = ref.watch(adminKpisProvider);

    return kpisAsync.when(
      data: (kpis) => LayoutBuilder(
        builder: (context, constraints) {
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildResponsiveCard(
                constraints,
                StatCard(
                  title: 'Total Students',
                  value: kpis.totalStudents.toString(),
                  subtitle: 'Academic Year ${ref.watch(activeYearProvider)}',
                  icon: LucideIcons.graduationCap,
                  color: const Color(0xFF6366F1), // Indigo
                ),
              ),
              _buildResponsiveCard(
                constraints,
                StatCard(
                  title: 'Total Staff',
                  value: kpis.totalStaff.toString(),
                  subtitle: 'All Roles',
                  icon: LucideIcons.userCheck,
                  color: const Color(0xFFEC4899), // Pink
                ),
              ),
              _buildResponsiveCard(
                constraints,
                StatCard(
                  title: 'Today\'s Attendance',
                  value: '${kpis.attendanceRate.toStringAsFixed(1)}%',
                  subtitle: 'Global Avg',
                  icon: LucideIcons.calendarCheck,
                  color: const Color(0xFF10B981), // Emerald
                ),
              ),
              _buildResponsiveCard(
                constraints,
                StatCard(
                  title: 'Total Revenue',
                  value: 'GH₵ ${kpis.totalRevenue.toStringAsFixed(0)}',
                  subtitle: 'Term ${ref.watch(activeTermProvider)}',
                  icon: LucideIcons.banknote,
                  color: const Color(0xFFF59E0B), // Amber
                ),
              ),
            ],
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    ).animate().fadeIn(duration: 600.ms, delay: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildResponsiveCard(BoxConstraints constraints, Widget child) {
    // Basic responsive implementation: on wide screens 4 cards, narrow screens 2 or 1
    double width = (constraints.maxWidth - 3 * 16) / 4; // 4 columns
    if (constraints.maxWidth < 1100) width = (constraints.maxWidth - 16) / 2; // 2 columns
    if (constraints.maxWidth < 600) width = constraints.maxWidth; // 1 column

    return SizedBox(
      width: width,
      height: 160,
      child: child,
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    AsyncValue<List<ActivityLog>> activitiesAsync,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                flex: 2,
                child: SizedBox(
                  height: 400,
                  child: RevenueChart(),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 400,
                  child: _RecentActivityPanel(activitiesAsync: activitiesAsync),
                ),
              ),
            ],
          );
        } else {
          return Column(
            children: [
              const SizedBox(
                height: 400,
                child: RevenueChart(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 400,
                child: _RecentActivityPanel(activitiesAsync: activitiesAsync),
              ),
            ],
          );
        }
      },
    ).animate().fadeIn(duration: 800.ms, delay: 600.ms);
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: PortalActionCard(
        title: label,
        subtitle: 'Open and continue this workflow.',
        icon: icon,
        onTap: onTap,
        primary: AppTheme.actionIndigo,
        accent: AppTheme.authorityYellow,
      ),
    );
  }
}

class _RecentActivityPanel extends StatelessWidget {
  final AsyncValue<List<ActivityLog>> activitiesAsync;

  const _RecentActivityPanel({required this.activitiesAsync});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Activity',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ActivityLogsScreen()),
                    );
                  },
                  child: const Text('View All', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: activitiesAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        'No recent activity yet.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppTheme.textMuted),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, index) => const Divider(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _ActivityTile(log: item);
                    },
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                error: (err, stack) => Center(
                  child: Text(
                    'Failed to load activities',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.error),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final ActivityLog log;

  const _ActivityTile({required this.log});

  IconData _iconForModule() {
    switch (log.module) {
      case 'students':
        return LucideIcons.users;
      case 'finance':
        return LucideIcons.banknote;
      case 'staff':
        return LucideIcons.userCheck;
      default:
        return LucideIcons.activity;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppTheme.surfaceMuted,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _iconForModule(),
            size: 16,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                log.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 2),
              Text(
                '${log.actorName} • ${log.actorRole.toUpperCase()}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppTheme.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

