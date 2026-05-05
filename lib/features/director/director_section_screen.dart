import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:drift/drift.dart' as drift;
import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';
import 'package:ghanaclass_school_management/core/providers/system_settings_providers.dart';
import 'package:ghanaclass_school_management/features/academic/academic_providers.dart';
import 'package:ghanaclass_school_management/features/finance/finance_analytics_providers.dart';
import 'package:ghanaclass_school_management/features/finance/finance_providers.dart' show FinanceExpenseEntry, combinedExpensesProvider;
import 'package:ghanaclass_school_management/features/director/director_budget_service.dart';
import 'package:ghanaclass_school_management/features/director/director_kpi_providers.dart';
import 'package:ghanaclass_school_management/features/director/director_kpi_service.dart';
import 'package:ghanaclass_school_management/features/director/director_budget_providers.dart';
import 'package:ghanaclass_school_management/features/director/director_communication_providers.dart';
import 'package:ghanaclass_school_management/features/director/director_communication_service.dart';
import 'package:ghanaclass_school_management/features/director/director_notifications_settings_providers.dart';
import 'package:ghanaclass_school_management/features/director/director_workflow_providers.dart';
import 'package:ghanaclass_school_management/features/director/director_workflow_service.dart';
import 'package:ghanaclass_school_management/features/director/director_sections.dart';
import 'package:ghanaclass_school_management/features/dashboard/widgets/resource_utilization_card.dart';
import 'package:ghanaclass_school_management/features/dashboard/widgets/audit_logs_analytics_card.dart';
import 'package:ghanaclass_school_management/features/dashboard/widgets/data_access_analytics_card.dart';
import 'package:printing/printing.dart';
import 'package:ghanaclass_school_management/shared/printing/pdf_preview_screen.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class DirectorSectionScreen extends ConsumerWidget {
  const DirectorSectionScreen({
    super.key,
    required this.sectionId,
  });

  final String sectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = directorSectionById(sectionId);
    final academicYear = ref.watch(activeYearProvider);
    final term = ref.watch(activeTermProvider);

    if (section == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Director')),
        body: const Center(
          child: Text('Section not found.', style: TextStyle(color: AppTheme.textMuted)),
        ),
      );
    }

    final kpisAsync = ref.watch(directorKpisProvider);
    final tone = _toneForSection(section.id);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [tone.primary, tone.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: tone.primary.withValues(alpha: 0.22),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(Icons.workspace_premium_outlined, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(section.title),
                Text(
                  'Academic Year $academicYear  •  Term $term',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              tone.primary.withValues(alpha: 0.08),
              tone.accent.withValues(alpha: 0.03),
              AppTheme.background,
              AppTheme.background,
            ],
            stops: const [0, 0.18, 0.46, 1],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -20,
              child: IgnorePointer(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [tone.accent.withValues(alpha: 0.26), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 120,
              left: -60,
              child: IgnorePointer(
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [tone.primary.withValues(alpha: 0.12), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1140),
                  child: kpisAsync.when(
                    data: (kpis) => ListView(
                      children: [
                        _DirectorHero(
                          section: section,
                          kpis: kpis,
                          academicYear: academicYear,
                          term: term,
                          tone: tone,
                        ),
                        const SizedBox(height: 18),
                        for (var index = 0; index < section.features.length; index++) ...[
                          _FeatureCard(
                            feature: section.features[index],
                            kpis: kpis,
                            tone: tone,
                            featureIndex: index,
                          ),
                          if (index != section.features.length - 1) const SizedBox(height: 16),
                        ],
                      ],
                    ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Center(
                      child: Text('Could not load KPIs: $e', style: const TextStyle(color: AppTheme.textMuted)),
                    ),
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

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.feature,
    required this.kpis,
    required this.tone,
    required this.featureIndex,
  });

  final DirectorFeature feature;
  final DirectorKpis kpis;
  final _DirectorVisualTone tone;
  final int featureIndex;

  @override
  Widget build(BuildContext context) {
    final featureAccent = _featureAccent(feature.kind, tone, featureIndex);
    final description = _featureDescription(feature.kind, feature.title);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: featureAccent.withValues(alpha: 0.18)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            featureAccent.withValues(alpha: 0.05),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: tone.primary.withValues(alpha: 0.06),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [featureAccent, tone.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Icon(_featureIcon(feature.kind), color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feature.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted, height: 1.35),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: featureAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: featureAccent.withValues(alpha: 0.16)),
                  ),
                  child: Text(
                    'Module ${featureIndex + 1}',
                    style: TextStyle(color: featureAccent, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _FeatureBody(kind: feature.kind, kpis: kpis),
          ],
        ),
      ),
    );
  }
}

class _DirectorHero extends StatelessWidget {
  const _DirectorHero({
    required this.section,
    required this.kpis,
    required this.academicYear,
    required this.term,
    required this.tone,
  });

  final DirectorSection section;
  final DirectorKpis kpis;
  final int academicYear;
  final int term;
  final _DirectorVisualTone tone;

  String _fmtInt(int v) => NumberFormat.decimalPattern().format(v);
  String _fmtPercent(double v) => '${v.toStringAsFixed(1)}%';
  String _fmtMoney(double v) => 'GH₵ ${NumberFormat('#,##0').format(v)}';

  @override
  Widget build(BuildContext context) {
    final metrics = _heroMetricsForSection(section.id, kpis, _fmtInt, _fmtPercent, _fmtMoney);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tone.primary, tone.secondary],
        ),
        boxShadow: [
          BoxShadow(
            color: tone.primary.withValues(alpha: 0.24),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                  ),
                  child: const Text(
                    'Director Portal',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                  ),
                  child: Text(
                    'Academic Year $academicYear • Term $term',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              section.title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Text(
                _sectionDescription(section),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.84),
                      height: 1.45,
                    ),
              ),
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final metric in metrics)
                  _HeroMetricCard(metric: metric),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroMetricCard extends StatelessWidget {
  const _HeroMetricCard({required this.metric});

  final ({String label, String value, IconData icon}) metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(metric.icon, color: Colors.white.withValues(alpha: 0.9), size: 18),
          const SizedBox(height: 14),
          Text(metric.label, style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            metric.value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22),
          ),
        ],
      ),
    );
  }
}

class _FeatureBody extends StatelessWidget {
  const _FeatureBody({required this.kind, required this.kpis});

  final DirectorFeatureKind kind;
  final DirectorKpis kpis;

  String _fmtInt(int v) => NumberFormat.decimalPattern().format(v);

  String _fmtPercent(double v) => '${v.toStringAsFixed(1)}%';

  String _fmtMoney(double v) => 'GH₵ ${NumberFormat('#,##0').format(v)}';

  String _fmtDateTime(DateTime dt) => DateFormat('yyyy-MM-dd HH:mm').format(dt);

  Color _varianceColor(double value) => value >= 0 ? Colors.green.shade700 : Colors.red.shade700;

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case DirectorFeatureKind.budget:
        return const _BudgetEditor(mode: _BudgetEditorMode.budget);
      case DirectorFeatureKind.dashboard:
        return _KpiGrid(
          items: [
            _KpiItem(label: 'Enrollment', value: _fmtInt(kpis.totalStudents)),
            _KpiItem(label: 'Attendance', value: _fmtPercent(kpis.studentAttendanceRateToday)),
            _KpiItem(label: 'Fees', value: _fmtPercent(kpis.feesCollectionRate)),
            _KpiItem(label: 'Staff', value: _fmtInt(kpis.totalStaff)),
            _KpiItem(label: 'Projected Balance', value: _fmtMoney(kpis.projectedTermBalance)),
            _KpiItem(label: 'Actual Income', value: _fmtMoney(kpis.actualTermIncome), valueColor: Colors.green.shade700),
            _KpiItem(label: 'Actual Expenses', value: _fmtMoney(kpis.actualTermExpenses), valueColor: Colors.deepOrange.shade700),
            _KpiItem(label: 'Balance Variance', value: _fmtMoney(kpis.termBalanceVariance), valueColor: _varianceColor(kpis.termBalanceVariance)),
            _KpiItem(label: 'Budget Snapshots', value: _fmtInt(kpis.budgetSnapshotCount)),
          ],
        );
      case DirectorFeatureKind.financeAnalytics:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _FinanceAnalyticsPanel(),
            SizedBox(height: 12),
            _BudgetEditor(mode: _BudgetEditorMode.analytics),
          ],
        );
      case DirectorFeatureKind.attendanceOverview:
        return _ProgressStat(
          label: 'Today',
          progress: kpis.studentAttendanceRateToday / 100.0,
          valueText: _fmtPercent(kpis.studentAttendanceRateToday),
        );
      case DirectorFeatureKind.customWidgets:
        return const _CustomWidgetsPanel();

      case DirectorFeatureKind.feesLedger:
        return _TwoColumnStats(
          leftLabel: 'Expected',
          leftValue: _fmtMoney(kpis.feesExpected),
          rightLabel: 'Collected',
          rightValue: _fmtMoney(kpis.feesCollected),
        );
      case DirectorFeatureKind.expenses:
        return const _BudgetEditor(mode: _BudgetEditorMode.expenses);
      case DirectorFeatureKind.payroll:
        return _TwoColumnStats(
          leftLabel: 'Net total',
          leftValue: _fmtMoney(kpis.payrollNetThisMonth),
          rightLabel: 'Allowances',
          rightValue: _fmtMoney(kpis.payrollAllowancesThisMonth),
        );
      case DirectorFeatureKind.approvalsLargeExpenses:
        return const _ApprovalsPanel(showCreate: true, defaultCategory: 'expense');

      case DirectorFeatureKind.students:
        return _SimpleStat(label: 'Total students', value: _fmtInt(kpis.totalStudents));
      case DirectorFeatureKind.admissions:
        return _SimpleStat(label: 'Admissions (this year)', value: _fmtInt(kpis.admissionsThisYear));
      case DirectorFeatureKind.retention:
        return _ProgressStat(
          label: 'Retention',
          progress: kpis.retentionRate / 100.0,
          valueText: _fmtPercent(kpis.retentionRate),
        );
      case DirectorFeatureKind.demographics:
        return _KpiGrid(
          items: [
            _KpiItem(label: 'Male', value: _fmtInt(kpis.maleStudents)),
            _KpiItem(label: 'Female', value: _fmtInt(kpis.femaleStudents)),
            _KpiItem(label: 'Repeaters', value: _fmtInt(kpis.repeaters)),
            _KpiItem(label: 'New', value: _fmtInt(kpis.newStudentsThisYear)),
          ],
        );

      case DirectorFeatureKind.teacherReports:
        return _SimpleStat(label: 'Reports (this term)', value: _fmtInt(kpis.reportSummariesThisTerm));
      case DirectorFeatureKind.classes:
        return _SimpleStat(label: 'Classes', value: _fmtInt(kpis.classesThisYear));
      case DirectorFeatureKind.subjects:
        return _SimpleStat(label: 'Subjects', value: _fmtInt(kpis.activeSubjects));
      case DirectorFeatureKind.studentProfiles:
        return _SimpleStat(label: 'Profiles', value: _fmtInt(kpis.totalStudents));

      case DirectorFeatureKind.staff:
        return _SimpleStat(label: 'Staff', value: _fmtInt(kpis.totalStaff));
      case DirectorFeatureKind.staffAttendance:
        return _ProgressStat(
          label: 'Present',
          progress: kpis.staffAttendanceRateToday / 100.0,
          valueText: _fmtPercent(kpis.staffAttendanceRateToday),
        );
      case DirectorFeatureKind.staffAppraisals:
        return const _StaffAppraisalsPanel();

      case DirectorFeatureKind.reportsFinance:
        return const _FinanceReportsPanel();
      case DirectorFeatureKind.complianceChecklists:
        return const _ComplianceChecklistPanel();
      case DirectorFeatureKind.customReportBuilder:
        return const _CustomReportBuilderPanel();
      case DirectorFeatureKind.export:
        return const _ExportPanel();

      case DirectorFeatureKind.resourceUtilizationLabs:
        return const ResourceUtilizationCard();
      case DirectorFeatureKind.auditLogs:
        return const AuditLogsAnalyticsCard();
      case DirectorFeatureKind.dataAccess:
        return const DataAccessAnalyticsCard();

      case DirectorFeatureKind.broadcast:
        return const _BroadcastPanel();
      case DirectorFeatureKind.communicationLogs:
        return const _CommunicationLogsPanel();
      case DirectorFeatureKind.emergencyAlerts:
        return const _EmergencyAlertsPanel();

      case DirectorFeatureKind.approveRequests:
        return const _ApprovalsPanel(showCreate: true);
      case DirectorFeatureKind.overrides:
        return const _ApprovalsPanel(showCreate: true, defaultCategory: 'override');
      case DirectorFeatureKind.taskDelegation:
        return const _DelegationPanel();

      case DirectorFeatureKind.realTimeAlerts:
        return _SimpleStat(label: 'Open alerts', value: _fmtInt(kpis.openAlerts));
      case DirectorFeatureKind.alertThresholds:
        return const _AlertThresholdsPanel();
      case DirectorFeatureKind.summaryEmails:
        return const _SummaryEmailsPanel();

      case DirectorFeatureKind.auditCompliance:
        return _SimpleStat(label: 'Audit events', value: _fmtInt(kpis.auditEvents));
      case DirectorFeatureKind.roleManagement:
        return const _RoleManagementPanel();
      case DirectorFeatureKind.settings:
        return _SimpleStat(label: 'Status', value: kpis.settingsStatus);
      case DirectorFeatureKind.offlineSync:
        return _SimpleStat(
          label: 'Last sync',
          value: kpis.lastSyncAt == null ? 'Never' : _fmtDateTime(kpis.lastSyncAt!),
        );
    }
  }
}

class _FinanceAnalyticsPanel extends ConsumerWidget {
  const _FinanceAnalyticsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(activeYearProvider);
    final incomeAsync = ref.watch(monthlyIncomeProvider(year));
    final expenseAsync = ref.watch(monthlyExpensesProvider(year));

    return incomeAsync.when(
      data: (income) => expenseAsync.when(
        data: (expense) {
          final all = <int>{...income.keys, ...expense.keys}.toList()..sort();
          final months = all.isEmpty ? List<int>.generate(12, (i) => i + 1) : all;
          final incomeSpots = months.map((m) => FlSpot(m.toDouble(), income[m] ?? 0)).toList(growable: false);
          final expenseSpots = months.map((m) => FlSpot(m.toDouble(), expense[m] ?? 0)).toList(growable: false);

          return SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 56)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, meta) {
                        const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                        final m = v.toInt();
                        if (m >= 1 && m <= 12) {
                          return Text(months[m], style: const TextStyle(fontSize: 10, color: AppTheme.textMuted));
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 1,
                maxX: 12,
                lineBarsData: [
                  LineChartBarData(
                    spots: incomeSpots,
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: Colors.green.withValues(alpha: 0.08)),
                  ),
                  LineChartBarData(
                    spots: expenseSpots,
                    isCurved: true,
                    color: Colors.red,
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: Colors.red.withValues(alpha: 0.08)),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
        error: (e, s) => Text('Could not load expenses: $e', style: const TextStyle(color: AppTheme.textMuted)),
      ),
      loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
      error: (e, s) => Text('Could not load income: $e', style: const TextStyle(color: AppTheme.textMuted)),
    );
  }
}

class _FinanceReportsPanel extends ConsumerWidget {
  const _FinanceReportsPanel();

  String _fmtMoney(double v) => 'GH₵ ${NumberFormat('#,##0').format(v)}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(activeYearProvider);
    final incomeAsync = ref.watch(monthlyIncomeProvider(year));
    final expenseAsync = ref.watch(monthlyExpensesProvider(year));

