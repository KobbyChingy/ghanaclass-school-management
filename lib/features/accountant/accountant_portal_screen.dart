import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/core/providers/system_settings_providers.dart';
import 'package:ghanaclass_school_management/shared/widgets/portal_surface.dart';

class AccountantPortalScreen extends ConsumerWidget {
  const AccountantPortalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final academicYear = ref.watch(activeYearProvider);
    final term = ref.watch(activeTermProvider);
    final tiles = <_PortalTileData>[
      _PortalTileData(
        title: 'My Profile',
        subtitle: 'Account details and profile overview',
        icon: LucideIcons.user,
        onTap: () => context.go('/accountant/profile'),
      ),
      _PortalTileData(
        title: 'Fee Structure Setup',
        subtitle: 'Set term fees, categories, discounts',
        icon: LucideIcons.slidersHorizontal,
        onTap: () => context.go('/finance/fees'),
      ),
      _PortalTileData(
        title: 'Billing & Invoicing',
        subtitle: 'Generate invoices, templates, exports',
        icon: LucideIcons.fileText,
        onTap: () => context.go('/accountant/invoicing'),
      ),
      _PortalTileData(
        title: 'Payments & Receipts',
        subtitle: 'Record payments and issue receipts',
        icon: LucideIcons.banknote,
        onTap: () => context.go('/finance/payments'),
      ),
      _PortalTileData(
        title: 'Arrears & Reminders',
        subtitle: 'Track arrears, send reminders',
        icon: LucideIcons.bellRing,
        onTap: () => context.go('/accountant/arrears'),
      ),
      _PortalTileData(
        title: 'Expense Management',
        subtitle: 'Record expenses and approvals',
        icon: LucideIcons.shoppingBag,
        onTap: () => context.go('/finance/expenses'),
      ),
      _PortalTileData(
        title: 'Payroll Processing',
        subtitle: 'Salaries, deductions, payslips',
        icon: LucideIcons.wallet,
        onTap: () => context.go('/finance/payroll'),
      ),
      _PortalTileData(
        title: 'Banking & Reconciliation',
        subtitle: 'Statements, reconciliation, cashflow',
        icon: LucideIcons.landmark,
        onTap: () => context.go('/accountant/banking'),
      ),
      _PortalTileData(
        title: 'Reports & Analytics',
        subtitle: 'Collections, P&L, debtors, exports',
        icon: LucideIcons.barChart3,
        onTap: () => context.go('/finance/analytics'),
      ),
      _PortalTileData(
        title: 'Inventory & Assets',
        subtitle: 'Assets, uniforms/stock (optional)',
        icon: LucideIcons.package,
        onTap: () => context.go('/accountant/assets'),
      ),
      _PortalTileData(
        title: 'Security & Compliance',
        subtitle: 'Roles, audit trails, backups',
        icon: LucideIcons.shieldCheck,
        onTap: () => context.go('/accountant/security'),
      ),
      _PortalTileData(
        title: 'Integrations & Automation',
        subtitle: 'SMS/email, MoMo, exports, webhooks',
        icon: LucideIcons.zap,
        onTap: () => context.go('/accountant/integrations'),
      ),
    ];

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PortalHeroBanner(
                  eyebrow: 'Accountant portal',
                  title: 'Finance Operations',
                  subtitle: '${currentUser?.fullName ?? 'Finance lead'} is managing fees, cashflow, arrears, expenses, payroll, and reporting for the active term.',
                  icon: LucideIcons.wallet,
                  primary: const Color(0xFF0F766E),
                  accent: const Color(0xFFF59E0B),
                  metrics: [
                    PortalHeroMetric(label: 'Academic year', value: '$academicYear'),
                    PortalHeroMetric(label: 'Active term', value: 'Term $term'),
                    PortalHeroMetric(label: 'Finance lanes', value: '${tiles.length}'),
                  ],
                ),
                const SizedBox(height: 24),
                PortalSectionPanel(
                  title: 'Finance Lanes',
                  subtitle: 'Billing, collections, expense controls, payroll, reconciliation, and compliance workflows.',
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      double cardWidth = (constraints.maxWidth - 32) / 3;
                      if (constraints.maxWidth < 980) {
                        cardWidth = (constraints.maxWidth - 16) / 2;
                      }
                      if (constraints.maxWidth < 640) {
                        cardWidth = constraints.maxWidth;
                      }
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          for (var index = 0; index < tiles.length; index++)
                            SizedBox(
                              width: cardWidth,
                              height: 190,
                              child: _PortalTile(data: tiles[index], index: index),
                            ),
                        ],
                      );
                    },
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

class _PortalTileData {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _PortalTileData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}

class _PortalTile extends StatelessWidget {
  final _PortalTileData data;
  final int index;

  const _PortalTile({required this.data, required this.index});

  @override
  Widget build(BuildContext context) {
    final tones = [
      (const Color(0xFF0F766E), const Color(0xFF14B8A6)),
      (const Color(0xFF4F46E5), const Color(0xFF818CF8)),
      (const Color(0xFFF59E0B), const Color(0xFFFBBF24)),
      (const Color(0xFFBE185D), const Color(0xFFF472B6)),
    ];
    final tone = tones[index % tones.length];
    return PortalActionCard(
      title: data.title,
      subtitle: data.subtitle,
      icon: data.icon,
      onTap: data.onTap,
      primary: tone.$1,
      accent: tone.$2,
      badge: 'Finance',
    );
  }
}
