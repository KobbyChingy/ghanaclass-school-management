import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/features/staff/staff_providers.dart';
import 'package:ghanaclass_school_management/features/staff/staff_repair_service.dart';

class StaffRepairScreen extends ConsumerStatefulWidget {
  const StaffRepairScreen({super.key});

  @override
  ConsumerState<StaffRepairScreen> createState() => _StaffRepairScreenState();
}

class _StaffRepairScreenState extends ConsumerState<StaffRepairScreen> {
  bool _loading = false;
  StaffRepairSnapshot? _snapshot;
  StaffRepairReport? _lastReport;
  bool _syncUsersFromStaff = false;

  @override
  void initState() {
    super.initState();
    // Fire-and-forget initial scan.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Data Repair'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: currentUser?.role != UserRole.admin.name
                ? _accessDenied()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(),
                      const SizedBox(height: 16),
                      _statusCard(),
                      const SizedBox(height: 16),
                      _actionsCard(),
                      if (_lastReport != null) ...[
                        const SizedBox(height: 16),
                        _reportCard(_lastReport!),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.actionIndigo.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.wrench, color: AppTheme.actionIndigo),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Repair broken staff records', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text(
                    'Fixes legacy DB issues like missing user links and NULLs in non-null fields. Safe to run multiple times.',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard() {
    final snapshot = _snapshot;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Current Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_loading && snapshot == null)
              const LinearProgressIndicator()
            else if (snapshot == null)
              const Text('No scan data yet. Click “Scan Now”.', style: TextStyle(color: AppTheme.textMuted))
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _metric('Total staff', snapshot.totalStaff.toString(), icon: LucideIcons.users),
                  _metric('Backfill needed', snapshot.rowsNeedingDefaultBackfill.toString(), icon: LucideIcons.clipboardList),
                  _metric('Missing user link', snapshot.rowsMissingUserId.toString(), icon: LucideIcons.link2Off),
                  _metric('Orphaned user IDs', snapshot.orphanUserIds.toString(), icon: LucideIcons.alertTriangle),
                  _metric('User name mismatch', snapshot.linkedUsersNeedingNameSync.toString(), icon: LucideIcons.user),
                  _metric('User phone mismatch', snapshot.linkedUsersNeedingPhoneSync.toString(), icon: LucideIcons.phone),
                  _metric('User active mismatch', snapshot.linkedUsersNeedingActiveSync.toString(), icon: LucideIcons.toggleLeft),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _actionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Also sync linked user profiles'),
              subtitle: const Text(
                'Updates users.fullName / phone / active from staff records (recommended before staff import/export).',
                style: TextStyle(color: AppTheme.textMuted),
              ),
              value: _syncUsersFromStaff,
              onChanged: _loading
                  ? null
                  : (v) {
                      setState(() => _syncUsersFromStaff = v);
                    },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _scan,
                    icon: _loading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(LucideIcons.refreshCw, size: 18),
                    label: const Text('Scan Now'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _confirmAndRepair,
                    icon: const Icon(LucideIcons.wrench, size: 18),
                    label: const Text('Run Repair'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.actionIndigo,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportCard(StaffRepairReport report) {
    final before = report.before;
    final after = report.after;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Last Repair Run', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Duration: ${report.duration.inSeconds}s', style: const TextStyle(color: AppTheme.textMuted)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _metric('Backfill needed', '${before.rowsNeedingDefaultBackfill} → ${after.rowsNeedingDefaultBackfill}', icon: LucideIcons.clipboardList),
                _metric('Missing user link', '${before.rowsMissingUserId} → ${after.rowsMissingUserId}', icon: LucideIcons.link2Off),
                _metric('Orphaned user IDs', '${before.orphanUserIds} → ${after.orphanUserIds}', icon: LucideIcons.alertTriangle),
                _metric('User name mismatch', '${before.linkedUsersNeedingNameSync} → ${after.linkedUsersNeedingNameSync}', icon: LucideIcons.user),
                _metric('User phone mismatch', '${before.linkedUsersNeedingPhoneSync} → ${after.linkedUsersNeedingPhoneSync}', icon: LucideIcons.phone),
                _metric('User active mismatch', '${before.linkedUsersNeedingActiveSync} → ${after.linkedUsersNeedingActiveSync}', icon: LucideIcons.toggleLeft),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value, {required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppTheme.textMuted),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _accessDenied() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.shieldAlert, size: 48, color: Colors.redAccent.withValues(alpha: 0.9)),
            const SizedBox(height: 12),
            const Text('Admin only', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('You do not have permission to run repair tools.', style: TextStyle(color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }

  Future<void> _scan() async {
    setState(() => _loading = true);
    try {
      final db = ref.read(databaseProvider);
      final service = StaffRepairService(db);
      final snap = await service.snapshot();
      if (!mounted) return;
      setState(() {
        _snapshot = snap;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmAndRepair() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Run Staff Repair?'),
        content: const Text(
          'This will modify local staff/user records to fix legacy issues (missing links, NULL fields).\n\n'
          'Recommended: Export a database backup first.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.actionIndigo),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Run Repair'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _repair();
  }

  Future<void> _repair() async {
    setState(() => _loading = true);
    try {
      final db = ref.read(databaseProvider);
      final service = StaffRepairService(db);
      final report = await service.repairAndReport(syncUsersFromStaff: _syncUsersFromStaff);

      // Refresh staff directory list.
      ref.invalidate(staffListProvider);

      if (!mounted) return;
      setState(() {
        _lastReport = report;
        _snapshot = report.after;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff repair completed.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Repair failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