    return incomeAsync.when(
      data: (income) => expenseAsync.when(
        data: (expense) {
          final totalIncome = income.values.fold<double>(0.0, (a, b) => a + b);
          final totalExpense = expense.values.fold<double>(0.0, (a, b) => a + b);
          final net = totalIncome - totalExpense;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _KpiGrid(
                items: [
                  _KpiItem(label: 'Income ($year)', value: _fmtMoney(totalIncome)),
                  _KpiItem(label: 'Expenses ($year)', value: _fmtMoney(totalExpense)),
                  _KpiItem(label: 'Net ($year)', value: _fmtMoney(net)),
                  const _KpiItem(label: 'Exports', value: 'See Export card'),
                ],
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Text('Could not load expenses: $e', style: const TextStyle(color: AppTheme.textMuted)),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Text('Could not load income: $e', style: const TextStyle(color: AppTheme.textMuted)),
    );
  }
}

class _ExportPanel extends ConsumerStatefulWidget {
  const _ExportPanel();

  @override
  ConsumerState<_ExportPanel> createState() => _ExportPanelState();
}

class _ExportPanelState extends ConsumerState<_ExportPanel> {
  bool _working = false;

  Future<void> _exportPaymentsExcel() async {
    setState(() => _working = true);
    try {
      final db = ref.read(databaseProvider);
      final year = ref.read(activeYearProvider);

      final fs = db.alias(db.feeStructures, 'fs');
      final st = db.alias(db.students, 'st');
      final joined = db.select(db.payments).join([
        drift.innerJoin(fs, fs.id.equalsExp(db.payments.feeStructureId)),
        drift.innerJoin(st, st.id.equalsExp(db.payments.studentId)),
      ])
        ..where(fs.academicYear.equals(year))
        ..orderBy([
          drift.OrderingTerm(expression: db.payments.paymentDate, mode: drift.OrderingMode.desc),
        ]);

      final rows = await joined.get();
      final excel = xl.Excel.createExcel();
      final sheet = excel['Payments'];

      sheet.appendRow([
        xl.TextCellValue('Receipt'),
        xl.TextCellValue('Payment Date'),
        xl.TextCellValue('Student'),
        xl.TextCellValue('Fee Name'),
        xl.TextCellValue('Category'),
        xl.TextCellValue('Amount Paid'),
        xl.TextCellValue('Method'),
        xl.TextCellValue('Notes'),
      ]);

      for (final r in rows) {
        final p = r.readTable(db.payments);
        final fee = r.readTable(fs);
        final student = r.readTable(st);
        sheet.appendRow([
          xl.TextCellValue(p.receiptNumber),
          xl.TextCellValue(p.paymentDate.toIso8601String()),
          xl.TextCellValue('${student.firstName} ${student.lastName}'),
          xl.TextCellValue(fee.feeName),
          xl.TextCellValue(fee.category),
          xl.DoubleCellValue(p.amountPaid),
          xl.TextCellValue(p.paymentMethod),
          xl.TextCellValue(p.notes ?? ''),
        ]);
      }

      final bytes = excel.save();
      if (bytes == null) throw Exception('Failed to generate file');

      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export payments Excel',
        fileName: 'payments_$year.xlsx',
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
      );
      if (path == null) return;
      final normalized = path.endsWith('.xlsx') ? path : '$path.xlsx';
      await File(normalized).writeAsBytes(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payments exported'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _exportExpensesExcel() async {
    setState(() => _working = true);
    try {
      final db = ref.read(databaseProvider);
      final u = db.alias(db.users, 'exp_user');
      final joined = db.select(db.expenses).join([
        drift.innerJoin(u, u.id.equalsExp(db.expenses.recordedBy)),
      ])
        ..orderBy([
          drift.OrderingTerm(expression: db.expenses.expenseDate, mode: drift.OrderingMode.desc),
        ]);

      final rows = await joined.get();
      final institutionalRows = await (db.select(db.institutionalExpenses).join([
        drift.innerJoin(u, u.id.equalsExp(db.institutionalExpenses.recordedBy)),
      ])
            ..orderBy([
              drift.OrderingTerm(expression: db.institutionalExpenses.expenseDate, mode: drift.OrderingMode.desc),
            ]))
          .get();
      final excel = xl.Excel.createExcel();
      final sheet = excel['Expenses'];

      sheet.appendRow([
        xl.TextCellValue('Source'),
        xl.TextCellValue('Expense Date'),
        xl.TextCellValue('Description'),
        xl.TextCellValue('Category'),
        xl.TextCellValue('Amount'),
        xl.TextCellValue('Recorded By'),
        xl.TextCellValue('Receipt Path'),
      ]);

      for (final r in rows) {
        final e = r.readTable(db.expenses);
        final user = r.readTable(u);
        sheet.appendRow([
          xl.TextCellValue('direct'),
          xl.TextCellValue(e.expenseDate.toIso8601String()),
          xl.TextCellValue(e.description),
          xl.TextCellValue(e.category),
          xl.DoubleCellValue(e.amount),
          xl.TextCellValue(user.fullName),
          xl.TextCellValue(e.receiptPath ?? ''),
        ]);
      }
      for (final r in institutionalRows) {
        final e = r.readTable(db.institutionalExpenses);
        final user = r.readTable(u);
        sheet.appendRow([
          xl.TextCellValue('institutional'),
          xl.TextCellValue(e.expenseDate.toIso8601String()),
          xl.TextCellValue(e.description ?? ''),
          xl.TextCellValue(e.category),
          xl.DoubleCellValue(e.amount),
          xl.TextCellValue(user.fullName),
          xl.TextCellValue(''),
        ]);
      }

      final bytes = excel.save();
      if (bytes == null) throw Exception('Failed to generate file');

      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export expenses Excel',
        fileName: 'expenses.xlsx',
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
      );
      if (path == null) return;
      final normalized = path.endsWith('.xlsx') ? path : '$path.xlsx';
      await File(normalized).writeAsBytes(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expenses exported'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _exportFinanceSummaryPdf() async {
    setState(() => _working = true);
    try {
      final year = ref.read(activeYearProvider);
      final income = await ref.read(monthlyIncomeProvider(year).future);
      final expense = await ref.read(monthlyExpensesProvider(year).future);
      final totalIncome = income.values.fold<double>(0.0, (a, b) => a + b);
      final totalExpense = expense.values.fold<double>(0.0, (a, b) => a + b);
      final net = totalIncome - totalExpense;

      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Finance Summary ($year)', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              pw.Text('Total Income: GH₵ ${totalIncome.toStringAsFixed(2)}'),
              pw.Text('Total Expenses: GH₵ ${totalExpense.toStringAsFixed(2)}'),
              pw.Text('Net: GH₵ ${net.toStringAsFixed(2)}'),
            ],
          ),
        ),
      );

      final bytes = await doc.save();
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export finance summary PDF',
        fileName: 'finance_summary_$year.pdf',
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      if (path == null) return;
      final normalized = path.endsWith('.pdf') ? path : '$path.pdf';
      await File(normalized).writeAsBytes(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finance PDF exported'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.tonal(
          onPressed: _working ? null : _exportFinanceSummaryPdf,
          child: Text(_working ? 'Working…' : 'Export Finance PDF'),
        ),
        FilledButton.tonal(
          onPressed: _working ? null : _exportPaymentsExcel,
          child: Text(_working ? 'Working…' : 'Export Payments Excel'),
        ),
        FilledButton.tonal(
          onPressed: _working ? null : _exportExpensesExcel,
          child: Text(_working ? 'Working…' : 'Export Expenses Excel'),
        ),
      ],
    );
  }
}

class _BroadcastPanel extends ConsumerStatefulWidget {
  const _BroadcastPanel();

  @override
  ConsumerState<_BroadcastPanel> createState() => _BroadcastPanelState();
}

class _BroadcastPanelState extends ConsumerState<_BroadcastPanel> {
  DirectorAudience _audience = DirectorAudience.parents;
  DirectorChannel _channel = DirectorChannel.sms;
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _sending = true);
    try {
      final svc = ref.read(directorCommunicationServiceProvider);
      final result = await svc.sendBroadcast(
        createdByUserId: user.id,
        audience: _audience,
        channel: _channel,
        subject: _subjectController.text,
        message: _messageController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<DirectorAudience>(
              value: _audience,
              items: const [
                DropdownMenuItem(value: DirectorAudience.parents, child: Text('Parents')),
                DropdownMenuItem(value: DirectorAudience.staff, child: Text('Staff')),
              ],
              onChanged: _sending ? null : (v) => setState(() => _audience = v ?? DirectorAudience.parents),
            ),
            DropdownButton<DirectorChannel>(
              value: _channel,
              items: const [
                DropdownMenuItem(value: DirectorChannel.sms, child: Text('SMS')),
                DropdownMenuItem(value: DirectorChannel.email, child: Text('Email')),
                DropdownMenuItem(value: DirectorChannel.inApp, child: Text('In-app')),
              ],
              onChanged: _sending ? null : (v) => setState(() => _channel = v ?? DirectorChannel.sms),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _subjectController,
          decoration: const InputDecoration(isDense: true, labelText: 'Subject (optional)'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _messageController,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(isDense: true, labelText: 'Message'),
        ),
        const SizedBox(height: 10),
        FilledButton.tonal(
          onPressed: _sending ? null : _send,
          child: Text(_sending ? 'Sending…' : 'Send'),
        ),
      ],
    );
  }
}

class _EmergencyAlertsPanel extends ConsumerStatefulWidget {
  const _EmergencyAlertsPanel();

  @override
  ConsumerState<_EmergencyAlertsPanel> createState() => _EmergencyAlertsPanelState();
}

class _EmergencyAlertsPanelState extends ConsumerState<_EmergencyAlertsPanel> {
  DirectorChannel _channel = DirectorChannel.sms;
  final _messageController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _sending = true);
    try {
      final svc = ref.read(directorCommunicationServiceProvider);
      final result = await svc.sendEmergencyAlert(
        createdByUserId: user.id,
        channel: _channel,
        message: _messageController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButton<DirectorChannel>(
          value: _channel,
          items: const [
            DropdownMenuItem(value: DirectorChannel.sms, child: Text('SMS')),
            DropdownMenuItem(value: DirectorChannel.email, child: Text('Email')),
            DropdownMenuItem(value: DirectorChannel.inApp, child: Text('In-app')),
          ],
          onChanged: _sending ? null : (v) => setState(() => _channel = v ?? DirectorChannel.sms),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _messageController,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(isDense: true, labelText: 'Emergency message'),
        ),
        const SizedBox(height: 10),
        FilledButton.tonal(
          onPressed: _sending ? null : _send,
          child: Text(_sending ? 'Sending…' : 'Send Alert (Parents + Staff)'),
        ),
      ],
    );
  }
}

class _CommunicationLogsPanel extends ConsumerWidget {
  const _CommunicationLogsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLogs = ref.watch(directorRecentNotificationsProvider);

    return asyncLogs.when(
      data: (items) {
        if (items.isEmpty) {
          return const Text('No communication logs yet.', style: TextStyle(color: AppTheme.textMuted));
        }
        return Column(
          children: [
            for (final n in items.take(10))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(n.channel, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    ),
                    SizedBox(
                      width: 70,
                      child: Text(n.status, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    ),
                    Expanded(
                      child: Text(
                        n.subject?.trim().isNotEmpty == true ? n.subject!.trim() : n.message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Text('Could not load logs: $e', style: const TextStyle(color: AppTheme.textMuted)),
    );
  }
}

class _RoleManagementPanel extends ConsumerWidget {
  const _RoleManagementPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);

    return StreamBuilder<List<User>>(
      stream: (db.select(db.users)
            ..orderBy([(t) => drift.OrderingTerm(expression: t.fullName)]))
          .watch(),
      builder: (context, snap) {
        final users = snap.data ?? const <User>[];
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (users.isEmpty) {
          return const Text('No users found.', style: TextStyle(color: AppTheme.textMuted));
        }

        return Column(
          children: [
            for (final u in users.take(25)) _UserRoleRow(user: u),
            if (users.length > 25)
              Text('Showing first 25 users', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ],
        );
      },
    );
  }
}

class _UserRoleRow extends ConsumerStatefulWidget {
  const _UserRoleRow({required this.user});

  final User user;

  @override
  ConsumerState<_UserRoleRow> createState() => _UserRoleRowState();
}

class _UserRoleRowState extends ConsumerState<_UserRoleRow> {
  bool _saving = false;

  late UserRole _role = supportedPortalRoles.firstWhere(
    (r) => r.name == widget.user.role,
    orElse: () => UserRole.teacher,
  );

  late bool _active = widget.user.isActive;

  @override
  void didUpdateWidget(covariant _UserRoleRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) {
      _role = supportedPortalRoles.firstWhere((r) => r.name == widget.user.role, orElse: () => UserRole.teacher);
      _active = widget.user.isActive;
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final db = ref.read(databaseProvider);
      await (db.update(db.users)..where((t) => t.id.equals(widget.user.id))).write(
        UsersCompanion(
          role: drift.Value(_role.name),
          isActive: drift.Value(_active),
          updatedAt: drift.Value(DateTime.now()),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User updated'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final roleDropdown = DropdownButton<UserRole>(
            value: supportedPortalRoles.contains(_role) ? _role : UserRole.teacher,
            items: supportedPortalRoles
                .map((r) => DropdownMenuItem(value: r, child: Text(r.displayName)))
                .toList(growable: false),
            onChanged: _saving ? null : (v) => setState(() => _role = v ?? _role),
          );
          final activeSwitch = Switch(
            value: _active,
            onChanged: _saving ? null : (v) => setState(() => _active = v),
          );
          final saveButton = FilledButton.tonal(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save'),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.user.fullName, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    roleDropdown,
                    activeSwitch,
                    saveButton,
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: Text(widget.user.fullName, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 10),
              roleDropdown,
              const SizedBox(width: 10),
              activeSwitch,
              const SizedBox(width: 6),
              saveButton,
            ],
          );
        },
      ),
    );
  }
}

class _CustomWidgetsPanel extends ConsumerStatefulWidget {
  const _CustomWidgetsPanel();

  @override
  ConsumerState<_CustomWidgetsPanel> createState() => _CustomWidgetsPanelState();
}

class _CustomWidgetsPanelState extends ConsumerState<_CustomWidgetsPanel> {
  static const _kNoteKey = 'director_custom_widget_note';
  final _controller = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final row = await (db.select(db.syncMetadata)
          ..where((t) => t.key.equals(_kNoteKey))
          ..limit(1))
        .getSingleOrNull();
    _controller.text = row?.value ?? '';
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final db = ref.read(databaseProvider);
      await db.into(db.syncMetadata).insertOnConflictUpdate(
            SyncMetadataCompanion.insert(
              key: _kNoteKey,
              value: drift.Value(_controller.text.trim().isEmpty ? null : _controller.text.trim()),
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(isDense: true, labelText: 'Pinned note'),
        ),
        const SizedBox(height: 10),
        FilledButton.tonal(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save Note'),
        ),
      ],
    );
  }
}

class _SimpleStat extends StatelessWidget {
  const _SimpleStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.surfaceMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, height: 1.2)),
        ],
      ),
    );
  }
}

class _ProgressStat extends StatelessWidget {
  const _ProgressStat({required this.label, required this.valueText, required this.progress});

  final String label;
  final String valueText;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final normalizedProgress = progress.clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.surfaceMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w600))),
              Text(valueText, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: normalizedProgress,
              minHeight: 10,
              backgroundColor: AppTheme.surfaceMuted,
              valueColor: AlwaysStoppedAnimation<Color>(Color.lerp(AppTheme.authorityYellow, AppTheme.actionIndigo, normalizedProgress) ?? AppTheme.actionIndigo),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiItem {
  final String label;
  final String value;
  final Color? valueColor;

  const _KpiItem({required this.label, required this.value, this.valueColor});
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.items});

  final List<_KpiItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 520 ? 2 : 4;
        final tileWidth = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in items)
              SizedBox(
                width: tileWidth,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.surfaceMuted),
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        (item.valueColor ?? AppTheme.actionIndigo).withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text(
                          item.value,
                          style: TextStyle(fontWeight: FontWeight.w900, color: item.valueColor, fontSize: 20),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TwoColumnStats extends StatelessWidget {
  const _TwoColumnStats({
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
  });

  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _SimpleStat(label: leftLabel, value: leftValue)),
        const SizedBox(width: 16),
        Expanded(child: _SimpleStat(label: rightLabel, value: rightValue)),
      ],
    );
  }
}

class _DirectorVisualTone {
  const _DirectorVisualTone({
    required this.primary,
    required this.secondary,
    required this.accent,
  });

  final Color primary;
  final Color secondary;
  final Color accent;
}

_DirectorVisualTone _toneForSection(String sectionId) {
  switch (sectionId) {
    case 'budget':
      return const _DirectorVisualTone(
        primary: Color(0xFF0F3D3E),
        secondary: Color(0xFF14532D),
        accent: Color(0xFFF59E0B),
      );
    case 'expenses':
      return const _DirectorVisualTone(
        primary: Color(0xFF3F1D38),
        secondary: Color(0xFF7C2D12),
        accent: Color(0xFFFB7185),
      );
    case 'analytics':
      return const _DirectorVisualTone(
        primary: Color(0xFF1E3A8A),
        secondary: Color(0xFF164E63),
        accent: Color(0xFF22C55E),
      );
    case 'resource-utilization':
      return const _DirectorVisualTone(
        primary: Color(0xFF3B2F0B),
        secondary: Color(0xFF365314),
        accent: Color(0xFFEAB308),
      );
    case 'audit-logs':
      return const _DirectorVisualTone(
        primary: Color(0xFF312E81),
        secondary: Color(0xFF1E1B4B),
        accent: Color(0xFFA78BFA),
      );
    case 'data-access-roles':
      return const _DirectorVisualTone(
        primary: Color(0xFF0F172A),
        secondary: Color(0xFF1D4ED8),
        accent: Color(0xFF38BDF8),
      );
    case 'executive-dashboard':
    default:
      return const _DirectorVisualTone(
        primary: Color(0xFF111827),
        secondary: Color(0xFF1D4ED8),
        accent: Color(0xFFF59E0B),
      );
  }
}

String _sectionDescription(DirectorSection section) {
  switch (section.id) {
    case 'budget':
      return 'Shape term strategy with fee targets, payroll planning, and living draft budgets that stay available across sessions.';
    case 'expenses':
      return 'Track purchasing pressure with structured canteen and shop tables, fast approvals, and a cleaner operational control surface.';
    case 'analytics':
      return 'Review financial performance, compare planned versus actual movement, and export a sharper executive narrative for the term.';
    case 'resource-utilization':
      return 'Monitor how learning infrastructure is being used so decisions on labs, equipment, and capacity stay evidence-based.';
    case 'audit-logs':
      return 'Inspect platform activity with a calmer, executive-facing view that makes operational anomalies easier to spot.';
    case 'data-access-roles':
      return 'Review visibility, permissions, and governance boundaries with clearer emphasis on risk-sensitive controls.';
    case 'executive-dashboard':
    default:
      return 'A sharper executive command center for school performance, attendance, cash flow, staffing, and term momentum.';
  }
}

List<({String label, String value, IconData icon})> _heroMetricsForSection(
  String sectionId,
  DirectorKpis kpis,
  String Function(int) fmtInt,
  String Function(double) fmtPercent,
  String Function(double) fmtMoney,
) {
  switch (sectionId) {
    case 'budget':
      return [
        (label: 'Projected Balance', value: fmtMoney(kpis.projectedTermBalance), icon: Icons.account_balance_wallet_outlined),
        (label: 'Term Expenses', value: fmtMoney(kpis.projectedTermExpenses), icon: Icons.stacked_bar_chart_outlined),
        (label: 'Snapshots', value: fmtInt(kpis.budgetSnapshotCount), icon: Icons.history_toggle_off_outlined),
      ];
    case 'expenses':
      return [
        (label: 'Monthly Expenses', value: fmtMoney(kpis.expensesThisMonth), icon: Icons.receipt_long_outlined),
        (label: 'Payroll Net', value: fmtMoney(kpis.payrollNetThisMonth), icon: Icons.payments_outlined),
        (label: 'Variance', value: fmtMoney(kpis.termBalanceVariance), icon: Icons.compare_arrows_outlined),
      ];
    case 'analytics':
      return [
        (label: 'Actual Income', value: fmtMoney(kpis.actualTermIncome), icon: Icons.trending_up_outlined),
        (label: 'Actual Expenses', value: fmtMoney(kpis.actualTermExpenses), icon: Icons.trending_down_outlined),
        (label: 'Fee Collection', value: fmtPercent(kpis.feesCollectionRate), icon: Icons.pie_chart_outline_outlined),
      ];
    default:
      return [
        (label: 'Enrollment', value: fmtInt(kpis.totalStudents), icon: Icons.groups_2_outlined),
        (label: 'Attendance', value: fmtPercent(kpis.studentAttendanceRateToday), icon: Icons.fact_check_outlined),
        (label: 'Projected Balance', value: fmtMoney(kpis.projectedTermBalance), icon: Icons.account_balance_wallet_outlined),
      ];
  }
}

