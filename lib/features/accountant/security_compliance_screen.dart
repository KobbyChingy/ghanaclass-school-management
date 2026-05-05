import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:ghanaclass_school_management/core/constants/theme.dart';

class SecurityComplianceScreen extends StatelessWidget {
  const SecurityComplianceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Security & Compliance')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Controls & Auditability',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Role-based access, audit trails, backups, and data protection for sensitive finance records.',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: ListView(
                    children: const [
                      _InfoTile(
                        icon: LucideIcons.userCheck,
                        title: 'Role-based Access',
                        subtitle: 'Accountant-only views for finance modules; admin override.',
                      ),
                      _InfoTile(
                        icon: LucideIcons.scrollText,
                        title: 'Audit Trails',
                        subtitle: 'Track who changed fees, payments, invoices, and expenses.',
                      ),
                      _InfoTile(
                        icon: LucideIcons.lock,
                        title: 'Backups & Encryption',
                        subtitle: 'Regular backups and secure storage for credentials and documents.',
                      ),
                      _InfoTile(
                        icon: LucideIcons.receipt,
                        title: 'Tax Compliance (Ghana)',
                        subtitle: 'Support VAT/PAYE reporting where applicable and keep export-ready records.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: null,
                    icon: Icon(LucideIcons.history, size: 18),
                    label: Text('Open Audit Log (coming soon)'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primarySlate.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primarySlate),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.textMuted)),
      ),
    );
  }
}
