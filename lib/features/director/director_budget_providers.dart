import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/features/director/director_budget_service.dart';

final directorBudgetServiceProvider = Provider<DirectorBudgetService>((ref) {
  final db = ref.watch(databaseProvider);
  return DirectorBudgetService(db);
});
