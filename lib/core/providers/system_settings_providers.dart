import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/core/services/system_settings_service.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';

final systemSettingsServiceProvider = Provider<SystemSettingsService>((ref) {
  final db = ref.watch(databaseProvider);
  return SystemSettingsService(db);
});

final systemSettingsProvider = StreamProvider<SystemSetting>((ref) {
  return ref.watch(systemSettingsServiceProvider).watchSettings();
});

final activeTermProvider = Provider<int>((ref) {
  final settings = ref.watch(systemSettingsProvider).value;
  return settings?.activeTerm ?? 1;
});

final activeYearProvider = Provider<int>((ref) {
  final settings = ref.watch(systemSettingsProvider).value;
  return settings?.activeAcademicYear ?? DateTime.now().year;
});
