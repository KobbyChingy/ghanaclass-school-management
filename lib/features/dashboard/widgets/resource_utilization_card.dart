import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghanaclass_school_management/core/services/ict_lab_service.dart';
import 'package:ghanaclass_school_management/core/services/science_lab_service.dart';
import 'package:intl/intl.dart';

import 'package:ghanaclass_school_management/core/providers/database_provider.dart';

/// Analytics card for resource utilization (ICT & Science Labs)
class ResourceUtilizationCard extends ConsumerWidget {
  const ResourceUtilizationCard({super.key});

  static final DateFormat _dayFormat = DateFormat('EEE, d MMM');
  static final DateFormat _timeFormat = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final ictLabService = IctLabService(db);
    final scienceLabService = ScienceLabService(db);
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    final to = DateTime(now.year, now.month + 1, 1).subtract(const Duration(days: 1));

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resource Utilization (Labs)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            FutureBuilder(
              future: Future.wait([
                ictLabService.getUsageSessions(from: from, to: to),
                scienceLabService.getUsageSessions(from: from, to: to),
              ]),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final ictSessions = snapshot.data![0] as List<IctLabUsageSessionWithMeta>;
                final sciSessions = snapshot.data![1] as List<ScienceLabUsageSessionWithMeta>;
                final ictEntries = ictSessions
                    .map(
                      (session) => _LabSessionEntry(
                        className: session.schoolClass?.className ?? 'Unassigned Class',
                        subjectName: session.subject?.subjectName ?? 'No subject',
                        teacherName: session.conductedBy?.fullName ?? 'Unassigned teacher',
                        participants: session.participants,
                        startedAt: session.session.startedAt,
                        endedAt: session.session.endedAt,
                      ),
                    )
                    .toList(growable: false);
                final scienceEntries = sciSessions
                    .map(
                      (session) => _LabSessionEntry(
                        className: session.schoolClass?.className ?? 'Unassigned Class',
                        subjectName: session.subject?.subjectName ?? 'No subject',
                        teacherName: session.conductedBy?.fullName ?? 'Unassigned teacher',
                        participants: session.participants,
                        startedAt: session.session.startedAt,
                        endedAt: session.session.endedAt,
                      ),
                    )
                    .toList(growable: false);
                final totalIctHours = _totalHours(ictEntries);
                final totalSciHours = _totalHours(scienceEntries);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _MetricChip(
                          label: 'ICT sessions',
                          value: '${ictEntries.length}',
                        ),
                        _MetricChip(
                          label: 'ICT hours',
                          value: totalIctHours.toStringAsFixed(1),
                        ),
                        _MetricChip(
                          label: 'Science sessions',
                          value: '${scienceEntries.length}',
                        ),
                        _MetricChip(
                          label: 'Science hours',
                          value: totalSciHours.toStringAsFixed(1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _LabSection(
                      title: 'ICT Lab Sessions',
                      accentColor: const Color(0xFF2563EB),
                      emptyMessage: 'No ICT lab sessions recorded this month.',
                      dayFormat: _dayFormat,
                      timeFormat: _timeFormat,
                      sessions: ictEntries,
                    ),
                    const SizedBox(height: 16),
                    _LabSection(
                      title: 'Science Lab Sessions',
                      accentColor: const Color(0xFF059669),
                      emptyMessage: 'No science lab sessions recorded this month.',
                      dayFormat: _dayFormat,
                      timeFormat: _timeFormat,
                      sessions: scienceEntries,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

double _totalHours(List<_LabSessionEntry> sessions) {
  return sessions.fold<double>(0, (sum, session) => sum + session.duration.inMinutes / 60);
}

class _LabSessionEntry {
  const _LabSessionEntry({
    required this.className,
    required this.subjectName,
    required this.teacherName,
    required this.participants,
    required this.startedAt,
    required this.endedAt,
  });

  final String className;
  final String subjectName;
  final String teacherName;
  final int participants;
  final DateTime startedAt;
  final DateTime? endedAt;

  Duration get duration => (endedAt ?? DateTime.now()).difference(startedAt);
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _LabSection extends StatelessWidget {
  const _LabSection({
    required this.title,
    required this.accentColor,
    required this.emptyMessage,
    required this.dayFormat,
    required this.timeFormat,
    required this.sessions,
  });

  final String title;
  final Color accentColor;
  final String emptyMessage;
  final DateFormat dayFormat;
  final DateFormat timeFormat;
  final List<_LabSessionEntry> sessions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupedSessions = <String, List<_LabSessionEntry>>{};

    for (final session in sessions) {
      groupedSessions.putIfAbsent(session.className, () => <_LabSessionEntry>[]).add(session);
    }

    final classNames = groupedSessions.keys.toList()..sort();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withValues(alpha: 0.24)),
        color: accentColor.withValues(alpha: 0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (sessions.isEmpty)
            Text(emptyMessage, style: theme.textTheme.bodyMedium)
          else
            ...classNames.map(
              (className) {
                final classSessions = groupedSessions[className]!..sort((a, b) => a.startedAt.compareTo(b.startedAt));
                final totalHours = _totalHours(classSessions);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              className,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            '${classSessions.length} sessions • ${totalHours.toStringAsFixed(1)} hrs',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...classSessions.map(
                        (session) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _SessionTile(
                            session: session,
                            accentColor: accentColor,
                            dayFormat: dayFormat,
                            timeFormat: timeFormat,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.accentColor,
    required this.dayFormat,
    required this.timeFormat,
  });

  final _LabSessionEntry session;
  final Color accentColor;
  final DateFormat dayFormat;
  final DateFormat timeFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final endedAt = session.endedAt;
    final timeRange = endedAt == null
        ? '${timeFormat.format(session.startedAt)} onward'
        : '${timeFormat.format(session.startedAt)} - ${timeFormat.format(endedAt)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  session.subjectName,
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${session.duration.inMinutes ~/ 60}h ${session.duration.inMinutes % 60}m',
                style: theme.textTheme.bodySmall?.copyWith(color: accentColor, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${dayFormat.format(session.startedAt)} • $timeRange',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Teacher: ${session.teacherName} • Students: ${session.participants}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
