import 'package:ghanaclass_school_management/core/constants/user_roles.dart';

/// Default dashboard widget order/visibility per role
const Map<UserRole, List<String>> roleBasedWidgetOrder = {
  UserRole.admin: [
    'ResourceUtilizationCard',
    'AuditLogsAnalyticsCard',
    'DataAccessAnalyticsCard',
  ],
  UserRole.accountant: [
    'ResourceUtilizationCard',
    'DataAccessAnalyticsCard',
  ],
  UserRole.teacher: [
    'ResourceUtilizationCard',
  ],
  UserRole.library: [
    'BookBorrowingTrendsCard',
  ],
  UserRole.ictlab: [
    'ResourceUtilizationCard',
  ],
  UserRole.sciencelab: [
    'ResourceUtilizationCard',
  ],
  UserRole.parent: [
    'AuditLogsAnalyticsCard',
  ],
  // Add more as needed
};
