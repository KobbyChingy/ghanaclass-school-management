import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghanaclass_school_management/core/providers/database_provider.dart';
import 'package:ghanaclass_school_management/features/alarms/alarm_scheduler.dart';
import 'package:ghanaclass_school_management/features/alarms/alarm_service.dart';

final alarmServiceProvider = Provider<AlarmService>((ref) {
  final db = ref.watch(databaseProvider);
  return AlarmService(db);
});

final alarmsStreamProvider = StreamProvider((ref) {
  return ref.watch(alarmServiceProvider).watchAlarms();
});

/// Keeps an in-app scheduler alive (fires alarms while app is running).
final alarmSchedulerProvider = Provider<AlarmScheduler>((ref) {
  final scheduler = AlarmScheduler(service: ref.watch(alarmServiceProvider));
  scheduler.start();
  ref.onDispose(() => scheduler.dispose());
  return scheduler;
});
