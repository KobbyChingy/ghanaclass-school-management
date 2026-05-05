import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:ghanaclass_school_management/core/constants/theme.dart';

class BillingInvoicingScreen extends StatelessWidget {
  const BillingInvoicingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Billing & Invoicing')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Invoices',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Generate individual, class, or batch invoices. Customize templates (logo, due dates) and export to PDF/Excel.',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _ActionButton(
                      icon: LucideIcons.filePlus,
                      label: 'Create Invoice',
                      onTap: () => _comingSoon(context),
                    ),
                    _ActionButton(
                      icon: LucideIcons.layers,
                      label: 'Batch Invoices',
                      onTap: () => _comingSoon(context),
                    ),
                    _ActionButton(
                      icon: LucideIcons.download,
                      label: 'Export PDF/Excel',
                      onTap: () => _comingSoon(context),
                    ),
                    _ActionButton(
                      icon: LucideIcons.settings2,
                      label: 'Template Settings',
                      onTap: () => _comingSoon(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Implementation Notes', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 10),
                          Text('• Auto-invoice on term start/enrollment.'),
                          Text('• Link invoices to parent portal for online viewing.'),
                          Text('• Keep a full audit log of invoice creation/edits.'),
                        ],
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
      const SnackBar(content: Text('Billing & Invoicing: coming soon.')),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.actionIndigo.withValues(alpha: 0.08),
        foregroundColor: AppTheme.actionIndigo,
        elevation: 0,
      ),
    );
  }
}
