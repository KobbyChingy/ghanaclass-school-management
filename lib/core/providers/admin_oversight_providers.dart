import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/core/services/admin_oversight_service.dart';
import 'package:ghanaclass_school_management/core/providers/system_settings_providers.dart';

final adminOversightServiceProvider = Provider<AdminOversightService>((ref) {
  final db = ref.watch(databaseProvider);
  return AdminOversightService(db);
});

final adminKpisProvider = FutureProvider<AdminKpis>((ref) async {
  final term = ref.watch(activeTermProvider);
  final year = ref.watch(activeYearProvider);
  return await ref.watch(adminOversightServiceProvider).getGlobalKpis(term, year);
});
