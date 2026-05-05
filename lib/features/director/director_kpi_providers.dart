import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/core/providers/system_settings_providers.dart';
import 'package:ghanaclass_school_management/features/director/director_kpi_service.dart';

final directorKpiServiceProvider = Provider<DirectorKpiService>((ref) {
  final db = ref.watch(databaseProvider);
  return DirectorKpiService(db);
});

final directorKpisProvider = FutureProvider<DirectorKpis>((ref) async {
  final term = ref.watch(activeTermProvider);
  final year = ref.watch(activeYearProvider);
  return ref.watch(directorKpiServiceProvider).getKpis(activeTerm: term, activeYear: year);
});
