import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/shared/widgets/portal_surface.dart';

class AccountantProfileScreen extends ConsumerWidget {
  const AccountantProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final horizontalPadding = portalHorizontalPadding(context);
    final contentMaxWidth = portalContentMaxWidth(context);
    final stackedIdentity = MediaQuery.sizeOf(context).width < 560;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentMaxWidth),
          child: ListView(
            padding: EdgeInsets.all(horizontalPadding),
            children: [
              PortalHeroBanner(
                eyebrow: 'Finance profile',
                title: 'Accountant Profile',
                subtitle: 'Identity and access details for the finance operations account currently signed in.',
                icon: LucideIcons.wallet,
                primary: const Color(0xFF0F766E),
                accent: const Color(0xFFF59E0B),
                metrics: [
                  PortalHeroMetric(label: 'Full name', value: user.fullName),
                  PortalHeroMetric(label: 'Role', value: user.role),
                ],
              ),
              const SizedBox(height: 20),
              PortalSectionPanel(
                title: 'Finance Identity',
                subtitle: 'Core profile information for this accountant portal account.',
                child: stackedIdentity
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: AppTheme.actionIndigo.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(LucideIcons.user, color: AppTheme.actionIndigo),
                          ),
                          const SizedBox(height: 14),
                          Text(user.fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(user.email, style: const TextStyle(color: AppTheme.textMuted)),
                          const SizedBox(height: 6),
                          Text('Role: ${user.role}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                        ],
                      )
                    : Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: AppTheme.actionIndigo.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(LucideIcons.user, color: AppTheme.actionIndigo),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user.fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Text(user.email, style: const TextStyle(color: AppTheme.textMuted)),
                                const SizedBox(height: 6),
                                Text('Role: ${user.role}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