Color _featureAccent(DirectorFeatureKind kind, _DirectorVisualTone tone, int index) {
  switch (kind) {
    case DirectorFeatureKind.dashboard:
    case DirectorFeatureKind.budget:
    case DirectorFeatureKind.financeAnalytics:
      return tone.accent;
    case DirectorFeatureKind.expenses:
    case DirectorFeatureKind.approvalsLargeExpenses:
      return const Color(0xFFFB7185);
    case DirectorFeatureKind.auditLogs:
    case DirectorFeatureKind.dataAccess:
    case DirectorFeatureKind.roleManagement:
      return const Color(0xFF38BDF8);
    default:
      return index.isEven ? tone.accent : AppTheme.actionIndigo;
  }
}

IconData _featureIcon(DirectorFeatureKind kind) {
  switch (kind) {
    case DirectorFeatureKind.dashboard:
      return Icons.space_dashboard_outlined;
    case DirectorFeatureKind.budget:
      return Icons.account_balance_wallet_outlined;
    case DirectorFeatureKind.expenses:
      return Icons.receipt_long_outlined;
    case DirectorFeatureKind.financeAnalytics:
      return Icons.insights_outlined;
    case DirectorFeatureKind.reportsFinance:
      return Icons.summarize_outlined;
    case DirectorFeatureKind.export:
      return Icons.file_download_outlined;
    case DirectorFeatureKind.approvalsLargeExpenses:
      return Icons.rule_folder_outlined;
    case DirectorFeatureKind.attendanceOverview:
      return Icons.verified_user_outlined;
    case DirectorFeatureKind.resourceUtilizationLabs:
      return Icons.science_outlined;
    case DirectorFeatureKind.auditLogs:
      return Icons.manage_search_outlined;
    case DirectorFeatureKind.dataAccess:
    case DirectorFeatureKind.roleManagement:
      return Icons.admin_panel_settings_outlined;
    default:
      return Icons.auto_awesome_mosaic_outlined;
  }
}

String _featureDescription(DirectorFeatureKind kind, String fallbackTitle) {
  switch (kind) {
    case DirectorFeatureKind.dashboard:
      return 'High-signal performance tiles for enrollment, attendance, fee health, and current balance pressure.';
    case DirectorFeatureKind.budget:
      return 'A more focused planning studio for fee projections, payroll structure, and revision control.';
    case DirectorFeatureKind.expenses:
      return 'Operational spending tables designed for faster entry, clearer totals, and stronger oversight.';
    case DirectorFeatureKind.financeAnalytics:
      return 'Trend analysis that turns financial movement into an executive story, not just raw numbers.';
    case DirectorFeatureKind.reportsFinance:
      return 'Condensed finance summaries for quick review before sharing or exporting.';
    case DirectorFeatureKind.export:
      return 'Pull clean executive outputs for reporting, audit follow-up, and offline circulation.';
    case DirectorFeatureKind.approvalsLargeExpenses:
      return 'Review high-value requests in a calmer approval surface with less visual noise.';
    case DirectorFeatureKind.attendanceOverview:
      return 'A fast signal on how the school day is unfolding before operational issues compound.';
    case DirectorFeatureKind.resourceUtilizationLabs:
      return 'Utilization insights for physical learning resources, helping investment decisions stay grounded.';
    case DirectorFeatureKind.auditLogs:
      return 'Readable oversight for recent platform actions, exceptions, and accountability checks.';
    case DirectorFeatureKind.dataAccess:
    case DirectorFeatureKind.roleManagement:
      return 'Sharper governance views for permissions, access exposure, and administrative control.';
    default:
      return '$fallbackTitle with a cleaner, more executive-oriented presentation.';
  }
}

enum _SnapshotFilter {
  all,
  currentYear,
  currentTerm,
}

class _BudgetEditor extends ConsumerStatefulWidget {
  const _BudgetEditor({required this.mode});

  final _BudgetEditorMode mode;

  @override
  ConsumerState<_BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends ConsumerState<_BudgetEditor> {
  final _snapshotNoteController = TextEditingController();
  DirectorBudgetPlan? _plan;
  DirectorBudgetAnalytics? _analytics;
  List<DirectorBudgetSnapshot> _snapshots = const [];
  _SnapshotFilter _snapshotFilter = _SnapshotFilter.currentTerm;
  String _recordedExpenseCategoryFilter = 'All';
  _RecordedExpenseDateFilter _recordedExpenseDateFilter = _RecordedExpenseDateFilter.all;
  String? _comparisonLeftId;
  String? _comparisonRightId;
  int? _loadedYear;
  int? _loadedTerm;
  Map<int, int> _classStudentCounts = const {};
  bool _loading = false;
  bool _saving = false;
  bool _exporting = false;
  bool _comparisonExporting = false;
  bool _comparisonPrinting = false;
  bool _autosaving = false;
  bool _hasUnsavedChanges = false;
  int _draftVersion = 0;
  int _persistedDraftVersion = 0;
  DateTime? _lastDraftSavedAt;
  Timer? _autosaveTimer;

  bool get _showBudgetContent => widget.mode == _BudgetEditorMode.budget;
  bool get _showExpensesContent => widget.mode == _BudgetEditorMode.expenses;
  bool get _showAnalyticsContent => widget.mode == _BudgetEditorMode.analytics;
  bool get _saveInProgress => _saving || _autosaving;
  String? _error;

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _snapshotNoteController.dispose();
    super.dispose();
  }

  String _snapshotId(DirectorBudgetSnapshot snapshot) {
    return '${snapshot.academicYear}-${snapshot.term}-${snapshot.savedAt.toIso8601String()}';
  }

  String _snapshotLabel(DirectorBudgetSnapshot snapshot) {
    return 'Y${snapshot.academicYear} • T${snapshot.term} • ${DateFormat('yyyy-MM-dd HH:mm').format(snapshot.savedAt)}';
  }

  Color? _studentDeltaColor(int delta) {
    if (delta > 0) return Colors.blue.shade700;
    if (delta < 0) return Colors.deepOrange.shade700;
    return null;
  }

  Color? _studentDeltaTint(int delta) {
    if (delta > 0) return Colors.blue.withValues(alpha: 0.08);
    if (delta < 0) return Colors.orange.withValues(alpha: 0.08);
    return null;
  }

  List<DirectorBudgetSnapshot> _filteredSnapshotsFor(
    List<DirectorBudgetSnapshot> snapshots,
    int academicYear,
    int term,
  ) {
    final filtered = switch (_snapshotFilter) {
      _SnapshotFilter.all => snapshots,
      _SnapshotFilter.currentYear => snapshots.where((row) => row.academicYear == academicYear).toList(growable: false),
      _SnapshotFilter.currentTerm => snapshots.where((row) => row.academicYear == academicYear && row.term == term).toList(growable: false),
    };
    return filtered.take(12).toList(growable: false);
  }

  void _syncComparisonSelection(List<DirectorBudgetSnapshot> visibleSnapshots) {
    final visibleIds = visibleSnapshots.map(_snapshotId).toSet();
    String? nextLeft = _comparisonLeftId;
    String? nextRight = _comparisonRightId;

    if (nextLeft != null && !visibleIds.contains(nextLeft)) {
      nextLeft = null;
    }
    if (nextRight != null && !visibleIds.contains(nextRight)) {
      nextRight = null;
    }

    final defaults = visibleSnapshots.take(2).toList(growable: false);
    nextLeft ??= defaults.isNotEmpty ? _snapshotId(defaults.first) : null;
    nextRight ??= defaults.length > 1 ? _snapshotId(defaults[1]) : null;

    if (nextLeft == nextRight && defaults.length > 1) {
      nextRight = _snapshotId(defaults[1]);
    }

    _comparisonLeftId = nextLeft;
    _comparisonRightId = nextRight;
  }

  DirectorBudgetSnapshot? _findSnapshotById(List<DirectorBudgetSnapshot> snapshots, String? id) {
    if (id == null) return null;
    for (final snapshot in snapshots) {
      if (_snapshotId(snapshot) == id) return snapshot;
    }
    return null;
  }

