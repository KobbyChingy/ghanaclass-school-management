import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path/path.dart' as p;

import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/features/alarms/alarm_providers.dart';
import 'package:ghanaclass_school_management/features/alarms/alarm_repeat.dart';

class AlarmsScreen extends ConsumerWidget {
  const AlarmsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alarmsAsync = ref.watch(alarmsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarm / Siren'),
        actions: [
          IconButton(
            tooltip: 'New alarm',
            icon: const Icon(LucideIcons.plus),
            onPressed: () async {
              await showDialog<void>(
                context: context,
                builder: (_) => const _AlarmEditorDialog(),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: alarmsAsync.when(
        data: (alarms) {
          if (alarms.isEmpty) {
            return _EmptyState(
              onCreate: () async {
                await showDialog<void>(
                  context: context,
                  builder: (_) => const _AlarmEditorDialog(),
                );
              },
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: alarms.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final alarm = alarms[index];
              return _AlarmCard(alarm: alarm);
            },
          );
        },
        error: (e, _) => Center(child: Text('Error: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          elevation: 0,
          color: AppTheme.surfaceMuted,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.clock4, size: 44, color: AppTheme.textMuted),
                const SizedBox(height: 10),
                Text('No alarms yet', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  'Create alarms like “Break Time”, pick an audio file, choose the time, and optionally repeat on selected days.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(LucideIcons.plus),
                  label: const Text('Create Alarm'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AlarmCard extends ConsumerWidget {
  const _AlarmCard({required this.alarm});

  final Alarm alarm;

  String _timeLabel() {
    final hh = alarm.hour.toString().padLeft(2, '0');
    final mm = alarm.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(alarmServiceProvider);
    final scheduler = ref.watch(alarmSchedulerProvider);

    final repeat = AlarmRepeat.summary(alarm.repeatDaysMask);

    final soundFileName = p.basename(alarm.soundPath);
    final soundExists = File(alarm.soundPath).existsSync();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.actionIndigo.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.clock, size: 16, color: AppTheme.actionIndigo),
                      const SizedBox(width: 6),
                      Text(
                        _timeLabel(),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alarm.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                        alarm.description?.trim().isNotEmpty == true ? alarm.description!.trim() : repeat,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: alarm.isEnabled,
                  onChanged: (v) => service.setEnabled(alarm.id, v),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(soundExists ? LucideIcons.music : LucideIcons.alertTriangle, size: 18, color: soundExists ? AppTheme.textMuted : AppTheme.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          soundExists ? soundFileName : 'Missing audio file ($soundFileName)',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: soundExists ? () => scheduler.testPlay(alarm.soundPath) : null,
                  icon: const Icon(LucideIcons.play, size: 16),
                  label: const Text('Test'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(LucideIcons.pencil),
                  onPressed: () async {
                    await showDialog<void>(
                      context: context,
                      builder: (_) => _AlarmEditorDialog(existing: alarm),
                    );
                  },
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(LucideIcons.trash2),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Delete alarm?'),
                        content: Text('Delete “${alarm.title}”?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );

                    if (ok == true) {
                      await service.deleteAlarm(alarm.id);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Pill(label: repeat, icon: LucideIcons.repeat),
                if (!alarm.isEnabled) const _Pill(label: 'Disabled', icon: LucideIcons.ban),
                if (alarm.lastFiredAt != null)
                  _Pill(
                    label: 'Last fired: ${alarm.lastFiredAt!.toLocal().toString().substring(0, 16)}',
                    icon: LucideIcons.history,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textMuted),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}

class _AlarmEditorDialog extends ConsumerStatefulWidget {
  const _AlarmEditorDialog({this.existing});

  final Alarm? existing;

  @override
  ConsumerState<_AlarmEditorDialog> createState() => _AlarmEditorDialogState();
}

class _AlarmEditorDialogState extends ConsumerState<_AlarmEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _description;

  int _hour = 9;
  int _minute = 0;
  int _repeatMask = AlarmRepeat.weekdays;

  String? _soundPath;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;

    _title = TextEditingController(text: existing?.title ?? '');
    _description = TextEditingController(text: existing?.description ?? '');

    _hour = existing?.hour ?? 9;
    _minute = existing?.minute ?? 0;
    _repeatMask = existing?.repeatDaysMask ?? AlarmRepeat.weekdays;
    _soundPath = existing?.soundPath;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  String _timeLabel() {
    final hh = _hour.toString().padLeft(2, '0');
    final mm = _minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Future<void> _pickTime(BuildContext context) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
    );
    if (time == null) return;
    setState(() {
      _hour = time.hour;
      _minute = time.minute;
    });
  }

  void _toggleDay(int bit) {
    setState(() {
      if ((_repeatMask & bit) != 0) {
        _repeatMask &= ~bit;
      } else {
        _repeatMask |= bit;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(alarmServiceProvider);

    final isEditing = widget.existing != null;
    final repeatSummary = AlarmRepeat.summary(_repeatMask);

    return AlertDialog(
      title: Text(isEditing ? 'Edit Alarm' : 'New Alarm'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g. Break Time',
                    prefixIcon: Icon(LucideIcons.type),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Title is required';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Shown under title',
                    prefixIcon: Icon(LucideIcons.text),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                          color: AppTheme.surfaceMuted,
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.clock, size: 18, color: AppTheme.textMuted),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _timeLabel(),
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () => _pickTime(context),
                              child: const Text('Set time'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Repeat', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _RepeatChip(
                      label: 'Mon',
                      selected: (_repeatMask & AlarmRepeat.monday) != 0,
                      onTap: () => _toggleDay(AlarmRepeat.monday),
                    ),
                    _RepeatChip(
                      label: 'Tue',
                      selected: (_repeatMask & AlarmRepeat.tuesday) != 0,
                      onTap: () => _toggleDay(AlarmRepeat.tuesday),
                    ),
                    _RepeatChip(
                      label: 'Wed',
                      selected: (_repeatMask & AlarmRepeat.wednesday) != 0,
                      onTap: () => _toggleDay(AlarmRepeat.wednesday),
                    ),
                    _RepeatChip(
                      label: 'Thu',
                      selected: (_repeatMask & AlarmRepeat.thursday) != 0,
                      onTap: () => _toggleDay(AlarmRepeat.thursday),
                    ),
                    _RepeatChip(
                      label: 'Fri',
                      selected: (_repeatMask & AlarmRepeat.friday) != 0,
                      onTap: () => _toggleDay(AlarmRepeat.friday),
                    ),
                    _RepeatChip(
                      label: 'Sat',
                      selected: (_repeatMask & AlarmRepeat.saturday) != 0,
                      onTap: () => _toggleDay(AlarmRepeat.saturday),
                    ),
                    _RepeatChip(
                      label: 'Sun',
                      selected: (_repeatMask & AlarmRepeat.sunday) != 0,
                      onTap: () => _toggleDay(AlarmRepeat.sunday),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: () => setState(() => _repeatMask = AlarmRepeat.everyday),
                      icon: const Icon(LucideIcons.repeat2, size: 16),
                      label: const Text('Every day'),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() => _repeatMask = AlarmRepeat.weekdays),
                      icon: const Icon(LucideIcons.calendarDays, size: 16),
                      label: const Text('Weekdays'),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() => _repeatMask = 0),
                      icon: const Icon(LucideIcons.zap, size: 16),
                      label: const Text('One-time'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Current: $repeatSummary',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                    color: AppTheme.surfaceMuted,
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.music, size: 18, color: AppTheme.textMuted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _soundPath == null ? 'No sound selected' : p.basename(_soundPath!),
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await service.pickAndSaveAudioFile();
                          if (picked == null) return;
                          setState(() => _soundPath = picked);
                        },
                        icon: const Icon(LucideIcons.upload, size: 16),
                        label: Text(_soundPath == null ? 'Upload sound' : 'Change'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            if (_soundPath == null || _soundPath!.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload/select a sound file')));
              return;
            }

            if (widget.existing == null) {
              await service.createAlarm(
                title: _title.text,
                description: _description.text,
                soundPath: _soundPath!,
                hour: _hour,
                minute: _minute,
                repeatDaysMask: _repeatMask,
              );
            } else {
              await service.updateAlarm(
                widget.existing!,
                title: _title.text,
                description: _description.text,
                soundPath: _soundPath,
                hour: _hour,
                minute: _minute,
                repeatDaysMask: _repeatMask,
              );
            }

            if (context.mounted) Navigator.pop(context);
          },
          child: Text(isEditing ? 'Save changes' : 'Create alarm'),
        ),
      ],
    );
  }
}

class _RepeatChip extends StatelessWidget {
  const _RepeatChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppTheme.actionIndigo : AppTheme.border),
          color: selected ? AppTheme.actionIndigo.withValues(alpha: 0.12) : AppTheme.surface,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: selected ? AppTheme.actionIndigo : AppTheme.textMuted,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
        ),
      ),
    );
  }
}
