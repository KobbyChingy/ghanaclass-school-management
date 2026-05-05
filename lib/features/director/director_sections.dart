enum DirectorFeatureKind {
  budget,
  dashboard,
  financeAnalytics,
  attendanceOverview,
  customWidgets,

  feesLedger,
  expenses,
  payroll,
  approvalsLargeExpenses,

  students,
  admissions,
  retention,
  demographics,

  teacherReports,
  classes,
  subjects,
  studentProfiles,

  staff,
  staffAttendance,
  staffAppraisals,

  reportsFinance,
  complianceChecklists,
  customReportBuilder,
  export,

  resourceUtilizationLabs,
  auditLogs,
  dataAccess,

  broadcast,
  communicationLogs,
  emergencyAlerts,

  approveRequests,
  overrides,
  taskDelegation,

  realTimeAlerts,
  alertThresholds,
  summaryEmails,

  auditCompliance,
  roleManagement,
  settings,
  offlineSync,
}

class DirectorFeature {
  final DirectorFeatureKind kind;
  final String title;
  final String? description;
  final String? route;

  const DirectorFeature({
    required this.kind,
    required this.title,
    this.description,
    this.route,
  });
}

class DirectorSection {
  final String id;
  final String title;
  final String description;
  final String integrationPoints;
  final List<DirectorFeature> features;

  const DirectorSection({
    required this.id,
    required this.title,
    required this.description,
    required this.integrationPoints,
    required this.features,
  });
}

const directorExecutiveDashboardSection = DirectorSection(
  id: 'executive-dashboard',
  title: 'Executive Dashboard',
  description: '',
  integrationPoints: '',
  features: [
    DirectorFeature(
      kind: DirectorFeatureKind.dashboard,
      title: 'Executive Dashboard',
    ),
    DirectorFeature(
      kind: DirectorFeatureKind.attendanceOverview,
      title: 'Attendance Overview',
    ),
  ],
);

const directorBudgetSection = DirectorSection(
  id: 'budget',
  title: 'Budget',
  description: '',
  integrationPoints: '',
  features: [
    DirectorFeature(
      kind: DirectorFeatureKind.budget,
      title: 'Budget Planner',
    ),
  ],
);

const directorExpensesSection = DirectorSection(
  id: 'expenses',
  title: 'Expenses',
  description: '',
  integrationPoints: '',
  features: [
    DirectorFeature(
      kind: DirectorFeatureKind.expenses,
      title: 'Expenses',
    ),
    DirectorFeature(
      kind: DirectorFeatureKind.approvalsLargeExpenses,
      title: 'Large Expense Approvals',
    ),
  ],
);

const directorAnalyticsSection = DirectorSection(
  id: 'analytics',
  title: 'Analytics',
  description: '',
  integrationPoints: '',
  features: [
    DirectorFeature(
      kind: DirectorFeatureKind.reportsFinance,
      title: 'Financial Reports',
    ),
    DirectorFeature(
      kind: DirectorFeatureKind.export,
      title: 'Exports',
    ),
    DirectorFeature(
      kind: DirectorFeatureKind.financeAnalytics,
      title: 'Trend Analytics',
    ),
  ],
);

const directorResourceUtilizationSection = DirectorSection(
  id: 'resource-utilization',
  title: 'Resource Utilization',
  description: '',
  integrationPoints: '',
  features: [
    DirectorFeature(
      kind: DirectorFeatureKind.resourceUtilizationLabs,
      title: 'Resource Utilization',
    ),
  ],
);

const directorAuditLogsSection = DirectorSection(
  id: 'audit-logs',
  title: 'Audit Logs',
  description: '',
  integrationPoints: '',
  features: [
    DirectorFeature(
      kind: DirectorFeatureKind.auditLogs,
      title: 'Audit Logs',
    ),
  ],
);

const directorDataAccessSection = DirectorSection(
  id: 'data-access-roles',
  title: 'Data Access Roles',
  description: '',
  integrationPoints: '',
  features: [
    DirectorFeature(
      kind: DirectorFeatureKind.dataAccess,
      title: 'Data Access',
    ),
    DirectorFeature(
      kind: DirectorFeatureKind.roleManagement,
      title: 'Role Management',
    ),
  ],
);

const directorSections = <DirectorSection>[
  directorExecutiveDashboardSection,
  directorBudgetSection,
  directorExpensesSection,
  directorAnalyticsSection,
  directorResourceUtilizationSection,
  directorAuditLogsSection,
  directorDataAccessSection,
];

DirectorSection? directorSectionById(String id) {
  for (final section in directorSections) {
    if (section.id == id) return section;
  }
  return null;
}
