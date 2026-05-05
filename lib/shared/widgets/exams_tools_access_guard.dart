import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/features/teachers/teacher_providers.dart';

class ExamsToolsAccessGuard extends ConsumerWidget {
  final Widget child;
  final String title;

  const ExamsToolsAccessGuard({
    super.key,
    required this.child,
    required this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final roleName = user?.role;

    if (roleName != UserRole.teacher.name) {
      return _RestrictedScaffold(title: title);
    }

    final canAccessAsync = ref.watch(canAccessExamsToolsProvider);
    return canAccessAsync.when(
      data: (canAccess) => canAccess ? child : _RestrictedScaffold(title: title),
      loading: () => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _RestrictedScaffold(title: title),
    );
  }
}

class _RestrictedScaffold extends StatelessWidget {
  final String title;

  const _RestrictedScaffold({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.lock, size: 48, color: AppTheme.textMuted.withValues(alpha: 0.6)),
              const SizedBox(height: 12),
              const Text('Access restricted', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              const Text(
                'Only head/class teachers and subject teachers can access this feature.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
