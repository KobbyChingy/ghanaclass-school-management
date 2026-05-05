import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghanaclass_school_management/core/providers/database_provider.dart';
import 'package:ghanaclass_school_management/features/director/director_notifications_settings_service.dart';

final directorNotificationsSettingsServiceProvider = Provider<DirectorNotificationsSettingsService>((ref) {
  final db = ref.watch(databaseProvider);
  return DirectorNotificationsSettingsService(db);
});

final directorNotificationsSettingsProvider = FutureProvider.autoDispose<DirectorNotificationsSettings>((ref) async {
  final svc = ref.watch(directorNotificationsSettingsServiceProvider);
  return svc.getSettings();
});
