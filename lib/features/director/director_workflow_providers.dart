import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghanaclass_school_management/core/providers/database_provider.dart';
import 'package:ghanaclass_school_management/features/director/director_workflow_service.dart';

final directorWorkflowServiceProvider = Provider<DirectorWorkflowService>((ref) {
  final db = ref.watch(databaseProvider);
  return DirectorWorkflowService(db);
});

final pendingApprovalRequestsProvider = StreamProvider.autoDispose((ref) {
  final svc = ref.watch(directorWorkflowServiceProvider);
  return svc.watchApprovalRequests(status: 'pending', limit: 20);
});

final recentApprovalRequestsProvider = StreamProvider.autoDispose((ref) {
  final svc = ref.watch(directorWorkflowServiceProvider);
  return svc.watchApprovalRequests(limit: 20);
});

final openDelegationTasksProvider = StreamProvider.autoDispose((ref) {
  final svc = ref.watch(directorWorkflowServiceProvider);
  return svc.watchDelegationTasks(status: 'open', limit: 50);
});

final recentDelegationTasksProvider = StreamProvider.autoDispose((ref) {
  final svc = ref.watch(directorWorkflowServiceProvider);
  return svc.watchDelegationTasks(limit: 50);
});

final staffAppraisalsProvider = StreamProvider.autoDispose((ref) {
  final svc = ref.watch(directorWorkflowServiceProvider);
  return svc.watchStaffAppraisals(limit: 50);
});
