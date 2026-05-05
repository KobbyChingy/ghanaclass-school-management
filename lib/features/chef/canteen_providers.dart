import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghanaclass_school_management/core/providers/activity_providers.dart';
import 'package:ghanaclass_school_management/core/providers/database_provider.dart';
import 'package:ghanaclass_school_management/features/chef/canteen_service.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';

final canteenServiceProvider = Provider<CanteenService>((ref) {
  final db = ref.watch(databaseProvider);
  final activity = ref.watch(activityServiceProvider);
  return CanteenService(db, activityService: activity);
});

final canteenItemsProvider = FutureProvider.family<List<ShopItem>, String?>((ref, query) async {
  final service = ref.watch(canteenServiceProvider);
  return service.getCanteenItems(query: query);
});

final canteenMenuEntriesProvider = FutureProvider.family<List<CanteenMenuEntryView>, DateTime>((ref, date) async {
  final service = ref.watch(canteenServiceProvider);
  return service.getMenuEntriesForDate(date);
});

final canteenTodayPosItemsProvider = FutureProvider.family<List<CanteenPosItem>, String?>((ref, query) async {
  final service = ref.watch(canteenServiceProvider);
  return service.getPosItemsForDate(DateTime.now(), query: query);
});
