import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:ghanaclass_school_management/core/constants/theme.dart';

class ArrearsRemindersScreen extends StatelessWidget {
  const ArrearsRemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Arrears & Reminders')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aged Debtors & Follow-ups',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Filter by class/term/amount overdue, send SMS/email reminders, and generate defaulter reports.',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 760;
                    final fields = [
                      _FilterField(
                        label: 'Class',
                        icon: LucideIcons.school,
                        hint: 'e.g., JHS 2',
                      ),
                      _FilterField(
                        label: 'Overdue (days)',
                        icon: LucideIcons.calendar,
                        hint: 'e.g., 7',
                      ),
                      _FilterField(
                        label: 'Min Amount (GHS)',
                        icon: LucideIcons.coins,
                        hint: 'e.g., 200',
                      ),
                    ];

                    if (compact) {
                      return Column(
                        children: [
                          for (var i = 0; i < fields.length; i++) ...[
                            fields[i],
                            if (i != fields.length - 1) const SizedBox(height: 12),
                          ],
                        ],
                      );
                    }

                    return Row(
                      children: [
                        for (var i = 0; i < fields.length; i++) ...[
                          Expanded(child: fields[i]),
                          if (i != fields.length - 1) const SizedBox(width: 12),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _comingSoon(context),
                      icon: const Icon(LucideIcons.search, size: 18),
                      label: const Text('View Arrears'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _comingSoon(context),
                      icon: const Icon(LucideIcons.messageSquare, size: 18),
                      label: const Text('Send SMS Reminders'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.authorityYellow, foregroundColor: Colors.black),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _comingSoon(context),
                      icon: const Icon(LucideIcons.mail, size: 18),
                      label: const Text('Send Email Reminders'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.actionIndigo, foregroundColor: Colors.white),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _comingSoon(context),
                      icon: const Icon(LucideIcons.fileDown, size: 18),
                      label: const Text('Export Defaulters'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.actionIndigo.withValues(alpha: 0.08), foregroundColor: AppTheme.actionIndigo, elevation: 0),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Card(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(LucideIcons.alertTriangle, color: AppTheme.textMuted),
                            SizedBox(height: 10),
                            Text('Arrears dashboard is coming soon.', style: TextStyle(color: AppTheme.textMuted)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Arrears & Reminders: coming soon.')),
    );
  }
}

class _FilterField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String hint;

  const _FilterField({
    required this.label,
    required this.icon,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
      ),
    );
  }
}