  Future<void> _loadForContext(int academicYear, int term) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final svc = ref.read(directorBudgetServiceProvider);
      final plan = await svc.getBudgetPlan(academicYear: academicYear, term: term);
      final analytics = await svc.getBudgetAnalytics(academicYear: academicYear, term: term);
      final snapshots = await svc.getBudgetSnapshots();
      final classStudentCounts = await svc.getActiveStudentCountsByClass(academicYear: academicYear);
      final classes = await ref.read(classesProvider.future);
      final seededPlan = _seedPlanForClasses(plan, classes, classStudentCounts, academicYear: academicYear);
      final syncedPlan = _syncPlanWithStudentCounts(seededPlan, classStudentCounts);
      final visibleSnapshots = _filteredSnapshotsFor(snapshots, academicYear, term);
      if (!mounted) return;
      setState(() {
        _plan = syncedPlan;
        _analytics = _rebuildAnalytics(syncedPlan, otherFeesPerTerm: analytics.otherFeesPerTerm);
        _snapshots = snapshots;
        _loadedYear = academicYear;
        _loadedTerm = term;
        _classStudentCounts = classStudentCounts;
        _syncComparisonSelection(visibleSnapshots);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('FormatException: ', ''));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _ensureLoaded(int academicYear, int term) {
    if ((_loadedYear == academicYear && _loadedTerm == term) || _loading) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_loadedYear == academicYear && _loadedTerm == term) return;
      _loadForContext(academicYear, term);
    });
  }

  DirectorBudgetPlan _currentPlan(int academicYear, int term) {
    return (_plan ?? DirectorBudgetPlan.empty(academicYear: academicYear, term: term)).normalized(
      academicYear: academicYear,
      term: term,
    );
  }

  DirectorBudgetAnalytics _rebuildAnalytics(DirectorBudgetPlan plan, {double? otherFeesPerTerm}) {
    final otherFees = otherFeesPerTerm ?? _analytics?.otherFeesPerTerm ?? 0;
    return DirectorBudgetAnalytics(
      termBudgetPlan: plan,
      canteenIncomePerTerm: plan.totalCanteenFeesPerTerm,
      schoolFeesPerTerm: plan.totalSchoolFees,
      otherFeesPerTerm: otherFees,
      totalIncomePerTerm: plan.totalCanteenFeesPerTerm + plan.totalSchoolFees + otherFees,
      totalExpensesPerTerm: plan.totalExpensesPerTerm,
      actualIncomePerTerm: _analytics?.actualIncomePerTerm ?? 0,
      actualExpensesPerTerm: _analytics?.actualExpensesPerTerm ?? 0,
      canteenPurchasingPerTerm: plan.totalCanteenExpensesPerTerm,
      salariesPerTerm: plan.salaryBudgetPerTerm,
      taxPerTerm: plan.taxBudgetPerTerm,
      ssnitPerTerm: plan.ssnitBudgetPerTerm,
    );
  }

  DirectorBudgetPlan _syncPlanWithStudentCounts(DirectorBudgetPlan plan, Map<int, int> counts) {
    return plan.copyWith(
      canteenFeeRows: [
        for (final row in plan.canteenFeeRows)
          row.classId == null ? row : row.copyWith(studentCount: counts[row.classId!] ?? 0),
      ],
      schoolFeeRows: [
        for (final row in plan.schoolFeeRows)
          row.classId == null ? row : row.copyWith(studentCount: counts[row.classId!] ?? 0),
      ],
    );
  }

  DirectorBudgetPlan _seedPlanForClasses(
    DirectorBudgetPlan plan,
    List<SchoolClassesData> classes,
    Map<int, int> counts, {
    required int academicYear,
  }) {
    final activeClasses = classes
        .where((row) => row.academicYear == academicYear && row.isActive)
        .toList(growable: false)
      ..sort((a, b) => a.className.compareTo(b.className));

    final existingCanteenIds = plan.canteenFeeRows.map((row) => row.classId).whereType<int>().toSet();
    final existingSchoolIds = plan.schoolFeeRows.map((row) => row.classId).whereType<int>().toSet();

    final seededCanteen = <CanteenFeeBudgetRow>[
      ...plan.canteenFeeRows,
      for (final schoolClass in activeClasses)
        if (!existingCanteenIds.contains(schoolClass.id))
          CanteenFeeBudgetRow(
            classId: schoolClass.id,
            classLabel: schoolClass.className,
            studentCount: counts[schoolClass.id] ?? 0,
            amountPerChild: 0,
            daysPerWeek: 0,
            weeksPerMonth: 0,
          ),
    ];

    final seededSchool = <SchoolFeeBudgetRow>[
      ...plan.schoolFeeRows,
      for (final schoolClass in activeClasses)
        if (!existingSchoolIds.contains(schoolClass.id))
          SchoolFeeBudgetRow(
            classId: schoolClass.id,
            classLabel: schoolClass.className,
            studentCount: counts[schoolClass.id] ?? 0,
            amount: 0,
          ),
    ];

    return plan.copyWith(
      canteenFeeRows: seededCanteen,
      schoolFeeRows: seededSchool,
    );
  }

  void _setPlan(DirectorBudgetPlan plan) {
    final syncedPlan = _syncPlanWithStudentCounts(plan, _classStudentCounts);
    setState(() {
      _plan = syncedPlan;
      _analytics = _rebuildAnalytics(syncedPlan);
      _error = null;
      _hasUnsavedChanges = true;
      _draftVersion += 1;
    });
    _scheduleAutosave();
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted || !_hasUnsavedChanges || _saving || _autosaving) {
        return;
      }
      unawaited(_saveDraft());
    });
  }

  String _draftStatusText() {
    if (_autosaving) return 'Auto-saving…';
    if (_saving) return 'Saving revision…';
    if (_hasUnsavedChanges) return 'Unsaved changes';
    if (_lastDraftSavedAt != null) {
      return 'Saved ${DateFormat('HH:mm:ss').format(_lastDraftSavedAt!)}';
    }
    return 'Changes auto-save';
  }

  Future<void> _saveDraft({
    String successMessage = 'Changes saved',
    bool showFeedback = false,
  }) async {
    if (_autosaving || _saving) {
      return;
    }
    if (!_hasUnsavedChanges && _lastDraftSavedAt != null) {
      if (!mounted || !showFeedback) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All changes are already saved.'), backgroundColor: Colors.green),
      );
      return;
    }

    _autosaveTimer?.cancel();
    final academicYear = ref.read(activeYearProvider);
    final term = ref.read(activeTermProvider);
    final plan = _currentPlan(academicYear, term);
    final requestVersion = _draftVersion;

    setState(() {
      _autosaving = true;
      _error = null;
    });

    try {
      final svc = ref.read(directorBudgetServiceProvider);
      await svc.saveBudgetDraft(plan);
      final analytics = await svc.getBudgetAnalytics(academicYear: academicYear, term: term);
      ref.invalidate(directorKpisProvider);
      if (!mounted) return;
      final savedAt = DateTime.now();
      setState(() {
        _plan = plan;
        _analytics = analytics;
        if (requestVersion > _persistedDraftVersion) {
          _persistedDraftVersion = requestVersion;
        }
        _hasUnsavedChanges = _draftVersion != _persistedDraftVersion;
        _lastDraftSavedAt = savedAt;
      });
      if (showFeedback && !_hasUnsavedChanges) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('FormatException: ', ''));
    } finally {
      if (mounted) {
        final pendingChanges = _draftVersion != _persistedDraftVersion;
        setState(() {
          _autosaving = false;
          _hasUnsavedChanges = pendingChanges;
        });
        if (pendingChanges) {
          _scheduleAutosave();
        }
      }
    }
  }

  Future<void> _restoreSnapshot(DirectorBudgetSnapshot snapshot, int academicYear, int term) async {
    final classes = await ref.read(classesProvider.future);
    final restoredPlan = snapshot.plan.normalized(academicYear: academicYear, term: term);
    final seededPlan = _seedPlanForClasses(
      restoredPlan,
      classes,
      _classStudentCounts,
      academicYear: academicYear,
    );
    _setPlan(seededPlan);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loaded Term ${snapshot.term}, ${snapshot.academicYear} snapshot into the current planner.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  double _parseMoney(String value) {
    final parsed = double.tryParse(value.trim());
    if (parsed == null || parsed.isNaN || parsed.isInfinite || parsed < 0) {
      return 0;
    }
    return parsed;
  }

  int _parseCount(String value) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed < 0) return 0;
    return parsed;
  }

  Color _varianceColor(double value, {bool lowerIsBetter = false}) {
    final isFavorable = lowerIsBetter ? value <= 0 : value >= 0;
    return isFavorable ? Colors.green.shade700 : Colors.red.shade700;
  }

  Color _varianceTint(double value, {bool lowerIsBetter = false}) {
    final isFavorable = lowerIsBetter ? value <= 0 : value >= 0;
    return isFavorable ? Colors.green.withValues(alpha: 0.08) : Colors.red.withValues(alpha: 0.08);
  }

  Widget _analyticsTile({
    required String label,
    required String value,
    Color? valueColor,
    Color? backgroundColor,
  }) {
    return SizedBox(
      width: 180,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(fontWeight: FontWeight.w900, color: valueColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _plannedVsActualChart(DirectorBudgetAnalytics analytics) {
    final groups = <({String label, double planned, double actual, bool lowerIsBetter})>[
      (label: 'Income', planned: analytics.totalIncomePerTerm, actual: analytics.actualIncomePerTerm, lowerIsBetter: false),
      (label: 'Expenses', planned: analytics.totalExpensesPerTerm, actual: analytics.actualExpensesPerTerm, lowerIsBetter: true),
      (label: 'Balance', planned: analytics.projectedBalance, actual: analytics.actualBalance, lowerIsBetter: false),
    ];
    final maxValue = groups
        .expand((row) => [row.planned.abs(), row.actual.abs()])
        .fold<double>(1, (max, value) => value > max ? value : max);

    return SizedBox(
      height: 260,
      child: BarChart(
        BarChartData(
          maxY: maxValue * 1.25,
          minY: 0,
          barTouchData: BarTouchData(enabled: true),
          gridData: FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 64,
                getTitlesWidget: (value, meta) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    NumberFormat.compact().format(value),
                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= groups.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(groups[index].label, style: const TextStyle(fontSize: 11)),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var index = 0; index < groups.length; index++)
              BarChartGroupData(
                x: index,
                barsSpace: 6,
                barRods: [
                  BarChartRodData(
                    toY: groups[index].planned.abs(),
                    width: 18,
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.blueGrey.shade300,
                  ),
                  BarChartRodData(
                    toY: groups[index].actual.abs(),
                    width: 18,
                    borderRadius: BorderRadius.circular(6),
                    color: _varianceColor(groups[index].actual - groups[index].planned, lowerIsBetter: groups[index].lowerIsBetter),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _save({bool replaceLatestSnapshot = true}) async {
    _autosaveTimer?.cancel();
    final academicYear = ref.read(activeYearProvider);
    final term = ref.read(activeTermProvider);
    final plan = _currentPlan(academicYear, term);
    final snapshotNote = _snapshotNoteController.text.trim();

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final svc = ref.read(directorBudgetServiceProvider);
      await svc.saveBudgetPlan(
        plan,
        replaceLatestSnapshot: replaceLatestSnapshot,
        snapshotNote: snapshotNote,
      );
      final analytics = await svc.getBudgetAnalytics(academicYear: academicYear, term: term);
      final snapshots = await svc.getBudgetSnapshots();
      final visibleSnapshots = _filteredSnapshotsFor(snapshots, academicYear, term);

      ref.invalidate(directorKpisProvider);
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _analytics = analytics;
        _snapshots = snapshots;
        _persistedDraftVersion = _draftVersion;
        _hasUnsavedChanges = false;
        _lastDraftSavedAt = DateTime.now();
        _syncComparisonSelection(visibleSnapshots);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(replaceLatestSnapshot ? 'Director budget saved and current snapshot updated' : 'Director budget saved as a new revision'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('FormatException: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _sectionCard({required String title, String? subtitle, required Widget child}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: AppTheme.textMuted)),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _recordedInstitutionalExpensesSection(
    AsyncValue<List<FinanceExpenseEntry>> expensesAsync, {
    required int academicYear,
  }) {
    return _sectionCard(
      title: 'Recorded Expenses',
      subtitle: 'Institutional and operating expenses, including shop stock purchases, appear here with description and amount.',
      child: expensesAsync.when(
        data: (expenses) {
          if (expenses.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No expenses have been logged yet.', style: TextStyle(color: AppTheme.textMuted)),
            );
          }

          final categories = <String>{
            'All',
            ...expenses.map((row) => row.category).where((row) => row.trim().isNotEmpty),
          }.toList(growable: false)
            ..sort((a, b) {
              if (a == 'All') return -1;
              if (b == 'All') return 1;
              return a.toLowerCase().compareTo(b.toLowerCase());
            });

          if (!categories.contains(_recordedExpenseCategoryFilter)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() => _recordedExpenseCategoryFilter = 'All');
            });
          }

          final filtered = expenses.where((expense) {
            final matchesCategory = _recordedExpenseCategoryFilter == 'All' || expense.category == _recordedExpenseCategoryFilter;
            if (!matchesCategory) return false;

            switch (_recordedExpenseDateFilter) {
              case _RecordedExpenseDateFilter.all:
                return true;
              case _RecordedExpenseDateFilter.activeYear:
                return expense.expenseDate.year == academicYear;
              case _RecordedExpenseDateFilter.currentMonth:
                final now = DateTime.now();
                return expense.expenseDate.year == now.year && expense.expenseDate.month == now.month;
            }
          }).toList(growable: false);

          final sorted = [...filtered]
            ..sort((a, b) => b.expenseDate.compareTo(a.expenseDate));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 760;
                  final categoryField = DropdownButtonFormField<String>(
                    initialValue: _recordedExpenseCategoryFilter,
                    decoration: const InputDecoration(labelText: 'Category', isDense: true),
                    items: [
                      for (final category in categories)
                        DropdownMenuItem<String>(
                          value: category,
                          child: Text(category, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _recordedExpenseCategoryFilter = value);
                    },
                  );
                  final dateField = DropdownButtonFormField<_RecordedExpenseDateFilter>(
                    initialValue: _recordedExpenseDateFilter,
                    decoration: const InputDecoration(labelText: 'Date scope', isDense: true),
                    items: const [
                      DropdownMenuItem(value: _RecordedExpenseDateFilter.all, child: Text('All dates')),
                      DropdownMenuItem(value: _RecordedExpenseDateFilter.activeYear, child: Text('Active academic year')),
                      DropdownMenuItem(value: _RecordedExpenseDateFilter.currentMonth, child: Text('Current month')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _recordedExpenseDateFilter = value);
                    },
                  );

                  if (stacked) {
                    return Column(
                      children: [
                        categoryField,
                        const SizedBox(height: 12),
                        dateField,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: categoryField),
                      const SizedBox(width: 12),
                      Expanded(child: dateField),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Showing ${sorted.length} of ${expenses.length} logged expenses',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (sorted.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No recorded expenses match the selected filters.', style: TextStyle(color: AppTheme.textMuted)),
                ),
              for (var index = 0; index < sorted.length; index++) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.error.withValues(alpha: 0.10),
                    child: const Icon(Icons.receipt_long_outlined, color: AppTheme.error, size: 18),
                  ),
                  title: Text(
                    (sorted[index].description?.trim().isNotEmpty ?? false)
                        ? sorted[index].description!.trim()
                        : sorted[index].category,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${sorted[index].category} • ${sorted[index].isInstitutional ? 'Institutional' : 'Operating'} • ${DateFormat('MMM dd, yyyy').format(sorted[index].expenseDate)}',
                    style: const TextStyle(color: AppTheme.textMuted),
                  ),
                  trailing: Text(
                    'GH₵ ${sorted[index].amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.error),
                  ),
                ),
                if (index != sorted.length - 1) const Divider(height: 1),
              ],
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, s) => Text('Could not load recorded expenses: $e', style: const TextStyle(color: Colors.red)),
      ),
    );
  }

  Widget _headerCell(String text, {double width = 110}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }

  Widget _textCell({
    required String initialValue,
    required ValueChanged<String> onChanged,
    double width = 110,
    TextInputType? keyboardType,
    String? hint,
    Key? key,
  }) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: TextFormField(
          key: key,
          initialValue: initialValue,
          onChanged: onChanged,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
          ),
        ),
      ),
    );
  }

  Widget _valueCell(
    String text, {
    double width = 120,
    TextAlign textAlign = TextAlign.right,
    Color? textColor,
    Color? backgroundColor,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        text,
        textAlign: textAlign,
        style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
      ),
    );
  }

  String _money(double value) => 'GH₵ ${NumberFormat('#,##0.00').format(value)}';

  List<({
    String label,
    double leftValue,
    double rightValue,
    double delta,
    bool lowerIsBetter,
  })> _comparisonSummaryRows(DirectorBudgetSnapshot left, DirectorBudgetSnapshot right) {
    final leftActualBalance = left.actualIncomePerTerm - left.actualExpensesPerTerm;
    final rightActualBalance = right.actualIncomePerTerm - right.actualExpensesPerTerm;
    return [
      (label: 'Planned Income', leftValue: left.totalIncomePerTerm, rightValue: right.totalIncomePerTerm, delta: right.totalIncomePerTerm - left.totalIncomePerTerm, lowerIsBetter: false),
      (label: 'Planned Expenses', leftValue: left.totalExpensesPerTerm, rightValue: right.totalExpensesPerTerm, delta: right.totalExpensesPerTerm - left.totalExpensesPerTerm, lowerIsBetter: true),
      (label: 'Projected Balance', leftValue: left.projectedBalance, rightValue: right.projectedBalance, delta: right.projectedBalance - left.projectedBalance, lowerIsBetter: false),
      (label: 'Actual Income', leftValue: left.actualIncomePerTerm, rightValue: right.actualIncomePerTerm, delta: right.actualIncomePerTerm - left.actualIncomePerTerm, lowerIsBetter: false),
      (label: 'Actual Expenses', leftValue: left.actualExpensesPerTerm, rightValue: right.actualExpensesPerTerm, delta: right.actualExpensesPerTerm - left.actualExpensesPerTerm, lowerIsBetter: true),
      (label: 'Actual Balance', leftValue: leftActualBalance, rightValue: rightActualBalance, delta: rightActualBalance - leftActualBalance, lowerIsBetter: false),
      (label: 'Balance Variance', leftValue: left.balanceVariance, rightValue: right.balanceVariance, delta: right.balanceVariance - left.balanceVariance, lowerIsBetter: false),
    ];
  }

  List<({
    String item,
    double leftTermTotal,
    double rightTermTotal,
    double termTotalDelta,
  })> _expenseDiffRows(List<BudgetExpenseRow> leftRows, List<BudgetExpenseRow> rightRows, int months) {
    final leftByKey = {
      for (final row in leftRows)
        row.itemName.trim().toLowerCase(): row,
    };
    final rightByKey = {
      for (final row in rightRows)
        row.itemName.trim().toLowerCase(): row,
    };
    final keys = {...leftByKey.keys, ...rightByKey.keys}.where((key) => key.isNotEmpty).toList(growable: false)..sort();
    return [
      for (final key in keys)
        (
          item: (rightByKey[key]?.itemName ?? leftByKey[key]?.itemName ?? '').trim(),
          leftTermTotal: leftByKey[key]?.termTotal(months) ?? 0,
          rightTermTotal: rightByKey[key]?.termTotal(months) ?? 0,
          termTotalDelta: (rightByKey[key]?.termTotal(months) ?? 0) - (leftByKey[key]?.termTotal(months) ?? 0),
        ),
    ];
  }

  List<({
    String classLabel,
    int leftStudents,
    int rightStudents,
    int studentsDelta,
    double leftAmount,
    double rightAmount,
    double amountDelta,
    double leftTotal,
    double rightTotal,
    double totalDelta,
  })> _schoolFeeDiffRows(List<SchoolFeeBudgetRow> leftRows, List<SchoolFeeBudgetRow> rightRows) {
    final leftByKey = {
      for (final row in leftRows)
        '${row.classId ?? 'none'}:${row.classLabel.trim().toLowerCase()}': row,
    };
    final rightByKey = {
      for (final row in rightRows)
        '${row.classId ?? 'none'}:${row.classLabel.trim().toLowerCase()}': row,
    };
    final keys = {...leftByKey.keys, ...rightByKey.keys}.toList(growable: false)..sort();
    return [
      for (final key in keys)
        (
          classLabel: (rightByKey[key]?.classLabel ?? leftByKey[key]?.classLabel ?? '').trim(),
          leftStudents: leftByKey[key]?.studentCount ?? 0,
          rightStudents: rightByKey[key]?.studentCount ?? 0,
          studentsDelta: (rightByKey[key]?.studentCount ?? 0) - (leftByKey[key]?.studentCount ?? 0),
          leftAmount: leftByKey[key]?.amount ?? 0,
          rightAmount: rightByKey[key]?.amount ?? 0,
          amountDelta: (rightByKey[key]?.amount ?? 0) - (leftByKey[key]?.amount ?? 0),
          leftTotal: leftByKey[key]?.total ?? 0,
          rightTotal: rightByKey[key]?.total ?? 0,
          totalDelta: (rightByKey[key]?.total ?? 0) - (leftByKey[key]?.total ?? 0),
        ),
    ];
  }

  List<({
    String classLabel,
    int leftStudents,
    int rightStudents,
    int studentsDelta,
    double leftAmountPerChild,
    double rightAmountPerChild,
    double amountPerChildDelta,
    double leftTermTotal,
    double rightTermTotal,
    double termTotalDelta,
  })> _canteenFeeDiffRowsFromPlans(DirectorBudgetPlan leftPlan, DirectorBudgetPlan rightPlan) {
    final leftByKey = {
      for (final row in leftPlan.canteenFeeRows)
        '${row.classId ?? 'none'}:${row.classLabel.trim().toLowerCase()}': row,
    };
    final rightByKey = {
      for (final row in rightPlan.canteenFeeRows)
        '${row.classId ?? 'none'}:${row.classLabel.trim().toLowerCase()}': row,
    };
    final keys = {...leftByKey.keys, ...rightByKey.keys}.toList(growable: false)..sort();
    return [
      for (final key in keys)
        (
          classLabel: (rightByKey[key]?.classLabel ?? leftByKey[key]?.classLabel ?? '').trim(),
          leftStudents: leftByKey[key]?.studentCount ?? 0,
          rightStudents: rightByKey[key]?.studentCount ?? 0,
          studentsDelta: (rightByKey[key]?.studentCount ?? 0) - (leftByKey[key]?.studentCount ?? 0),
          leftAmountPerChild: leftByKey[key]?.amountPerChild ?? 0,
          rightAmountPerChild: rightByKey[key]?.amountPerChild ?? 0,
          amountPerChildDelta: (rightByKey[key]?.amountPerChild ?? 0) - (leftByKey[key]?.amountPerChild ?? 0),
          leftTermTotal: (leftByKey[key]?.termTotal(leftPlan.monthsInTerm)) ?? 0,
          rightTermTotal: (rightByKey[key]?.termTotal(rightPlan.monthsInTerm)) ?? 0,
          termTotalDelta: ((rightByKey[key]?.termTotal(rightPlan.monthsInTerm)) ?? 0) - ((leftByKey[key]?.termTotal(leftPlan.monthsInTerm)) ?? 0),
        ),
    ];
  }

  Future<void> _exportComparisonCsv(DirectorBudgetSnapshot left, DirectorBudgetSnapshot right) async {
    if (_comparisonExporting) return;
    setState(() => _comparisonExporting = true);
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export budget comparison CSV',
        fileName: 'director_budget_comparison_${left.academicYear}_t${left.term}_vs_${right.academicYear}_t${right.term}.csv',
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
      if (path == null) return;
      final normalized = path.endsWith('.csv') ? path : '$path.csv';

      final summaryRows = _comparisonSummaryRows(left, right);
      final months = left.plan.monthsInTerm;
      final canteenDiffs = _expenseDiffRows(left.plan.canteenExpenseRows, right.plan.canteenExpenseRows, months);
      final canteenFeeDiffs = _canteenFeeDiffRowsFromPlans(left.plan, right.plan);
      final schoolFeeDiffs = _schoolFeeDiffRows(left.plan.schoolFeeRows, right.plan.schoolFeeRows);
      final rows = <List<dynamic>>[
        ['Director Budget Snapshot Comparison'],
        ['Left Snapshot', _snapshotLabel(left)],
        ['Left Note', left.note ?? ''],
        ['Right Snapshot', _snapshotLabel(right)],
        ['Right Note', right.note ?? ''],
        [''],
        ['Summary'],
        ['Metric', 'Left', 'Right', 'Delta'],
        for (final row in summaryRows)
          [row.label, row.leftValue.toStringAsFixed(2), row.rightValue.toStringAsFixed(2), row.delta.toStringAsFixed(2)],
        [''],
        ['Canteen Expense Differences'],
        ['Item', 'Left Term Total', 'Right Term Total', 'Delta'],
        for (final row in canteenDiffs)
          [row.item, row.leftTermTotal.toStringAsFixed(2), row.rightTermTotal.toStringAsFixed(2), row.termTotalDelta.toStringAsFixed(2)],
        [''],
        ['Canteen Fee Differences'],
        ['Class', 'Left Students', 'Right Students', 'Students Delta', 'Left Amount/Child', 'Right Amount/Child', 'Amount Delta', 'Left Term Total', 'Right Term Total', 'Term Total Delta'],
        for (final row in canteenFeeDiffs)
          [row.classLabel, row.leftStudents, row.rightStudents, row.studentsDelta, row.leftAmountPerChild, row.rightAmountPerChild, row.amountPerChildDelta, row.leftTermTotal, row.rightTermTotal, row.termTotalDelta],
        [''],
        ['School Fee Differences'],
        ['Class', 'Left Students', 'Right Students', 'Students Delta', 'Left Amount', 'Right Amount', 'Amount Delta', 'Left Total', 'Right Total', 'Total Delta'],
        for (final row in schoolFeeDiffs)
          [row.classLabel, row.leftStudents, row.rightStudents, row.studentsDelta, row.leftAmount, row.rightAmount, row.amountDelta, row.leftTotal, row.rightTotal, row.totalDelta],
        [''],
        ['Payroll Differences'],
        ['Metric', 'Left', 'Right', 'Delta'],
        ['Monthly Salaries', left.plan.monthlySalaryBudget, right.plan.monthlySalaryBudget, right.plan.monthlySalaryBudget - left.plan.monthlySalaryBudget],
        ['Monthly Tax', left.plan.monthlyTaxBudget, right.plan.monthlyTaxBudget, right.plan.monthlyTaxBudget - left.plan.monthlyTaxBudget],
        ['Monthly SSNIT', left.plan.monthlySsnitBudget, right.plan.monthlySsnitBudget, right.plan.monthlySsnitBudget - left.plan.monthlySsnitBudget],
        ['Monthly Total', left.plan.monthlyPayrollTotal, right.plan.monthlyPayrollTotal, right.plan.monthlyPayrollTotal - left.plan.monthlyPayrollTotal],
        ['Term Total', left.plan.payrollBudgetPerTerm, right.plan.payrollBudgetPerTerm, right.plan.payrollBudgetPerTerm - left.plan.payrollBudgetPerTerm],
      ];

      final csv = const ListToCsvConverter().convert(rows);
      await File(normalized).writeAsString(csv);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Budget comparison CSV exported'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Comparison export failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _comparisonExporting = false);
    }
  }

  Future<Uint8List> _buildComparisonPdf({
    required DirectorBudgetSnapshot left,
    required DirectorBudgetSnapshot right,
    required InstitutionalIdentityData? schoolInfo,
    required PdfPageFormat pageFormat,
  }) async {
    final doc = pw.Document();
    late final pw.Font regular;
    late final pw.Font bold;
    try {
      regular = await PdfGoogleFonts.openSansRegular();
      bold = await PdfGoogleFonts.openSansBold();
    } catch (_) {
      regular = pw.Font.helvetica();
      bold = pw.Font.helveticaBold();
    }

    String money(double v) => 'GH₵ ${v.toStringAsFixed(2)}';
    final summaryRows = _comparisonSummaryRows(left, right);
    final months = left.plan.monthsInTerm;
    final canteenDiffs = _expenseDiffRows(left.plan.canteenExpenseRows, right.plan.canteenExpenseRows, months);
    final canteenFeeDiffs = _canteenFeeDiffRowsFromPlans(left.plan, right.plan);
    final schoolFeeDiffs = _schoolFeeDiffRows(left.plan.schoolFeeRows, right.plan.schoolFeeRows);

    final schoolName = (schoolInfo?.schoolName.trim().isNotEmpty == true) ? schoolInfo!.schoolName.trim() : 'School';
    final address = schoolInfo?.address?.trim();
    final phone = schoolInfo?.phoneNumber?.trim();
    final email = schoolInfo?.officialEmail.trim();

    pw.Widget infoLine(String? value) {
      final text = (value ?? '').trim();
      if (text.isEmpty) return pw.SizedBox.shrink();
      return pw.Text(text, style: pw.TextStyle(font: regular, fontSize: 9, color: PdfColors.grey700));
    }

    pw.Widget sectionTitle(String title) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10, bottom: 6),
        child: pw.Text(title, style: pw.TextStyle(font: bold, fontSize: 12, color: PdfColors.indigo900)),
      );
    }

    pw.Widget table({
      required List<String> headers,
      required List<List<String>> data,
      Map<int, pw.TableColumnWidth>? widths,
    }) {
      return pw.TableHelper.fromTextArray(
        headers: headers,
        data: data,
        headerStyle: pw.TextStyle(font: bold, color: PdfColors.white, fontSize: 8),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
        cellStyle: pw.TextStyle(font: regular, fontSize: 7.5),
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
        columnWidths: widths,
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 28),
        build: (context) => [
          pw.Text(schoolName, style: pw.TextStyle(font: bold, fontSize: 18, color: PdfColors.indigo900)),
          infoLine(address),
          infoLine([if (phone != null && phone.isNotEmpty) phone, if (email != null && email.isNotEmpty) email].join(' • ')),
          pw.SizedBox(height: 8),
          pw.Text('Director Budget Snapshot Comparison', style: pw.TextStyle(font: bold, fontSize: 15)),
          pw.Text(_snapshotLabel(left), style: pw.TextStyle(font: regular, fontSize: 10, color: PdfColors.grey700)),
          if ((left.note ?? '').isNotEmpty)
            pw.Text('Left note: ${left.note}', style: pw.TextStyle(font: regular, fontSize: 9, color: PdfColors.grey700)),
          pw.Text(_snapshotLabel(right), style: pw.TextStyle(font: regular, fontSize: 10, color: PdfColors.grey700)),
          if ((right.note ?? '').isNotEmpty)
            pw.Text('Right note: ${right.note}', style: pw.TextStyle(font: regular, fontSize: 9, color: PdfColors.grey700)),
          sectionTitle('Summary Metrics'),
          table(
            headers: const ['Metric', 'Left', 'Right', 'Delta'],
            data: [
              for (final row in summaryRows)
                [row.label, money(row.leftValue), money(row.rightValue), money(row.delta)],
            ],
            widths: const {
              0: pw.FlexColumnWidth(2.4),
              1: pw.FlexColumnWidth(1.2),
              2: pw.FlexColumnWidth(1.2),
              3: pw.FlexColumnWidth(1.2),
            },
          ),
          sectionTitle('Canteen Expense Changes'),
          table(
            headers: const ['Item', 'Left Term Total', 'Right Term Total', 'Delta'],
            data: [
              for (final row in canteenDiffs)
                [row.item, money(row.leftTermTotal), money(row.rightTermTotal), money(row.termTotalDelta)],
            ],
            widths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(1), 2: pw.FlexColumnWidth(1), 3: pw.FlexColumnWidth(1)},
          ),
          sectionTitle('Canteen Fee Changes'),
          table(
            headers: const ['Class', 'L Students', 'R Students', 'Delta', 'L Term Total', 'R Term Total', 'Total Delta'],
            data: [
              for (final row in canteenFeeDiffs)
                [row.classLabel, '${row.leftStudents}', '${row.rightStudents}', '${row.studentsDelta}', money(row.leftTermTotal), money(row.rightTermTotal), money(row.termTotalDelta)],
            ],
            widths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(0.8), 2: pw.FlexColumnWidth(0.8), 3: pw.FlexColumnWidth(0.8), 4: pw.FlexColumnWidth(1.1), 5: pw.FlexColumnWidth(1.1), 6: pw.FlexColumnWidth(1)},
          ),
          sectionTitle('School Fee Changes'),
          table(
            headers: const ['Class', 'L Students', 'R Students', 'Delta', 'L Total', 'R Total', 'Total Delta'],
            data: [
              for (final row in schoolFeeDiffs)
                [row.classLabel, '${row.leftStudents}', '${row.rightStudents}', '${row.studentsDelta}', money(row.leftTotal), money(row.rightTotal), money(row.totalDelta)],
            ],
            widths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(0.8), 2: pw.FlexColumnWidth(0.8), 3: pw.FlexColumnWidth(0.8), 4: pw.FlexColumnWidth(1.1), 5: pw.FlexColumnWidth(1.1), 6: pw.FlexColumnWidth(1)},
          ),
          sectionTitle('Payroll Changes'),
          table(
            headers: const ['Metric', 'Left', 'Right', 'Delta'],
            data: [
              ['Monthly Salaries', money(left.plan.monthlySalaryBudget), money(right.plan.monthlySalaryBudget), money(right.plan.monthlySalaryBudget - left.plan.monthlySalaryBudget)],
              ['Monthly Tax', money(left.plan.monthlyTaxBudget), money(right.plan.monthlyTaxBudget), money(right.plan.monthlyTaxBudget - left.plan.monthlyTaxBudget)],
              ['Monthly SSNIT', money(left.plan.monthlySsnitBudget), money(right.plan.monthlySsnitBudget), money(right.plan.monthlySsnitBudget - left.plan.monthlySsnitBudget)],
              ['Term Payroll Total', money(left.plan.payrollBudgetPerTerm), money(right.plan.payrollBudgetPerTerm), money(right.plan.payrollBudgetPerTerm - left.plan.payrollBudgetPerTerm)],
            ],
            widths: const {
              0: pw.FlexColumnWidth(2.2),
              1: pw.FlexColumnWidth(1.2),
              2: pw.FlexColumnWidth(1.2),
              3: pw.FlexColumnWidth(1.2),
            },
          ),
        ],
      ),
    );

    return doc.save();
  }

  Future<void> _openComparisonPdfPreview(DirectorBudgetSnapshot left, DirectorBudgetSnapshot right) async {
    if (_comparisonPrinting) return;
    setState(() => _comparisonPrinting = true);
    try {
      final schoolInfo = await ref.read(institutionalIdentityProvider.future);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfPreviewScreen(
            title: 'Budget Comparison PDF',
            subtitle: '${left.academicYear}/T${left.term} vs ${right.academicYear}/T${right.term}',
            pdfFileName: 'director_budget_comparison_${left.academicYear}_t${left.term}_vs_${right.academicYear}_t${right.term}.pdf',
            buildPdf: (format) => _buildComparisonPdf(
              left: left,
              right: right,
              schoolInfo: schoolInfo,
              pageFormat: format,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _comparisonPrinting = false);
    }
  }

  Future<void> _exportBudgetCsv(DirectorBudgetPlan plan, DirectorBudgetAnalytics analytics) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export director budget CSV',
        fileName: 'director_budget_term_${plan.term}_${plan.academicYear}.csv',
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
      if (path == null) return;
      final normalized = path.endsWith('.csv') ? path : '$path.csv';

      final rows = <List<dynamic>>[
        ['Director Budget Planner', 'Academic Year ${plan.academicYear}', 'Term ${plan.term}'],
        [''],
        ['Analytics'],
        ['Metric', 'Value'],
        ['Canteen Income Per Term', analytics.canteenIncomePerTerm.toStringAsFixed(2)],
        ['School Fees Per Term', analytics.schoolFeesPerTerm.toStringAsFixed(2)],
        ['Other Fees Per Term', analytics.otherFeesPerTerm.toStringAsFixed(2)],
        ['Total Income Per Term', analytics.totalIncomePerTerm.toStringAsFixed(2)],
        ['Total Expenses Per Term', analytics.totalExpensesPerTerm.toStringAsFixed(2)],
        ['Projected Balance', analytics.projectedBalance.toStringAsFixed(2)],
        [''],
        ['Canteen Expenses'],
        ['Item Name', 'Unit Price', for (var m = 1; m <= plan.monthsInTerm; m++) ...[  'M$m Qty', 'M$m Amount'], 'Term Total'],
        for (final row in plan.canteenExpenseRows)
          [row.itemName, row.unitPrice, for (var m = 0; m < plan.monthsInTerm; m++) ...[row.quantityForMonth(m), row.amountForMonth(m)], row.termTotal(plan.monthsInTerm)],
        [''],
        ['Canteen Fees'],
        ['Class', 'Students', 'Amount Per Child', 'Total', 'Days Per Week', 'Days in Week Total', 'Weeks Per Month', 'Week in Month Total', 'Term Total'],
        for (final row in plan.canteenFeeRows)
          [row.classLabel, row.studentCount, row.amountPerChild, row.total, row.daysPerWeek, row.daysInWeekTotal, row.weeksPerMonth, row.weekInMonthTotal, row.termTotal(plan.monthsInTerm)],
        [''],
        ['School Fees'],
        ['Class', 'Total Students', 'Amount', 'Total'],
        for (final row in plan.schoolFeeRows)
          [row.classLabel, row.studentCount, row.amount, row.total],
        [''],
        ['Payroll Budget'],
        ['Monthly Salaries', 'Monthly Tax', 'Monthly SSNIT', 'Monthly Total', 'Term Total'],
        [plan.monthlySalaryBudget, plan.monthlyTaxBudget, plan.monthlySsnitBudget, plan.monthlyPayrollTotal, plan.payrollBudgetPerTerm],
      ];

      final csv = const ListToCsvConverter().convert(rows);
      await File(normalized).writeAsString(csv);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Director budget CSV exported'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<Uint8List> _buildBudgetPdf({
    required DirectorBudgetPlan plan,
    required DirectorBudgetAnalytics analytics,
    required InstitutionalIdentityData? schoolInfo,
    required PdfPageFormat pageFormat,
  }) async {
    final doc = pw.Document();
    late final pw.Font regular;
    late final pw.Font bold;
    try {
      regular = await PdfGoogleFonts.openSansRegular();
      bold = await PdfGoogleFonts.openSansBold();
    } catch (_) {
      regular = pw.Font.helvetica();
      bold = pw.Font.helveticaBold();
    }

    String money(double v) => 'GH₵ ${v.toStringAsFixed(2)}';
    final schoolName = (schoolInfo?.schoolName.trim().isNotEmpty == true) ? schoolInfo!.schoolName.trim() : 'School';
    final address = schoolInfo?.address?.trim();
    final phone = schoolInfo?.phoneNumber?.trim();
    final email = schoolInfo?.officialEmail.trim();

    pw.Widget infoLine(String? value) {
      final text = (value ?? '').trim();
      if (text.isEmpty) return pw.SizedBox.shrink();
      return pw.Text(text, style: pw.TextStyle(font: regular, fontSize: 9, color: PdfColors.grey700));
    }

    pw.Widget sectionTitle(String title) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10, bottom: 6),
        child: pw.Text(title, style: pw.TextStyle(font: bold, fontSize: 12, color: PdfColors.indigo900)),
      );
    }

    pw.Widget summaryTable(List<List<String>> data) {
      return pw.TableHelper.fromTextArray(
        headers: const ['Metric', 'Value'],
        data: data,
        headerStyle: pw.TextStyle(font: bold, color: PdfColors.white, fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
        cellStyle: pw.TextStyle(font: regular, fontSize: 8.5),
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(1)},
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 28),
        build: (context) => [
          pw.Text(schoolName, style: pw.TextStyle(font: bold, fontSize: 18, color: PdfColors.indigo900)),
          infoLine(address),
          infoLine([if (phone != null && phone.isNotEmpty) phone, if (email != null && email.isNotEmpty) email].join(' • ')),
          pw.SizedBox(height: 8),
          pw.Text('Director Budget Planner', style: pw.TextStyle(font: bold, fontSize: 15)),
          pw.Text('Academic Year ${plan.academicYear} • Term ${plan.term}', style: pw.TextStyle(font: regular, fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 8),
          sectionTitle('Analytics'),
          summaryTable([
            ['Canteen Income Per Term', money(analytics.canteenIncomePerTerm)],
            ['School Fees Per Term', money(analytics.schoolFeesPerTerm)],
            ['Other Fees Per Term', money(analytics.otherFeesPerTerm)],
            ['Total Income Per Term', money(analytics.totalIncomePerTerm)],
            ['Total Expenses Per Term', money(analytics.totalExpensesPerTerm)],
            ['Projected Balance', money(analytics.projectedBalance)],
            ['Actual Income Per Term', money(analytics.actualIncomePerTerm)],
            ['Actual Expenses Per Term', money(analytics.actualExpensesPerTerm)],
            ['Balance Variance', money(analytics.balanceVariance)],
          ]),
          sectionTitle('Canteen Expenses'),
          pw.TableHelper.fromTextArray(
            headers: [
              'Item',
              'Unit Price',
              for (var m = 1; m <= plan.monthsInTerm; m++) ...[
                'M$m Qty',
                'M$m Amount',
              ],
              'Term Total',
            ],
            data: plan.canteenExpenseRows.map((row) => [
              row.itemName,
              money(row.unitPrice),
              for (var m = 0; m < plan.monthsInTerm; m++) ...[
                row.quantityForMonth(m).toStringAsFixed(0),
                money(row.amountForMonth(m)),
              ],
              money(row.termTotal(plan.monthsInTerm)),
            ]).toList(growable: false),
            headerStyle: pw.TextStyle(font: bold, color: PdfColors.white, fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
            cellStyle: pw.TextStyle(font: regular, fontSize: 7.8),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
          ),
          sectionTitle('Canteen Budget Fees'),
          pw.TableHelper.fromTextArray(
            headers: const ['Class', 'Students', 'Amt/Child', 'Total', 'Days/Week', 'Week Total', 'Weeks/Month', 'Month Total', 'Term Total'],
            data: plan.canteenFeeRows.map((row) => [row.classLabel, '${row.studentCount}', money(row.amountPerChild), money(row.total), row.daysPerWeek.toStringAsFixed(0), money(row.daysInWeekTotal), row.weeksPerMonth.toStringAsFixed(0), money(row.weekInMonthTotal), money(row.termTotal(plan.monthsInTerm))]).toList(growable: false),
            headerStyle: pw.TextStyle(font: bold, color: PdfColors.white, fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
            cellStyle: pw.TextStyle(font: regular, fontSize: 7.8),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
          ),
          sectionTitle('School Fees Budget'),
          pw.TableHelper.fromTextArray(
            headers: const ['Class', 'Students', 'Amount', 'Total'],
            data: plan.schoolFeeRows.map((row) => [row.classLabel, '${row.studentCount}', money(row.amount), money(row.total)]).toList(growable: false),
            headerStyle: pw.TextStyle(font: bold, color: PdfColors.white, fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
            cellStyle: pw.TextStyle(font: regular, fontSize: 7.8),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
          ),
          sectionTitle('Payroll Budget'),
          summaryTable([
            ['Monthly Salaries', money(plan.monthlySalaryBudget)],
            ['Monthly Tax', money(plan.monthlyTaxBudget)],
            ['Monthly SSNIT', money(plan.monthlySsnitBudget)],
            ['Monthly Total', money(plan.monthlyPayrollTotal)],
            ['Term Total', money(plan.payrollBudgetPerTerm)],
          ]),
        ],
      ),
    );

    return doc.save();
  }

  Future<void> _openBudgetPdfPreview(DirectorBudgetPlan plan, DirectorBudgetAnalytics analytics) async {
    final schoolInfo = await ref.read(institutionalIdentityProvider.future);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(
          title: 'Director Budget PDF',
          subtitle: 'Academic Year ${plan.academicYear} • Term ${plan.term}',
          pdfFileName: 'director_budget_term_${plan.term}_${plan.academicYear}.pdf',
          buildPdf: (format) => _buildBudgetPdf(
            plan: plan,
            analytics: analytics,
            schoolInfo: schoolInfo,
            pageFormat: format,
          ),
        ),
      ),
    );
  }

  Widget _budgetSnapshotRow(DirectorBudgetPlan plan, int academicYear, int term) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _SimpleStat(label: 'Academic Year', value: '$academicYear'),
        _SimpleStat(label: 'Term', value: '$term'),
        _SimpleStat(label: 'Months in Term', value: '${plan.monthsInTerm}'),
        SizedBox(
          width: 180,
          child: TextFormField(
            key: ValueKey('months-${plan.monthsInTerm}'),
            initialValue: '${plan.monthsInTerm}',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Months in term',
              isDense: true,
            ),
            onChanged: (value) {
              final parsed = _parseCount(value);
              _setPlan(plan.copyWith(monthsInTerm: parsed == 0 ? 3 : parsed.clamp(1, 12)));
            },
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => context.go('/settings'),
          icon: const Icon(Icons.settings_outlined),
          label: const Text('Academic Year & Term'),
        ),
        FilledButton.tonal(
          onPressed: _saveInProgress ? null : () => _saveDraft(successMessage: 'Planner settings saved', showFeedback: true),
          child: Text(_autosaving ? 'Auto-saving…' : 'Save Planner Settings'),
        ),
        Text(
          _draftStatusText(),
          style: const TextStyle(color: AppTheme.textMuted),
        ),
      ],
    );
  }

  Widget _analyticsSection(DirectorBudgetAnalytics analytics) {
    final incomeVarianceColor = _varianceColor(analytics.incomeVariance);
    final expenseVarianceColor = _varianceColor(analytics.expenseVariance, lowerIsBetter: true);
    final balanceVarianceColor = _varianceColor(analytics.balanceVariance);
    return _sectionCard(
      title: 'Term Analytics',
      subtitle: 'Projected totals, actual recorded totals, and variance for the active term.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _analyticsTile(label: 'Canteen Income', value: _money(analytics.canteenIncomePerTerm)),
              _analyticsTile(label: 'School Fees', value: _money(analytics.schoolFeesPerTerm)),
              _analyticsTile(label: 'Other Fee Structures', value: _money(analytics.otherFeesPerTerm)),
              _analyticsTile(label: 'Total Income', value: _money(analytics.totalIncomePerTerm)),
              _analyticsTile(label: 'Total Expenses', value: _money(analytics.totalExpensesPerTerm)),
              _analyticsTile(label: 'Projected Balance', value: _money(analytics.projectedBalance)),
              _analyticsTile(
                label: 'Actual Income',
                value: _money(analytics.actualIncomePerTerm),
                valueColor: Colors.green.shade700,
                backgroundColor: Colors.green.withValues(alpha: 0.06),
              ),
              _analyticsTile(
                label: 'Actual Expenses',
                value: _money(analytics.actualExpensesPerTerm),
                valueColor: Colors.deepOrange.shade700,
                backgroundColor: Colors.orange.withValues(alpha: 0.06),
              ),
              _analyticsTile(label: 'Actual Balance', value: _money(analytics.actualBalance)),
              _analyticsTile(
                label: 'Income Variance',
                value: _money(analytics.incomeVariance),
                valueColor: incomeVarianceColor,
                backgroundColor: _varianceTint(analytics.incomeVariance),
              ),
              _analyticsTile(
                label: 'Expense Variance',
                value: _money(analytics.expenseVariance),
                valueColor: expenseVarianceColor,
                backgroundColor: _varianceTint(analytics.expenseVariance, lowerIsBetter: true),
              ),
              _analyticsTile(
                label: 'Balance Variance',
                value: _money(analytics.balanceVariance),
                valueColor: balanceVarianceColor,
                backgroundColor: _varianceTint(analytics.balanceVariance),
              ),
              _analyticsTile(label: 'Canteen Purchasing', value: _money(analytics.canteenPurchasingPerTerm)),
              _analyticsTile(label: 'Salaries', value: _money(analytics.salariesPerTerm)),
              _analyticsTile(label: 'Tax', value: _money(analytics.taxPerTerm)),
              _analyticsTile(label: 'SSNIT', value: _money(analytics.ssnitPerTerm)),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Planned vs Actual', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text(
            'Grey bars show the plan. Colored bars show the recorded outcome for the current term.',
            style: TextStyle(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 12),
          _plannedVsActualChart(analytics),
        ],
      ),
    );
  }

  Widget _comparisonSection(
    List<DirectorBudgetSnapshot> visibleSnapshots,
    DirectorBudgetSnapshot left,
    DirectorBudgetSnapshot right,
    int academicYear,
    int term,
  ) {
    final summaryRows = _comparisonSummaryRows(left, right);
    final months = left.plan.monthsInTerm;
    final canteenDiffs = _expenseDiffRows(left.plan.canteenExpenseRows, right.plan.canteenExpenseRows, months);
    final canteenFeeDiffs = _canteenFeeDiffRowsFromPlans(left.plan, right.plan);
    final schoolFeeDiffs = _schoolFeeDiffRows(left.plan.schoolFeeRows, right.plan.schoolFeeRows);

    Widget sectionTable({
      required String title,
      required List<Widget> header,
      required List<List<Widget>> rows,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: header),
                for (final row in rows) Row(children: row),
              ],
            ),
          ),
        ],
      );
    }

    return _sectionCard(
      title: 'Snapshot Comparison',
      subtitle: 'Compare any two saved revisions from the current filter and export the differences as CSV or PDF.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 340,
                child: DropdownButtonFormField<String>(
                  initialValue: _comparisonLeftId,
                  decoration: const InputDecoration(labelText: 'Left snapshot', isDense: true),
                  items: [
                    for (final snapshot in visibleSnapshots)
                      DropdownMenuItem<String>(
                        value: _snapshotId(snapshot),
                        child: Text(_snapshotLabel(snapshot), overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _comparisonLeftId = value);
                  },
                ),
              ),
              SizedBox(
                width: 340,
                child: DropdownButtonFormField<String>(
                  initialValue: _comparisonRightId,
                  decoration: const InputDecoration(labelText: 'Right snapshot', isDense: true),
                  items: [
                    for (final snapshot in visibleSnapshots)
                      DropdownMenuItem<String>(
                        value: _snapshotId(snapshot),
                        child: Text(_snapshotLabel(snapshot), overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _comparisonRightId = value);
                  },
                ),
              ),
              OutlinedButton.icon(
                onPressed: _comparisonExporting ? null : () => _exportComparisonCsv(left, right),
                icon: const Icon(Icons.compare_arrows_outlined),
                label: Text(_comparisonExporting ? 'Exporting…' : 'Export Comparison CSV'),
              ),
              OutlinedButton.icon(
                onPressed: _comparisonPrinting ? null : () => _openComparisonPdfPreview(left, right),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: Text(_comparisonPrinting ? 'Preparing…' : 'Print / Preview PDF'),
              ),
              OutlinedButton.icon(
                onPressed: () => _restoreSnapshot(left, academicYear, term),
                icon: const Icon(Icons.vertical_align_bottom_outlined),
                label: const Text('Load Left'),
              ),
              OutlinedButton.icon(
                onPressed: () => _restoreSnapshot(right, academicYear, term),
                icon: const Icon(Icons.vertical_align_bottom_outlined),
                label: const Text('Load Right'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _analyticsTile(label: 'Left Snapshot', value: _snapshotLabel(left)),
              _analyticsTile(label: 'Right Snapshot', value: _snapshotLabel(right)),
            ],
          ),
          if ((left.note ?? '').isNotEmpty || (right.note ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Revision Notes', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    _SimpleStat(label: 'Left', value: (left.note ?? '').isEmpty ? 'No note' : left.note!),
                    const SizedBox(height: 6),
                    _SimpleStat(label: 'Right', value: (right.note ?? '').isEmpty ? 'No note' : right.note!),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          sectionTable(
            title: 'Summary Metrics',
            header: [
              _headerCell('Metric', width: 170),
              _headerCell('Left', width: 130),
              _headerCell('Right', width: 130),
              _headerCell('Delta', width: 130),
            ],
            rows: [
              for (final row in summaryRows)
                [
                  _valueCell(row.label, width: 170, textAlign: TextAlign.left),
                  _valueCell(_money(row.leftValue), width: 130),
                  _valueCell(_money(row.rightValue), width: 130),
                  _valueCell(
                    _money(row.delta),
                    width: 130,
                    textColor: _varianceColor(row.delta, lowerIsBetter: row.lowerIsBetter),
                    backgroundColor: _varianceTint(row.delta, lowerIsBetter: row.lowerIsBetter),
                  ),
                ],
            ],
          ),
          const SizedBox(height: 16),
          sectionTable(
            title: 'Canteen Expense Changes',
            header: [
              _headerCell('Item', width: 160),
              _headerCell('Left Term Total', width: 120),
              _headerCell('Right Term Total', width: 120),
              _headerCell('Delta', width: 120),
            ],
            rows: [
              for (final row in canteenDiffs)
                [
                  _valueCell(row.item, width: 160, textAlign: TextAlign.left),
                  _valueCell(_money(row.leftTermTotal), width: 120),
                  _valueCell(_money(row.rightTermTotal), width: 120),
                  _valueCell(
                    _money(row.termTotalDelta),
                    width: 120,
                    textColor: _varianceColor(row.termTotalDelta, lowerIsBetter: true),
                    backgroundColor: _varianceTint(row.termTotalDelta, lowerIsBetter: true),
                  ),
                ],
            ],
          ),
          const SizedBox(height: 16),
          sectionTable(
            title: 'Canteen Fee Changes',
            header: [
              _headerCell('Class', width: 160),
              _headerCell('L Students', width: 95),
              _headerCell('R Students', width: 95),
              _headerCell('Student Delta', width: 110),
              _headerCell('Left Term Total', width: 130),
              _headerCell('Right Term Total', width: 130),
              _headerCell('Delta', width: 120),
            ],
            rows: [
              for (final row in canteenFeeDiffs)
                [
                  _valueCell(row.classLabel, width: 160, textAlign: TextAlign.left),
                  _valueCell('${row.leftStudents}', width: 95, textAlign: TextAlign.center),
                  _valueCell('${row.rightStudents}', width: 95, textAlign: TextAlign.center),
                  _valueCell(
                    '${row.studentsDelta}',
                    width: 110,
                    textAlign: TextAlign.center,
                    textColor: _studentDeltaColor(row.studentsDelta),
                    backgroundColor: _studentDeltaTint(row.studentsDelta),
                  ),
                  _valueCell(_money(row.leftTermTotal), width: 130),
                  _valueCell(_money(row.rightTermTotal), width: 130),
                  _valueCell(
                    _money(row.termTotalDelta),
                    width: 120,
                    textColor: _varianceColor(row.termTotalDelta),
                    backgroundColor: _varianceTint(row.termTotalDelta),
                  ),
                ],
            ],
          ),
          const SizedBox(height: 16),
          sectionTable(
            title: 'School Fee Changes',
            header: [
              _headerCell('Class', width: 160),
              _headerCell('L Students', width: 95),
              _headerCell('R Students', width: 95),
              _headerCell('Student Delta', width: 110),
              _headerCell('Left Total', width: 130),
              _headerCell('Right Total', width: 130),
              _headerCell('Delta', width: 120),
            ],
            rows: [
              for (final row in schoolFeeDiffs)
                [
                  _valueCell(row.classLabel, width: 160, textAlign: TextAlign.left),
                  _valueCell('${row.leftStudents}', width: 95, textAlign: TextAlign.center),
                  _valueCell('${row.rightStudents}', width: 95, textAlign: TextAlign.center),
                  _valueCell(
                    '${row.studentsDelta}',
                    width: 110,
                    textAlign: TextAlign.center,
                    textColor: _studentDeltaColor(row.studentsDelta),
                    backgroundColor: _studentDeltaTint(row.studentsDelta),
                  ),
                  _valueCell(_money(row.leftTotal), width: 130),
                  _valueCell(_money(row.rightTotal), width: 130),
                  _valueCell(
                    _money(row.totalDelta),
                    width: 120,
                    textColor: _varianceColor(row.totalDelta),
                    backgroundColor: _varianceTint(row.totalDelta),
                  ),
                ],
            ],
          ),
          const SizedBox(height: 16),
          sectionTable(
            title: 'Payroll Changes',
            header: [
              _headerCell('Metric', width: 170),
              _headerCell('Left', width: 120),
              _headerCell('Right', width: 120),
              _headerCell('Delta', width: 120),
            ],
            rows: [
              [
                _valueCell('Monthly Salaries', width: 170, textAlign: TextAlign.left),
                _valueCell(_money(left.plan.monthlySalaryBudget), width: 120),
                _valueCell(_money(right.plan.monthlySalaryBudget), width: 120),
                _valueCell(
                  _money(right.plan.monthlySalaryBudget - left.plan.monthlySalaryBudget),
                  width: 120,
                  textColor: _varianceColor(right.plan.monthlySalaryBudget - left.plan.monthlySalaryBudget, lowerIsBetter: true),
                  backgroundColor: _varianceTint(right.plan.monthlySalaryBudget - left.plan.monthlySalaryBudget, lowerIsBetter: true),
                ),
              ],
              [
                _valueCell('Monthly Tax', width: 170, textAlign: TextAlign.left),
                _valueCell(_money(left.plan.monthlyTaxBudget), width: 120),
                _valueCell(_money(right.plan.monthlyTaxBudget), width: 120),
                _valueCell(
                  _money(right.plan.monthlyTaxBudget - left.plan.monthlyTaxBudget),
                  width: 120,
                  textColor: _varianceColor(right.plan.monthlyTaxBudget - left.plan.monthlyTaxBudget, lowerIsBetter: true),
                  backgroundColor: _varianceTint(right.plan.monthlyTaxBudget - left.plan.monthlyTaxBudget, lowerIsBetter: true),
                ),
              ],
              [
                _valueCell('Monthly SSNIT', width: 170, textAlign: TextAlign.left),
                _valueCell(_money(left.plan.monthlySsnitBudget), width: 120),
                _valueCell(_money(right.plan.monthlySsnitBudget), width: 120),
                _valueCell(
                  _money(right.plan.monthlySsnitBudget - left.plan.monthlySsnitBudget),
                  width: 120,
                  textColor: _varianceColor(right.plan.monthlySsnitBudget - left.plan.monthlySsnitBudget, lowerIsBetter: true),
                  backgroundColor: _varianceTint(right.plan.monthlySsnitBudget - left.plan.monthlySsnitBudget, lowerIsBetter: true),
                ),
              ],
              [
                _valueCell('Term Payroll Total', width: 170, textAlign: TextAlign.left),
                _valueCell(_money(left.plan.payrollBudgetPerTerm), width: 120),
                _valueCell(_money(right.plan.payrollBudgetPerTerm), width: 120),
                _valueCell(
                  _money(right.plan.payrollBudgetPerTerm - left.plan.payrollBudgetPerTerm),
                  width: 120,
                  textColor: _varianceColor(right.plan.payrollBudgetPerTerm - left.plan.payrollBudgetPerTerm, lowerIsBetter: true),
                  backgroundColor: _varianceTint(right.plan.payrollBudgetPerTerm - left.plan.payrollBudgetPerTerm, lowerIsBetter: true),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _snapshotHistorySection(List<DirectorBudgetSnapshot> snapshots, int academicYear, int term) {
    final relevant = _filteredSnapshotsFor(snapshots, academicYear, term);
    final left = _findSnapshotById(relevant, _comparisonLeftId);
    final right = _findSnapshotById(relevant, _comparisonRightId);

    return _sectionCard(
      title: 'Budget Snapshot History',
      subtitle: 'Recent saved term budgets for comparison. Use Update to replace the current term snapshot or Save Revision to keep multiple versions.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<_SnapshotFilter>(
                  initialValue: _snapshotFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'History filter', isDense: true),
                  items: const [
                    DropdownMenuItem(value: _SnapshotFilter.all, child: Text('All snapshots')),
                    DropdownMenuItem(value: _SnapshotFilter.currentYear, child: Text('Current academic year')),
                    DropdownMenuItem(value: _SnapshotFilter.currentTerm, child: Text('Current term only')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    final nextVisible = switch (value) {
                      _SnapshotFilter.all => snapshots,
                      _SnapshotFilter.currentYear => snapshots.where((row) => row.academicYear == academicYear).take(12).toList(growable: false),
                      _SnapshotFilter.currentTerm => snapshots.where((row) => row.academicYear == academicYear && row.term == term).take(12).toList(growable: false),
                    };
                    setState(() {
                      _snapshotFilter = value;
                      _syncComparisonSelection(nextVisible);
                    });
                  },
                ),
              ),
              Text(
                '${relevant.length} snapshot${relevant.length == 1 ? '' : 's'} visible',
                style: const TextStyle(color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (relevant.isEmpty)
            const Text('No budget snapshots saved yet.', style: TextStyle(color: AppTheme.textMuted))
          else ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _headerCell('Academic Year', width: 120),
                      _headerCell('Term', width: 70),
                      _headerCell('Saved At', width: 160),
                      _headerCell('Note', width: 180),
                      _headerCell('Planned Income', width: 130),
                      _headerCell('Planned Expenses', width: 135),
                      _headerCell('Actual Income', width: 130),
                      _headerCell('Actual Expenses', width: 135),
                      _headerCell('Balance Variance', width: 145),
                      _headerCell('', width: 86),
                    ],
                  ),
                  for (final row in relevant)
                    Row(
                      children: [
                        _valueCell('${row.academicYear}', width: 120, textAlign: TextAlign.center),
                        _valueCell('${row.term}', width: 70, textAlign: TextAlign.center),
                        _valueCell(DateFormat('yyyy-MM-dd HH:mm').format(row.savedAt), width: 160, textAlign: TextAlign.left),
                        _valueCell((row.note ?? '').isEmpty ? 'No note' : row.note!, width: 180, textAlign: TextAlign.left),
                        _valueCell(_money(row.totalIncomePerTerm), width: 130),
                        _valueCell(_money(row.totalExpensesPerTerm), width: 135),
                        _valueCell(_money(row.actualIncomePerTerm), width: 130),
                        _valueCell(_money(row.actualExpensesPerTerm), width: 135),
                        _valueCell(
                          _money(row.balanceVariance),
                          width: 145,
                          textColor: _varianceColor(row.balanceVariance),
                          backgroundColor: _varianceTint(row.balanceVariance),
                        ),
                        SizedBox(
                          width: 86,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: OutlinedButton(
                              onPressed: () => _restoreSnapshot(row, academicYear, term),
                              child: const Text('Load'),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (left != null && right != null && _snapshotId(left) != _snapshotId(right)) ...[
              const SizedBox(height: 16),
              _comparisonSection(relevant, left, right, academicYear, term),
            ],
          ],
        ],
      ),
    );
  }

  Widget _canteenExpenseBudgetTable({
    required List<BudgetExpenseRow> rows,
    required int monthsInTerm,
    required ValueChanged<List<BudgetExpenseRow>> onChanged,
  }) {
    // Compute dynamic total table width: 160 (item) + 110 (price) + months*(90+110) + 130 (term total) + 56 (delete)
    final monthColWidth = 90.0; // qty per month
    final amountColWidth = 110.0; // amount per month
    final tableWidth = 160 + 110 + monthsInTerm * (monthColWidth + amountColWidth) + 130 + 56;

    return _sectionCard(
      title: 'Canteen Expenses Table',
      subtitle: 'Item name, unit price, quantity for each month of the term, monthly amount, and term total.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _headerCell('Item Name', width: 160),
                    _headerCell('Unit Price', width: 110),
                    for (var m = 1; m <= monthsInTerm; m++) ...[
                      _headerCell('M$m Qty', width: monthColWidth),
                      _headerCell('M$m Amount', width: amountColWidth),
                    ],
                    _headerCell('Term Total', width: 130),
                    _headerCell('', width: 56),
                  ],
                ),
                if (rows.isEmpty)
                  Container(
                    width: tableWidth,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(border: Border.all(color: AppTheme.border)),
                    child: const Text('No rows added yet.', style: TextStyle(color: AppTheme.textMuted)),
                  )
                else
                  for (var index = 0; index < rows.length; index++)
                    Row(
                      children: [
                        _textCell(
                          key: ValueKey('ce-item-$index-${rows[index].itemName}'),
                          width: 160,
                          initialValue: rows[index].itemName,
                          hint: 'Rice, oil, sugar...',
                          onChanged: (value) {
                            final updated = [...rows];
                            updated[index] = updated[index].copyWith(itemName: value);
                            onChanged(updated);
                          },
                        ),
                        _textCell(
                          key: ValueKey('ce-price-$index-${rows[index].unitPrice}'),
                          width: 110,
                          initialValue: rows[index].unitPrice == 0 ? '' : rows[index].unitPrice.toStringAsFixed(2),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          hint: '0.00',
                          onChanged: (value) {
                            final updated = [...rows];
                            updated[index] = updated[index].copyWith(unitPrice: _parseMoney(value));
                            onChanged(updated);
                          },
                        ),
                        for (var m = 0; m < monthsInTerm; m++) ...[
                          _textCell(
                            key: ValueKey('ce-qty-$index-$m-${rows[index].quantityForMonth(m)}'),
                            width: monthColWidth,
                            initialValue: rows[index].quantityForMonth(m) == 0 ? '' : rows[index].quantityForMonth(m).toStringAsFixed(0),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            hint: '0',
                            onChanged: (value) {
                              final updated = [...rows];
                              final qty = _parseMoney(value);
                              final qtys = List<double>.from(
                                List.generate(
                                  updated[index].monthlyQuantities.length < monthsInTerm
                                      ? monthsInTerm
                                      : updated[index].monthlyQuantities.length,
                                  (i) => updated[index].quantityForMonth(i),
                                ),
                              );
                              while (qtys.length <= m) {
                                qtys.add(0);
                              }
                              qtys[m] = qty;
                              updated[index] = updated[index].copyWith(monthlyQuantities: qtys);
                              onChanged(updated);
                            },
                          ),
                          _valueCell(_money(rows[index].amountForMonth(m)), width: amountColWidth),
                        ],
                        _valueCell(_money(rows[index].termTotal(monthsInTerm)), width: 130),
                        SizedBox(
                          width: 56,
                          child: IconButton(
                            onPressed: () {
                              final updated = [...rows]..removeAt(index);
                              onChanged(updated);
                            },
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ),
                      ],
                    ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => onChanged([...rows, BudgetExpenseRow.empty()]),
                icon: const Icon(Icons.add),
                label: const Text('Add Row'),
              ),
              FilledButton.tonal(
                onPressed: _saveInProgress ? null : () => _saveDraft(successMessage: 'Canteen Expenses saved', showFeedback: true),
                child: Text(_autosaving ? 'Auto-saving…' : 'Save Canteen Expenses'),
              ),
              Text(
                'Term total: ${_money(rows.fold<double>(0, (sum, row) => sum + row.termTotal(monthsInTerm)))}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(_draftStatusText(), style: const TextStyle(color: AppTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _canteenFeesTable(List<CanteenFeeBudgetRow> rows, List<SchoolClassesData> classes, DirectorBudgetPlan plan) {
    String classLabelForId(int? id) {
      if (id == null) return '';
      for (final schoolClass in classes) {
        if (schoolClass.id == id) return schoolClass.className;
      }
      return 'Class #$id';
    }

    return _sectionCard(
      title: 'Canteen Budget Fees',
      subtitle: 'Class, number of students, amount per child, daily and term totals.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _headerCell('Class', width: 170),
                    _headerCell('Students', width: 90),
                    _headerCell('Amount / Child', width: 120),
                    _headerCell('Total', width: 120),
                    _headerCell('Days / Week', width: 100),
                    _headerCell('Days in Week Total', width: 150),
                    _headerCell('Weeks / Month', width: 110),
                    _headerCell('Week in Month Total', width: 170),
                    _headerCell('Total for Term', width: 150),
                    _headerCell('', width: 56),
                  ],
                ),
                if (rows.isEmpty)
                  Container(
                    width: 1236,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(border: Border.all(color: AppTheme.border)),
                    child: const Text('No class rows added yet.', style: TextStyle(color: AppTheme.textMuted)),
                  )
                else
                  for (var index = 0; index < rows.length; index++)
                    Row(
                      children: [
                        SizedBox(
                          width: 170,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: DropdownButtonFormField<int?>(
                              initialValue: rows[index].classId,
                              decoration: const InputDecoration(isDense: true),
                              items: [
                                const DropdownMenuItem<int?>(value: null, child: Text('Select class')),
                                ...classes.map(
                                  (schoolClass) => DropdownMenuItem<int?>(
                                    value: schoolClass.id,
                                    child: Text(schoolClass.className),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                final updated = [...rows];
                                updated[index] = updated[index].copyWith(
                                  classId: value,
                                  clearClassId: value == null,
                                  classLabel: classLabelForId(value),
                                  studentCount: value == null ? 0 : (_classStudentCounts[value] ?? 0),
                                );
                                _setPlan(plan.copyWith(canteenFeeRows: updated));
                              },
                            ),
                          ),
                        ),
                        _valueCell('${rows[index].studentCount}', width: 90, textAlign: TextAlign.center),
                        _textCell(
                          key: ValueKey('canteen-amount-$index-${rows[index].amountPerChild}'),
                          width: 120,
                          initialValue: rows[index].amountPerChild == 0 ? '' : rows[index].amountPerChild.toStringAsFixed(2),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (value) {
                            final updated = [...rows];
                            updated[index] = updated[index].copyWith(amountPerChild: _parseMoney(value));
                            _setPlan(plan.copyWith(canteenFeeRows: updated));
                          },
                        ),
                        _valueCell(_money(rows[index].total), width: 120),
                        _textCell(
                          key: ValueKey('canteen-days-$index-${rows[index].daysPerWeek}'),
                          width: 100,
                          initialValue: rows[index].daysPerWeek == 0 ? '' : rows[index].daysPerWeek.toStringAsFixed(0),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (value) {
                            final updated = [...rows];
                            updated[index] = updated[index].copyWith(daysPerWeek: _parseMoney(value));
                            _setPlan(plan.copyWith(canteenFeeRows: updated));
                          },
                        ),
                        _valueCell(_money(rows[index].daysInWeekTotal), width: 150),
                        _textCell(
                          key: ValueKey('canteen-weeks-$index-${rows[index].weeksPerMonth}'),
                          width: 110,
                          initialValue: rows[index].weeksPerMonth == 0 ? '' : rows[index].weeksPerMonth.toStringAsFixed(0),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (value) {
                            final updated = [...rows];
                            updated[index] = updated[index].copyWith(weeksPerMonth: _parseMoney(value));
                            _setPlan(plan.copyWith(canteenFeeRows: updated));
                          },
                        ),
                        _valueCell(_money(rows[index].weekInMonthTotal), width: 170),
                        _valueCell(_money(rows[index].termTotal(plan.monthsInTerm)), width: 150),
                        SizedBox(
                          width: 56,
                          child: IconButton(
                            onPressed: () {
                              final updated = [...rows]..removeAt(index);
                              _setPlan(plan.copyWith(canteenFeeRows: updated));
                            },
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ),
                      ],
                    ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _setPlan(plan.copyWith(canteenFeeRows: [...rows, CanteenFeeBudgetRow.empty()])),
                icon: const Icon(Icons.add),
                label: const Text('Add Class Row'),
              ),
              FilledButton.tonal(
                onPressed: _saveInProgress ? null : () => _saveDraft(successMessage: 'Canteen fee budget saved', showFeedback: true),
                child: Text(_autosaving ? 'Auto-saving…' : 'Save Canteen Fees'),
              ),
              const Text('Student counts auto-fill from active enrollment.', style: TextStyle(color: AppTheme.textMuted)),
              Text('Term total: ${_money(plan.totalCanteenFeesPerTerm)}', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(_draftStatusText(), style: const TextStyle(color: AppTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _schoolFeesTable(List<SchoolFeeBudgetRow> rows, List<SchoolClassesData> classes, DirectorBudgetPlan plan) {
    String classLabelForId(int? id) {
      if (id == null) return '';
      for (final schoolClass in classes) {
        if (schoolClass.id == id) return schoolClass.className;
      }
      return 'Class #$id';
    }

    return _sectionCard(
      title: 'School Fees Budget',
      subtitle: 'Per-class school fees budget for the active academic year.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _headerCell('Class', width: 180),
                    _headerCell('Total Students', width: 110),
                    _headerCell('Amount', width: 120),
                    _headerCell('Total', width: 140),
                    _headerCell('', width: 56),
                  ],
                ),
                if (rows.isEmpty)
                  Container(
                    width: 606,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(border: Border.all(color: AppTheme.border)),
                    child: const Text('No school fee rows added yet.', style: TextStyle(color: AppTheme.textMuted)),
                  )
                else
                  for (var index = 0; index < rows.length; index++)
                    Row(
                      children: [
                        SizedBox(
                          width: 180,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: DropdownButtonFormField<int?>(
                              initialValue: rows[index].classId,
                              decoration: const InputDecoration(isDense: true),
                              items: [
                                const DropdownMenuItem<int?>(value: null, child: Text('Select class')),
                                ...classes.map(
                                  (schoolClass) => DropdownMenuItem<int?>(
                                    value: schoolClass.id,
                                    child: Text(schoolClass.className),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                final updated = [...rows];
                                updated[index] = updated[index].copyWith(
                                  classId: value,
                                  clearClassId: value == null,
                                  classLabel: classLabelForId(value),
                                  studentCount: value == null ? 0 : (_classStudentCounts[value] ?? 0),
                                );
                                _setPlan(plan.copyWith(schoolFeeRows: updated));
                              },
                            ),
                          ),
                        ),
                        _valueCell('${rows[index].studentCount}', width: 110, textAlign: TextAlign.center),
                        _textCell(
                          key: ValueKey('school-amount-$index-${rows[index].amount}'),
                          width: 120,
                          initialValue: rows[index].amount == 0 ? '' : rows[index].amount.toStringAsFixed(2),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (value) {
                            final updated = [...rows];
                            updated[index] = updated[index].copyWith(amount: _parseMoney(value));
                            _setPlan(plan.copyWith(schoolFeeRows: updated));
                          },
                        ),
                        _valueCell(_money(rows[index].total), width: 140),
                        SizedBox(
                          width: 56,
                          child: IconButton(
                            onPressed: () {
                              final updated = [...rows]..removeAt(index);
                              _setPlan(plan.copyWith(schoolFeeRows: updated));
                            },
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ),
                      ],
                    ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _setPlan(plan.copyWith(schoolFeeRows: [...rows, SchoolFeeBudgetRow.empty()])),
                icon: const Icon(Icons.add),
                label: const Text('Add Class Row'),
              ),
              FilledButton.tonal(
                onPressed: _saveInProgress ? null : () => _saveDraft(successMessage: 'School fee budget saved', showFeedback: true),
                child: Text(_autosaving ? 'Auto-saving…' : 'Save School Fees'),
              ),
              const Text('Student counts auto-fill from active enrollment.', style: TextStyle(color: AppTheme.textMuted)),
              Text('Expected total: ${_money(plan.totalSchoolFees)}', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(_draftStatusText(), style: const TextStyle(color: AppTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _payrollBudgetTable(DirectorBudgetPlan plan) {
    return _sectionCard(
      title: 'Payroll Budget',
      subtitle: 'Monthly salaries, tax, SSNIT, and totals.',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _headerCell('Monthly Salaries', width: 160),
                _headerCell('Monthly Tax', width: 140),
                _headerCell('Monthly SSNIT', width: 140),
                _headerCell('Monthly Total', width: 150),
                _headerCell('Term Total', width: 150),
              ],
            ),
            Row(
              children: [
                _textCell(
                  key: ValueKey('salary-${plan.monthlySalaryBudget}'),
                  width: 160,
                  initialValue: plan.monthlySalaryBudget == 0 ? '' : plan.monthlySalaryBudget.toStringAsFixed(2),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) => _setPlan(plan.copyWith(monthlySalaryBudget: _parseMoney(value))),
                ),
                _textCell(
                  key: ValueKey('tax-${plan.monthlyTaxBudget}'),
                  width: 140,
                  initialValue: plan.monthlyTaxBudget == 0 ? '' : plan.monthlyTaxBudget.toStringAsFixed(2),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) => _setPlan(plan.copyWith(monthlyTaxBudget: _parseMoney(value))),
                ),
                _textCell(
                  key: ValueKey('ssnit-${plan.monthlySsnitBudget}'),
                  width: 140,
                  initialValue: plan.monthlySsnitBudget == 0 ? '' : plan.monthlySsnitBudget.toStringAsFixed(2),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) => _setPlan(plan.copyWith(monthlySsnitBudget: _parseMoney(value))),
                ),
                _valueCell(_money(plan.monthlyPayrollTotal), width: 150),
                _valueCell(_money(plan.payrollBudgetPerTerm), width: 150),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.tonal(
                  onPressed: _saveInProgress ? null : () => _saveDraft(successMessage: 'Payroll budget saved', showFeedback: true),
                  child: Text(_autosaving ? 'Auto-saving…' : 'Save Payroll'),
                ),
                Text(_draftStatusText(), style: const TextStyle(color: AppTheme.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final academicYear = ref.watch(activeYearProvider);
    final term = ref.watch(activeTermProvider);
    final institutionalExpensesAsync = _showExpensesContent ? ref.watch(combinedExpensesProvider) : null;
    final classes = ref.watch(classesProvider).maybeWhen(
          data: (value) => value,
          orElse: () => const <SchoolClassesData>[],
        );

    _ensureLoaded(academicYear, term);

    final plan = _currentPlan(academicYear, term);
    final analytics = _analytics ?? _rebuildAnalytics(plan);

    if (_loading && _plan == null) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_showBudgetContent) ...[
          _sectionCard(
            title: 'Director Budget Planner',
            subtitle: 'Active term budget tables for canteen fees, school fees, payroll, and saved revisions.',
            child: _budgetSnapshotRow(plan, academicYear, term),
          ),
          const SizedBox(height: 12),
          _snapshotHistorySection(_snapshots, academicYear, term),
          const SizedBox(height: 12),
          _canteenFeesTable(plan.canteenFeeRows, classes, plan),
          const SizedBox(height: 12),
          _schoolFeesTable(plan.schoolFeeRows, classes, plan),
          const SizedBox(height: 12),
          _payrollBudgetTable(plan),
          const SizedBox(height: 12),
          TextField(
            controller: _snapshotNoteController,
            minLines: 1,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Revision note',
              hintText: 'Optional note for this saved snapshot',
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonal(
                onPressed: _saving ? null : () => _save(replaceLatestSnapshot: true),
                child: Text(_saving ? 'Saving…' : 'Update Current Snapshot'),
              ),
              FilledButton(
                onPressed: _saving ? null : () => _save(replaceLatestSnapshot: false),
                child: Text(_saving ? 'Saving…' : 'Save New Revision'),
              ),
              OutlinedButton.icon(
                onPressed: (_saving || _exporting) ? null : () => _exportBudgetCsv(plan, analytics),
                icon: const Icon(Icons.table_view_outlined),
                label: Text(_exporting ? 'Exporting…' : 'Export CSV'),
              ),
              OutlinedButton.icon(
                onPressed: _saving ? null : () => _openBudgetPdfPreview(plan, analytics),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Print / Preview'),
              ),
              if (_loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ],
        if (_showExpensesContent) ...[
          _canteenExpenseBudgetTable(
            rows: plan.canteenExpenseRows,
            monthsInTerm: plan.monthsInTerm,
            onChanged: (rows) => _setPlan(plan.copyWith(canteenExpenseRows: rows)),
          ),
          const SizedBox(height: 12),
          _recordedInstitutionalExpensesSection(
            institutionalExpensesAsync!,
            academicYear: academicYear,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonal(
                onPressed: _saving ? null : () => _save(replaceLatestSnapshot: true),
                child: Text(_saving ? 'Saving…' : 'Save Expense Changes'),
              ),
              if (_loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ],
        if (_showAnalyticsContent) _analyticsSection(analytics),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(color: Colors.red),
          ),
        ],
      ],
    );
  }
}

enum _RecordedExpenseDateFilter {
  all,
  activeYear,
  currentMonth,
}

enum _BudgetEditorMode {
  budget,
  expenses,
  analytics,
}

class _ApprovalsPanel extends ConsumerWidget {
  const _ApprovalsPanel({
    this.showCreate = false,
    this.defaultCategory,
  });

  final bool showCreate;
  final String? defaultCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ApprovalsList(),
        if (showCreate) ...[
          const SizedBox(height: 10),
          _ApprovalsCreateForm(defaultCategory: defaultCategory),
        ],
      ],
    );
  }
}

class _ApprovalsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingApprovalRequestsProvider);

    String money(double v) => 'GH₵ ${NumberFormat('#,##0').format(v)}';
    String when(DateTime dt) => DateFormat('yyyy-MM-dd HH:mm').format(dt);

    return pending.when(
      data: (rows) {
        if (rows.isEmpty) {
          return const Text('No pending requests', style: TextStyle(color: AppTheme.textMuted));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Pending', style: TextStyle(color: AppTheme.textMuted))),
                Text('${rows.length}', style: const TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 10),
            for (final r in rows.take(6)) ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.request.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(
                        '${r.request.category}  •  ${r.requestedBy.fullName}  •  ${when(r.request.requestedAt)}',
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                      if (r.request.amount != null) ...[
                        const SizedBox(height: 4),
                        Text('Amount: ${money(r.request.amount!)}', style: const TextStyle(color: AppTheme.textMuted)),
                      ],
                      if ((r.request.description ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(r.request.description!.trim()),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          FilledButton.tonal(
                            onPressed: () async {
                              final user = ref.read(currentUserProvider);
                              if (user == null) return;
                              await ref.read(directorWorkflowServiceProvider).decideApprovalRequest(
                                    requestId: r.request.id,
                                    status: 'approved',
                                    decidedByUserId: user.id,
                                  );
                            },
                            child: const Text('Approve'),
                          ),
                          const SizedBox(width: 10),
                          FilledButton.tonal(
                            onPressed: () async {
                              final user = ref.read(currentUserProvider);
                              if (user == null) return;
                              await ref.read(directorWorkflowServiceProvider).decideApprovalRequest(
                                    requestId: r.request.id,
                                    status: 'rejected',
                                    decidedByUserId: user.id,
                                  );
                            },
                            child: const Text('Reject'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
      loading: () => const LinearProgressIndicator(minHeight: 6),
      error: (e, s) => Text('Could not load approvals: $e', style: const TextStyle(color: AppTheme.textMuted)),
    );
  }
}

class _ApprovalsCreateForm extends ConsumerStatefulWidget {
  const _ApprovalsCreateForm({this.defaultCategory});

  final String? defaultCategory;

  @override
  ConsumerState<_ApprovalsCreateForm> createState() => _ApprovalsCreateFormState();
}

class _ApprovalsCreateFormState extends ConsumerState<_ApprovalsCreateForm> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  bool _saving = false;
  String _category = 'general';
  String? _error;

  @override
  void initState() {
    super.initState();
    _category = widget.defaultCategory ?? 'general';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) throw Exception('Not logged in');

      final amountRaw = _amountController.text.trim();
      final amount = amountRaw.isEmpty ? null : double.tryParse(amountRaw);
      if (amountRaw.isNotEmpty && (amount == null || amount.isNaN || amount.isInfinite || amount < 0)) {
        throw const FormatException('Enter a valid amount');
      }

      await ref.read(directorWorkflowServiceProvider).createApprovalRequest(
            title: _titleController.text,
            category: _category,
            description: _descController.text,
            amount: amount,
            requestedByUserId: user.id,
          );

      _titleController.clear();
      _descController.clear();
      _amountController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request submitted'), backgroundColor: Colors.green),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('FormatException: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Create request', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Row(
              children: [
                DropdownButton<String>(
                  value: _category,
                  items: const [
                    DropdownMenuItem(value: 'general', child: Text('General')),
                    DropdownMenuItem(value: 'expense', child: Text('Expense')),
                    DropdownMenuItem(value: 'override', child: Text('Override')),
                  ],
                  onChanged: _saving
                      ? null
                      : (v) {
                          if (v == null) return;
                          setState(() {
                            _category = v;
                            _error = null;
                          });
                        },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    enabled: !_saving,
                    decoration: const InputDecoration(isDense: true, labelText: 'Title'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descController,
              enabled: !_saving,
              decoration: const InputDecoration(isDense: true, labelText: 'Description (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    enabled: !_saving,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(isDense: true, labelText: 'Amount (optional)'),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonal(
                  onPressed: _saving ? null : _create,
                  child: Text(_saving ? 'Saving…' : 'Submit'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}

class _DelegationPanel extends ConsumerStatefulWidget {
  const _DelegationPanel();

  @override
  ConsumerState<_DelegationPanel> createState() => _DelegationPanelState();
}

class _DelegationPanelState extends ConsumerState<_DelegationPanel> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  bool _saving = false;
  int? _assigneeUserId;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) throw Exception('Not logged in');
      final assignee = _assigneeUserId;
      if (assignee == null) throw const FormatException('Select an assignee');

      await ref.read(directorWorkflowServiceProvider).createDelegationTask(
            title: _titleController.text,
            description: _descController.text,
            createdByUserId: user.id,
            assignedToUserId: assignee,
          );

      _titleController.clear();
      _descController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task created'), backgroundColor: Colors.green),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('FormatException: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(openDelegationTasksProvider);
    final db = ref.watch(databaseProvider);
    final usersStream = (db.select(db.users)..orderBy([(t) => drift.OrderingTerm(expression: t.fullName)])).watch();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        tasks.when(
          data: (rows) {
            if (rows.isEmpty) {
              return const Text('No open tasks', style: TextStyle(color: AppTheme.textMuted));
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final r in rows.take(6)) ...[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.task.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Text('Assigned to: ${r.assignedTo.fullName}', style: const TextStyle(color: AppTheme.textMuted)),
                                if ((r.task.description ?? '').trim().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(r.task.description!.trim()),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.tonal(
                            onPressed: () async {
                              await ref.read(directorWorkflowServiceProvider).setDelegationTaskStatus(
                                    taskId: r.task.id,
                                    status: 'done',
                                  );
                            },
                            child: const Text('Mark done'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
          loading: () => const LinearProgressIndicator(minHeight: 6),
          error: (e, s) => Text('Could not load tasks: $e', style: const TextStyle(color: AppTheme.textMuted)),
        ),
        const SizedBox(height: 10),
        StreamBuilder<List<User>>(
          stream: usersStream,
          builder: (context, snap) {
            final users = snap.data ?? const <User>[];
            if (_assigneeUserId == null && users.isNotEmpty) {
              _assigneeUserId = users.first.id;
            }

            return DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Delegate task', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButton<int>(
                            isExpanded: true,
                            value: _assigneeUserId,
                            items: [
                              for (final u in users) DropdownMenuItem(value: u.id, child: Text(u.fullName)),
                            ],
                            onChanged: _saving
                                ? null
                                : (v) {
                                    if (v == null) return;
                                    setState(() {
                                      _assigneeUserId = v;
                                      _error = null;
                                    });
                                  },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _titleController,
                            enabled: !_saving,
                            decoration: const InputDecoration(isDense: true, labelText: 'Title'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _descController,
                      enabled: !_saving,
                      decoration: const InputDecoration(isDense: true, labelText: 'Description (optional)'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),
                    FilledButton.tonal(
                      onPressed: _saving ? null : _create,
                      child: Text(_saving ? 'Saving…' : 'Create'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AlertThresholdsPanel extends ConsumerStatefulWidget {
  const _AlertThresholdsPanel();

  @override
  ConsumerState<_AlertThresholdsPanel> createState() => _AlertThresholdsPanelState();
}

class _AlertThresholdsPanelState extends ConsumerState<_AlertThresholdsPanel> {
  final _attendanceController = TextEditingController();
  final _feesController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _attendanceController.dispose();
    _feesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final a = double.tryParse(_attendanceController.text.trim());
      final f = double.tryParse(_feesController.text.trim());
      if (a == null || f == null) throw const FormatException('Enter valid numbers');

      final svc = ref.read(directorNotificationsSettingsServiceProvider);
      await svc.setThresholds(attendanceBelowPercent: a, feesCollectionBelowPercent: f);
      ref.invalidate(directorNotificationsSettingsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thresholds saved'), backgroundColor: Colors.green),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('FormatException: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(directorNotificationsSettingsProvider);

    return settingsAsync.when(
      data: (s) {
        if (_attendanceController.text.isEmpty) {
          _attendanceController.text = s.attendanceBelowPercent.toStringAsFixed(0);
        }
        if (_feesController.text.isEmpty) {
          _feesController.text = s.feesCollectionBelowPercent.toStringAsFixed(0);
        }

        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Alert thresholds', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _attendanceController,
                        enabled: !_saving,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(isDense: true, labelText: 'Attendance below (%)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _feesController,
                        enabled: !_saving,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(isDense: true, labelText: 'Fees collection below (%)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonal(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Saving…' : 'Save'),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const LinearProgressIndicator(minHeight: 6),
      error: (e, s) => Text('Could not load settings: $e', style: const TextStyle(color: AppTheme.textMuted)),
    );
  }
}

class _SummaryEmailsPanel extends ConsumerStatefulWidget {
  const _SummaryEmailsPanel();

  @override
  ConsumerState<_SummaryEmailsPanel> createState() => _SummaryEmailsPanelState();
}

class _SummaryEmailsPanelState extends ConsumerState<_SummaryEmailsPanel> {
  final _toController = TextEditingController();
  bool _saving = false;
  String _frequency = 'weekly';
  String? _error;

  @override
  void dispose() {
    _toController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final svc = ref.read(directorNotificationsSettingsServiceProvider);
      await svc.setSummaryEmail(frequency: _frequency, to: _toController.text);
      ref.invalidate(directorNotificationsSettingsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Summary email saved'), backgroundColor: Colors.green),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('FormatException: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(directorNotificationsSettingsProvider);
    return settingsAsync.when(
      data: (s) {
        if (_toController.text.isEmpty) {
          _toController.text = s.summaryEmailTo;
        }
        _frequency = _frequency.isEmpty ? s.summaryEmailFrequency : _frequency;

        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Summary emails', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    DropdownButton<String>(
                      value: _frequency,
                      items: const [
                        DropdownMenuItem(value: 'daily', child: Text('Daily')),
                        DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                        DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) {
                              if (v == null) return;
                              setState(() {
                                _frequency = v;
                                _error = null;
                              });
                            },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _toController,
                        enabled: !_saving,
                        decoration: const InputDecoration(isDense: true, labelText: 'Recipient email(s)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonal(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Saving…' : 'Save'),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const LinearProgressIndicator(minHeight: 6),
      error: (e, s) => Text('Could not load settings: $e', style: const TextStyle(color: AppTheme.textMuted)),
    );
  }
}

class _ComplianceChecklistPanel extends ConsumerStatefulWidget {
  const _ComplianceChecklistPanel();

  @override
  ConsumerState<_ComplianceChecklistPanel> createState() => _ComplianceChecklistPanelState();
}

class _ComplianceChecklistPanelState extends ConsumerState<_ComplianceChecklistPanel> {
  final _titleController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(directorWorkflowServiceProvider).addChecklistItem(title: _titleController.text);
      _titleController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checklist item added'), backgroundColor: Colors.green),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('FormatException: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = ref.watch(directorWorkflowServiceProvider);
    final term = ref.watch(activeTermProvider);
    final year = ref.watch(activeYearProvider);
    final user = ref.watch(currentUserProvider);

    return StreamBuilder<ComplianceProgress>(
      stream: svc.watchComplianceProgress(academicYear: year, term: term),
      builder: (context, progSnap) {
        final progress = progSnap.data ?? const ComplianceProgress(totalItems: 0, completedItems: 0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Term $term • $year', style: const TextStyle(color: AppTheme.textMuted))),
                Text('${progress.completedItems}/${progress.totalItems}', style: const TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: (progress.percent / 100.0).clamp(0.0, 1.0), minHeight: 8),
            const SizedBox(height: 10),
            StreamBuilder<List<ComplianceChecklistItem>>(
              stream: svc.watchChecklistItems(activeOnly: true),
              builder: (context, itemsSnap) {
                final items = itemsSnap.data ?? const <ComplianceChecklistItem>[];
                return StreamBuilder<Set<int>>(
                  stream: svc.watchCompletedChecklistItemIds(academicYear: year, term: term),
                  builder: (context, doneSnap) {
                    final done = doneSnap.data ?? <int>{};
                    if (items.isEmpty) {
                      return const Text('No checklist items yet', style: TextStyle(color: AppTheme.textMuted));
                    }
                    return Column(
                      children: [
                        for (final i in items.take(10))
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: done.contains(i.id),
                            title: Text(i.title),
                            subtitle: Text(i.category, style: const TextStyle(color: AppTheme.textMuted)),
                            onChanged: user == null
                                ? null
                                : (v) async {
                                    await svc.setChecklistItemCompleted(
                                      checklistItemId: i.id,
                                      completed: v == true,
                                      academicYear: year,
                                      term: term,
                                      completedByUserId: user.id,
                                    );
                                  },
                          ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Add checklist item', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _titleController,
                            enabled: !_saving,
                            decoration: const InputDecoration(isDense: true, labelText: 'Title'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.tonal(
                          onPressed: _saving ? null : _addItem,
                          child: Text(_saving ? 'Saving…' : 'Add'),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CustomReportBuilderPanel extends ConsumerStatefulWidget {
  const _CustomReportBuilderPanel();

  @override
  ConsumerState<_CustomReportBuilderPanel> createState() => _CustomReportBuilderPanelState();
}

class _CustomReportBuilderPanelState extends ConsumerState<_CustomReportBuilderPanel> {
  bool _exporting = false;

  Future<void> _exportPaymentsCsv() async {
    setState(() => _exporting = true);
    try {
      final db = ref.read(databaseProvider);
      final year = ref.read(activeYearProvider);

      final fs = db.alias(db.feeStructures, 'fs');
      final st = db.alias(db.students, 'st');

      final joined = db.select(db.payments).join([
        drift.innerJoin(fs, fs.id.equalsExp(db.payments.feeStructureId)),
        drift.innerJoin(st, st.id.equalsExp(db.payments.studentId)),
      ])
        ..where(fs.academicYear.equals(year))
        ..orderBy([
          drift.OrderingTerm(expression: db.payments.paymentDate, mode: drift.OrderingMode.desc),
        ]);

      final rows = await joined.get();
      final data = <List<dynamic>>[
        const ['receipt_number', 'payment_date', 'student_name', 'fee_name', 'category', 'amount_paid', 'method', 'notes'],
      ];
      for (final r in rows) {
        final p = r.readTable(db.payments);
        final fee = r.readTable(fs);
        final student = r.readTable(st);
        data.add([
          p.receiptNumber,
          p.paymentDate.toIso8601String(),
          '${student.firstName} ${student.lastName}',
          fee.feeName,
          fee.category,
          p.amountPaid,
          p.paymentMethod,
          p.notes ?? '',
        ]);
      }

      final csv = const ListToCsvConverter().convert(data);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export payments CSV',
        fileName: 'payments_$year.csv',
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
      if (path == null) return;
      final normalized = path.endsWith('.csv') ? path : '$path.csv';
      await File(normalized).writeAsString(csv);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payments exported'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportExpensesCsv() async {
    setState(() => _exporting = true);
    try {
      final db = ref.read(databaseProvider);
      final u = db.alias(db.users, 'exp_user');
      final joined = db.select(db.expenses).join([
        drift.innerJoin(u, u.id.equalsExp(db.expenses.recordedBy)),
      ])
        ..orderBy([
          drift.OrderingTerm(expression: db.expenses.expenseDate, mode: drift.OrderingMode.desc),
        ]);

      final rows = await joined.get();
      final institutionalRows = await (db.select(db.institutionalExpenses).join([
        drift.innerJoin(u, u.id.equalsExp(db.institutionalExpenses.recordedBy)),
      ])
            ..orderBy([
              drift.OrderingTerm(expression: db.institutionalExpenses.expenseDate, mode: drift.OrderingMode.desc),
            ]))
          .get();
      final data = <List<dynamic>>[
        const ['source', 'expense_date', 'description', 'category', 'amount', 'recorded_by', 'receipt_path'],
      ];
      for (final r in rows) {
        final e = r.readTable(db.expenses);
        final user = r.readTable(u);
        data.add([
          'direct',
          e.expenseDate.toIso8601String(),
          e.description,
          e.category,
          e.amount,
          user.fullName,
          e.receiptPath ?? '',
        ]);
      }
      for (final r in institutionalRows) {
        final e = r.readTable(db.institutionalExpenses);
        final user = r.readTable(u);
        data.add([
          'institutional',
          e.expenseDate.toIso8601String(),
          e.description ?? '',
          e.category,
          e.amount,
          user.fullName,
          '',
        ]);
      }

      final csv = const ListToCsvConverter().convert(data);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export expenses CSV',
        fileName: 'expenses.csv',
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
      if (path == null) return;
      final normalized = path.endsWith('.csv') ? path : '$path.csv';
      await File(normalized).writeAsString(csv);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expenses exported'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.tonal(
          onPressed: _exporting ? null : _exportPaymentsCsv,
          child: Text(_exporting ? 'Working…' : 'Export Payments CSV'),
        ),
        FilledButton.tonal(
          onPressed: _exporting ? null : _exportExpensesCsv,
          child: Text(_exporting ? 'Working…' : 'Export Expenses CSV'),
        ),
      ],
    );
  }
}

class _StaffAppraisalsPanel extends ConsumerStatefulWidget {
  const _StaffAppraisalsPanel();

  @override
  ConsumerState<_StaffAppraisalsPanel> createState() => _StaffAppraisalsPanelState();
}

class _StaffAppraisalsPanelState extends ConsumerState<_StaffAppraisalsPanel> {
  final _scoreController = TextEditingController();
  final _notesController = TextEditingController();
  bool _saving = false;
  int? _staffId;
  String? _error;

  @override
  void dispose() {
    _scoreController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) throw Exception('Not logged in');
      final staffId = _staffId;
      if (staffId == null) throw const FormatException('Select staff');

      final year = ref.read(activeYearProvider);
      final term = ref.read(activeTermProvider);

      final scoreRaw = _scoreController.text.trim();
      final score = scoreRaw.isEmpty ? null : double.tryParse(scoreRaw);
      if (scoreRaw.isNotEmpty && score == null) throw const FormatException('Enter valid score');

      await ref.read(directorWorkflowServiceProvider).createStaffAppraisal(
            staffId: staffId,
            periodYear: year,
            periodTerm: term,
            score: score,
            notes: _notesController.text,
            createdByUserId: user.id,
          );

      _scoreController.clear();
      _notesController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appraisal created'), backgroundColor: Colors.green),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('FormatException: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appraisalsAsync = ref.watch(staffAppraisalsProvider);
    final db = ref.watch(databaseProvider);

    final staffStream = (db.select(db.staff)
          ..orderBy([(t) => drift.OrderingTerm(expression: t.lastName)])
          ..limit(200))
        .join([
      drift.innerJoin(db.users, db.users.id.equalsExp(db.staff.userId)),
    ]).watch();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        appraisalsAsync.when(
          data: (rows) {
            if (rows.isEmpty) {
              return const Text('No appraisals yet', style: TextStyle(color: AppTheme.textMuted));
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final r in rows.take(6)) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${r.user.fullName} • Term ${r.appraisal.periodTerm ?? '—'} • ${r.appraisal.periodYear}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        r.appraisal.score == null ? '—' : r.appraisal.score!.toStringAsFixed(1),
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                  if ((r.appraisal.notes ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(r.appraisal.notes!.trim()),
                  ],
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
          loading: () => const LinearProgressIndicator(minHeight: 6),
          error: (e, s) => Text('Could not load appraisals: $e', style: const TextStyle(color: AppTheme.textMuted)),
        ),
        const SizedBox(height: 10),
        StreamBuilder<List<drift.TypedResult>>(
          stream: staffStream,
          builder: (context, snapshot) {
            final rows = snapshot.data ?? const <drift.TypedResult>[];
            final items = <({int staffId, String label})>[];
            for (final r in rows) {
              final s = r.readTable(db.staff);
              final u = r.readTable(db.users);
              items.add((staffId: s.id, label: u.fullName));
            }
            if (_staffId == null && items.isNotEmpty) {
              _staffId = items.first.staffId;
            }

            return DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Create appraisal', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButton<int>(
                            isExpanded: true,
                            value: _staffId,
                            items: [
                              for (final i in items) DropdownMenuItem(value: i.staffId, child: Text(i.label)),
                            ],
                            onChanged: _saving
                                ? null
                                : (v) {
                                    if (v == null) return;
                                    setState(() {
                                      _staffId = v;
                                      _error = null;
                                    });
                                  },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _scoreController,
                            enabled: !_saving,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(isDense: true, labelText: 'Score (optional)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _notesController,
                      enabled: !_saving,
                      maxLines: 2,
                      decoration: const InputDecoration(isDense: true, labelText: 'Notes (optional)'),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.tonal(
                      onPressed: _saving ? null : _create,
                      child: Text(_saving ? 'Saving…' : 'Create'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
