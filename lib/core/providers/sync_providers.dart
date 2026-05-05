import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghanaclass_school_management/core/services/connectivity_service.dart';
import 'package:ghanaclass_school_management/core/providers/database_provider.dart';
import 'package:ghanaclass_school_management/core/services/sync_service.dart';
import 'package:ghanaclass_school_management/core/config/app_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Connectivity service provider
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(() => service.dispose());
  return service;
});

// Online status stream provider
final onlineStatusProvider = StreamProvider<bool>((ref) {
  final connectivityService = ref.watch(connectivityServiceProvider);
  return connectivityService.statusStream;
});

// Current online status provider
final isOnlineProvider = Provider<bool>((ref) {
  final connectivityService = ref.watch(connectivityServiceProvider);
  return connectivityService.isOnline;
});

/// Whether Server Mode (remote backend) is enabled.
///
/// When enabled, internet connectivity is required for login and sync.
final serverEnabledProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return AppMode.resolveServerEnabled(prefs.getBool('server_enabled'));
});

/// Sync service provider (Server Mode outbox + pull/push)
final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(databaseProvider);
  return SyncService(db);
});

