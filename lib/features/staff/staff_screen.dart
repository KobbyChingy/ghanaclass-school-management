import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/features/staff/staff_import_dialog.dart';
import 'package:ghanaclass_school_management/features/staff/staff_import_service.dart';
import 'package:open_file/open_file.dart';

import 'package:ghanaclass_school_management/features/staff/staff_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';

class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({super.key});

  @override
  ConsumerState<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends ConsumerState<StaffScreen> {
  final _search = TextEditingController();
  String _query = '';
  String _selectedPosition = 'All';
  bool _selectionMode = false;
  final Set<int> _selectedStaffTableIds = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(staffListProvider);
    final currentUser = ref.watch(currentUserProvider);
    final isAdmin = currentUser?.role == UserRole.admin.name;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Directory'),
        actions: [
          if (_selectionMode) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('${_selectedStaffTableIds.length} selected', style: const TextStyle(color: AppTheme.textMuted)),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _selectionMode = false;
                _selectedStaffTableIds.clear();
              }),
              icon: const Icon(LucideIcons.x, size: 18),
              label: const Text('Cancel'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: isAdmin ? () => _selectAllFiltered() : null,
              icon: const Icon(LucideIcons.checkCheck, size: 18),
              label: const Text('Select All'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: (isAdmin && _selectedStaffTableIds.isNotEmpty) ? () => _confirmBulkDeactivate() : null,
              icon: const Icon(LucideIcons.shield, size: 18),
              label: const Text('Deactivate'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: (isAdmin && _selectedStaffTableIds.isNotEmpty) ? () => _confirmBulkDelete() : null,
              icon: const Icon(LucideIcons.trash2, size: 18),
              label: const Text('Delete'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            ),
            const SizedBox(width: 24),
          ] else ...[
            if (isAdmin) ...[
              OutlinedButton.icon(
                onPressed: () => setState(() => _selectionMode = true),
                icon: const Icon(LucideIcons.checkSquare, size: 18),
                label: const Text('Bulk Actions'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(width: 12),
            ],

            if (isAdmin) ...[
            OutlinedButton.icon(
              onPressed: () => context.push('/staff/repair'),
              icon: const Icon(LucideIcons.wrench, size: 18),
              label: const Text('Repair Data'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            const SizedBox(width: 12),
            ],
          OutlinedButton.icon(
            onPressed: () async {
              final path = await StaffImportExportService().exportTemplateToExcel();
              if (path != null) {
                await OpenFile.open(path);
              }
            },
            icon: const Icon(LucideIcons.download, size: 18),
            label: const Text('Export Template'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const StaffImportDialog(),
              );
            },
            icon: const Icon(LucideIcons.upload, size: 18),
            label: const Text('Import'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => context.push('/staff/admission'),
            icon: const Icon(LucideIcons.userPlus, size: 18),
            label: const Text('Add Staff'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.actionIndigo,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 24),
          ],
        ],
      ),
      body: staffAsync.when(
        data: (staff) {
          if (staff.isEmpty) return _buildEmptyState(context);

          final positions = <String>{
            for (final s in staff)
              if (s.position.trim().isNotEmpty) s.position.trim(),
          }.toList(growable: false)
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

          final q = _query.trim().toLowerCase();
          final filtered = staff.where((s) {
            if (_selectedPosition != 'All' && s.position.trim() != _selectedPosition) return false;
            if (q.isEmpty) return true;
            final name = '${s.firstName} ${s.lastName}'.toLowerCase();
            final staffId = s.staffId.toLowerCase();
            final phone = s.phoneNumber.toLowerCase();
            return name.contains(q) || staffId.contains(q) || phone.contains(q);
          }).toList(growable: false);

          return Column(
            children: [
              _buildFilterBar(context, staffCount: staff.length, positions: positions),
              const Divider(height: 1),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No staff found for the selected filter.'))
                    : _buildStaffGrid(context, filtered),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, {required int staffCount, required List<String> positions}) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(LucideIcons.search),
                hintText: 'Search staff (name, staff ID, phone...)',
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<String>(
              key: ValueKey(_selectedPosition),
              isExpanded: true,
              initialValue: _selectedPosition,
              decoration: const InputDecoration(
                labelText: 'Role/Position',
                prefixIcon: Icon(LucideIcons.badgeCheck),
              ),
              selectedItemBuilder: (context) {
                final values = <String>['All', ...positions];
                return values
                    .map(
                      (v) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          v,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false);
              },
              items: [
                const DropdownMenuItem(
                  value: 'All',
                  child: Text('All', maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                ...positions.map(
                  (p) => DropdownMenuItem(
                    value: p,
                    child: Text(p, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _selectedPosition = v);
              },
            ),
          ),
          const SizedBox(width: 12),
          Text('$staffCount staff', style: const TextStyle(color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.users, size: 64, color: AppTheme.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'No staff members found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffGrid(BuildContext context, List<StaffData> staff) {
    // Keep latest filtered list for Select All.
    _lastFiltered = staff;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 350,
          mainAxisExtent: 140,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: staff.length,
        itemBuilder: (context, index) {
          final s = staff[index];
          final isSelected = _selectedStaffTableIds.contains(s.id);
          return Card(
            child: ListTile(
              onTap: () {
                if (_selectionMode) {
                  setState(() {
                    if (isSelected) {
                      _selectedStaffTableIds.remove(s.id);
                    } else {
                      _selectedStaffTableIds.add(s.id);
                    }
                  });
                  return;
                }
                context.push('/staff/${s.id}');
              },
              onLongPress: () {
                if (!_selectionMode) {
                  setState(() {
                    _selectionMode = true;
                    _selectedStaffTableIds.add(s.id);
                  });
                }
              },
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.actionIndigo.withValues(alpha: 0.1),
                child: Text(
                  _initialsFor(s.firstName, s.lastName),
                  style: TextStyle(color: AppTheme.actionIndigo, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text('${s.firstName} ${s.lastName}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.position, style: TextStyle(color: AppTheme.actionIndigo, fontSize: 13)),
                  Text(s.phoneNumber, style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                ],
              ),
              trailing: _selectionMode
                  ? Checkbox(
                      value: isSelected,
                      onChanged: (_) {
                        setState(() {
                          if (isSelected) {
                            _selectedStaffTableIds.remove(s.id);
                          } else {
                            _selectedStaffTableIds.add(s.id);
                          }
                        });
                      },
                    )
                  : const Icon(LucideIcons.moreHorizontal, size: 20),
            ),
          );
        },
      ),
    );
  }

  List<StaffData> _lastFiltered = const [];

  void _selectAllFiltered() {
    setState(() {
      for (final s in _lastFiltered) {
        _selectedStaffTableIds.add(s.id);
      }
    });
  }

  Future<void> _confirmBulkDeactivate() async {
    final count = _selectedStaffTableIds.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate staff'),
        content: Text('Deactivate $count staff accounts? This will also disable their portal login.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final staffService = ref.read(staffServiceProvider);
    final result = await staffService.bulkDeactivateStaff(_selectedStaffTableIds.toList(), deactivateUsers: true);
    ref.invalidate(staffListProvider);

    if (!mounted) return;
    setState(() {
      _selectionMode = false;
      _selectedStaffTableIds.clear();
    });

    final msg = 'Deactivated ${result.affected}/${result.requested} staff.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  Future<void> _confirmBulkDelete() async {
    final count = _selectedStaffTableIds.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete staff profiles'),
        content: Text(
          'Delete $count staff profiles?\n\n'
          'This removes the staff profile record. If the staff has attendance records, deletion will be skipped for that staff.\n'
          'Portal login will be disabled for deleted staff.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final staffService = ref.read(staffServiceProvider);
    final result = await staffService.bulkDeleteStaff(_selectedStaffTableIds.toList(), deactivateUsers: true);
    ref.invalidate(staffListProvider);

    if (!mounted) return;
    setState(() {
      _selectionMode = false;
      _selectedStaffTableIds.clear();
    });

    final msg = result.skippedStaffTableIds.isEmpty
        ? 'Deleted ${result.affected}/${result.requested} staff.'
        : 'Deleted ${result.affected}/${result.requested} staff. Skipped: ${result.skippedStaffTableIds.length}.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: result.skippedStaffTableIds.isEmpty ? Colors.green : Colors.orange),
    );
  }

  String _initialsFor(String firstName, String lastName) {
    final first = firstName.trim();
    final last = lastName.trim();
    final a = first.isNotEmpty ? first.characters.first.toUpperCase() : '?';
    final b = last.isNotEmpty ? last.characters.first.toUpperCase() : '?';
    return '$a$b';
  }
}
