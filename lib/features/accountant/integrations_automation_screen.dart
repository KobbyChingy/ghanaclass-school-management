import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:ghanaclass_school_management/core/constants/theme.dart';

class IntegrationsAutomationScreen extends StatelessWidget {
  const IntegrationsAutomationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Integrations & Automation')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payments, Messaging, and Exports',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Connect SMS/email alerts, payment gateways (MoMo/bank), and export to accounting tools.',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: ListView(
                    children: const [
                      _IntegrationTile(
                        icon: LucideIcons.messageSquare,
                        title: 'SMS Reminders',
                        subtitle: 'Send arrears reminders and payment confirmations (e.g., Africa\'s Talking).',
                      ),
                      _IntegrationTile(
                        icon: LucideIcons.creditCard,
                        title: 'Payment Gateways',
                        subtitle: 'Integrate Paystack/Hubtel webhooks for real-time confirmations.',
                      ),
                      _IntegrationTile(
                        icon: LucideIcons.cloud,
                        title: 'Webhooks / API',
                        subtitle: 'Push events to external systems and receive payment callbacks.',
                      ),
                      _IntegrationTile(
                        icon: LucideIcons.sheet,
                        title: 'Accounting Export',
                        subtitle: 'Export collections and expenses for QuickBooks/CSV.',
                      ),
                      _IntegrationTile(
                        icon: LucideIcons.smartphone,
                        title: 'Parent Portal Sync',
                        subtitle: 'Parents view balances, invoices, and receipts online.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: null,
                      icon: Icon(LucideIcons.settings, size: 18),
                      label: Text('Configure Integrations (coming soon)'),
                    ),
                    ElevatedButton.icon(
                      onPressed: null,
                      icon: Icon(LucideIcons.send, size: 18),
                      label: Text('Test SMS/Email (coming soon)'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.authorityYellow, foregroundColor: Colors.black),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IntegrationTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _IntegrationTile({
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
            color: AppTheme.actionIndigo.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.actionIndigo),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.textMuted)),
      ),
    );
  }
}
