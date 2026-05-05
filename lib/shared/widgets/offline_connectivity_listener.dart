import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghanaclass_school_management/core/config/app_mode.dart';
import 'package:ghanaclass_school_management/core/providers/sync_providers.dart';

class OfflineConnectivityListener extends ConsumerStatefulWidget {
  const OfflineConnectivityListener({
    super.key,
    this.serverModeOnly = true,
    this.showBackOnline = true,
  });

  /// If true, only shows alerts when Server Mode is enabled.
  final bool serverModeOnly;

  /// If true, shows a "Back online" message when connectivity returns.
  final bool showBackOnline;

  @override
  ConsumerState<OfflineConnectivityListener> createState() => _OfflineConnectivityListenerState();
}

class _OfflineConnectivityListenerState extends ConsumerState<OfflineConnectivityListener> {
  bool? _lastIsOnline;

  @override
  Widget build(BuildContext context) {
    if (AppMode.forceServerModeOff && !AppMode.forceServerModeOn) {
      return const SizedBox.shrink();
    }

    final serverEnabledAsync = ref.watch(serverEnabledProvider);
    final shouldAlert = widget.serverModeOnly
        ? serverEnabledAsync.maybeWhen(data: (v) => v, orElse: () => false)
        : true;

    ref.listen<AsyncValue<bool>>(onlineStatusProvider, (previous, next) {
      final isOnline = next.asData?.value;
      if (isOnline == null) return;

      final last = _lastIsOnline;
      _lastIsOnline = isOnline;

      // Avoid spamming on first value.
      if (last == null) return;
      if (last == isOnline) return;
      if (!shouldAlert) return;
      if (!mounted) return;

      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;

      if (!isOnline) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('You are offline. Please connect to an internet source.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      } else if (widget.showBackOnline) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Back online.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        // Trigger a best-effort data sync when coming back online.
        // The Supabase SDK automatically reconnects its realtime channel.
        ref.read(syncServiceProvider).syncOnce();
      }
    });

    return const SizedBox.shrink();
  }
}
