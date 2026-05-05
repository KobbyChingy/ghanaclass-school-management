import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/providers/sync_providers.dart';

class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onlineStatusAsync = ref.watch(onlineStatusProvider);

    return onlineStatusAsync.when(
      data: (isOnline) => _buildStatusWidget(context, ref, isOnline),
      loading: () => _buildStatusWidget(context, ref, false),
      error: (err, _) => _buildStatusWidget(context, ref, false),
    );
  }

  Widget _buildStatusWidget(BuildContext context, WidgetRef ref, bool isOnline) {
    final icon = isOnline ? LucideIcons.wifi : LucideIcons.wifiOff;
    final color = isOnline ? AppTheme.success : AppTheme.textMuted;
    final label = isOnline ? 'Online' : 'Offline';

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: isOnline
          ? () {
              // Best-effort; does nothing unless Server Mode is enabled.
              ref.read(syncServiceProvider).syncOnce();
            }
          : null,
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
      ),
    );
  }
}
