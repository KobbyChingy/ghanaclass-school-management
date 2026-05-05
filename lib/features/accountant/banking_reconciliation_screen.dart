import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:ghanaclass_school_management/core/constants/theme.dart';

class BankingReconciliationScreen extends StatelessWidget {
  const BankingReconciliationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Banking & Reconciliation')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Accounts & Statements',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Manage multiple accounts (bank + mobile money), import statements, and reconcile collections to transactions.',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _comingSoon(context),
                      icon: const Icon(LucideIcons.plus, size: 18),
                      label: const Text('Add Account'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _comingSoon(context),
                      icon: const Icon(LucideIcons.upload, size: 18),
                      label: const Text('Import Statement (CSV)'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.authorityYellow, foregroundColor: Colors.black),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _comingSoon(context),
                      icon: const Icon(LucideIcons.gitCompare, size: 18),
                      label: const Text('Run Reconciliation'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.actionIndigo, foregroundColor: Colors.white),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _comingSoon(context),
                      icon: const Icon(LucideIcons.lineChart, size: 18),
                      label: const Text('Cashflow Projection'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.actionIndigo.withValues(alpha: 0.08), foregroundColor: AppTheme.actionIndigo, elevation: 0),
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
                          Text('Matching Strategy (planned)', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 10),
                          Text('• Exact match on amount + reference where available.'),
                          Text('• Fuzzy match on payer name + amount within a date window.'),
                          Text('• Manual override and audit trail for adjustments.'),
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
      const SnackBar(content: Text('Banking & Reconciliation: coming soon.')),
    );
  }
}
