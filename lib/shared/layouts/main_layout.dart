import 'dart:ui';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/shared/widgets/sync_status_indicator.dart';
import 'package:ghanaclass_school_management/shared/widgets/offline_connectivity_listener.dart';
import 'package:ghanaclass_school_management/core/providers/activity_providers.dart';
import 'package:ghanaclass_school_management/features/teachers/teacher_providers.dart';
import 'package:ghanaclass_school_management/features/alarms/alarm_providers.dart';
import 'package:ghanaclass_school_management/core/router/role_routes.dart';

class MainLayout extends ConsumerWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  Future<void> _showChangePasswordDialog(BuildContext context, WidgetRef ref, int userId) async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    var obscureCurrent = true;
    var obscureNew = true;
    var obscureConfirm = true;

    try {
      final submitted = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setLocalState) {
              return AlertDialog(
                title: const Text('Change Password'),
                content: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: currentController,
                        decoration: InputDecoration(
                          labelText: 'Current Password',
                          suffixIcon: IconButton(
                            icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setLocalState(() => obscureCurrent = !obscureCurrent),
                          ),
                        ),
                        obscureText: obscureCurrent,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: newController,
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          suffixIcon: IconButton(
                            icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setLocalState(() => obscureNew = !obscureNew),
                          ),
                        ),
                        obscureText: obscureNew,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: confirmController,
                        decoration: InputDecoration(
                          labelText: 'Confirm New Password',
                          suffixIcon: IconButton(
                            icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setLocalState(() => obscureConfirm = !obscureConfirm),
                          ),
                        ),
                        obscureText: obscureConfirm,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
                  ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('UPDATE')),
                ],
              );
            },
          );
        },
      );

      if (submitted != true) return;
      if (!context.mounted) return;
      final current = currentController.text;
      final next = newController.text;
      final confirm = confirmController.text;

      if (next.trim().length < 4) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password too short (min 4).'), backgroundColor: Colors.red),
        );
        return;
      }
      if (next.trim() != confirm.trim()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match.'), backgroundColor: Colors.red),
        );
        return;
      }

      await ref.read(authServiceProvider).updatePassword(
            userId: userId,
            oldPassword: current,
            newPassword: next,
          );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
    } finally {
      currentController.dispose();
      newController.dispose();
      confirmController.dispose();
    }
  }

  List<NavigationItem> _getNavigationItems(WidgetRef ref, UserRole role) {
    final commonItems = [
      NavigationItem(icon: LucideIcons.layoutDashboard, label: 'Dashboard', route: '/dashboard'),
    ];

    final canAccessExamsTools = ref.watch(canAccessExamsToolsProvider).maybeWhen(
          data: (v) => v,
          orElse: () => false,
        );

    switch (role) {
      case UserRole.admin:
        return [...commonItems,
          NavigationItem(icon: LucideIcons.users, label: 'Students', route: '/students'),
          NavigationItem(icon: LucideIcons.school, label: 'Classes', route: '/classes'),
          NavigationItem(icon: LucideIcons.bookOpen, label: 'Subjects', route: '/subjects'),
          NavigationItem(icon: LucideIcons.userCog, label: 'Teacher Assignments', route: '/teacher-assignments'),
          NavigationItem(icon: LucideIcons.userCheck, label: 'Staff', route: '/staff'),
          NavigationItem(icon: LucideIcons.clipboardCheck, label: 'Attendance', route: '/attendance'),
          NavigationItem(icon: LucideIcons.bookOpen, label: 'Ledger', route: '/finance/fees'),
          NavigationItem(icon: LucideIcons.wallet, label: 'Payroll', route: '/finance/payroll'),
          NavigationItem(icon: LucideIcons.shoppingBag, label: 'Expenses', route: '/finance/expenses'),
          NavigationItem(icon: LucideIcons.user, label: 'My Profile', route: '/profile'),
          NavigationItem(icon: LucideIcons.clock, label: 'Alarm / Siren', route: '/alarms'),
          NavigationItem(icon: LucideIcons.creditCard, label: 'ID Cards', route: '/id-cards'),
          NavigationItem(icon: LucideIcons.settings, label: 'Settings', route: '/director/settings'),
        ];
      case UserRole.director:
        return [
          NavigationItem(
            icon: LucideIcons.layoutDashboard,
            label: 'Executive Dashboard',
            route: '/director/executive-dashboard',
          ),
          NavigationItem(
            icon: LucideIcons.wallet,
            label: 'Budget',
            route: '/director/budget',
          ),
          NavigationItem(
            icon: LucideIcons.receipt,
            label: 'Expenses',
            route: '/director/expenses',
          ),
          NavigationItem(
            icon: LucideIcons.lineChart,
            label: 'Analytics',
            route: '/director/analytics',
          ),
          NavigationItem(
            icon: LucideIcons.activity,
            label: 'Resource Utilization',
            route: '/director/resource-utilization',
          ),
          NavigationItem(
            icon: LucideIcons.clipboardList,
            label: 'Audit Logs',
            route: '/director/audit-logs',
          ),
          NavigationItem(
            icon: LucideIcons.shieldCheck,
            label: 'Data Access Roles',
            route: '/director/data-access-roles',
          ),
          NavigationItem(icon: LucideIcons.settings, label: 'Settings', route: '/settings'),
        ];
      case UserRole.headmaster:
      case UserRole.headmistress:
        return [
          NavigationItem(
            icon: LucideIcons.layoutDashboard,
            label: 'Dashboard',
            route: '/dashboard',
            children: [
              NavigationItem(icon: LucideIcons.trendingUp, label: 'Financial Analytics', route: '/finance/analytics'),
              NavigationItem(icon: LucideIcons.clock, label: 'Alarms', route: '/alarms'),
              NavigationItem(icon: LucideIcons.clipboardCheck, label: 'Staff Attendance', route: '/attendance'),
            ],
          ),
          NavigationItem(
            icon: LucideIcons.bookOpen,
            label: 'Finance',
            route: '/finance/fees',
            children: [
              NavigationItem(icon: LucideIcons.bookOpen, label: 'Fees / Ledger', route: '/finance/fees'),
              NavigationItem(icon: LucideIcons.banknote, label: 'Payments', route: '/finance/payments'),
              NavigationItem(icon: LucideIcons.wallet, label: 'Payroll', route: '/finance/payroll'),
              NavigationItem(icon: LucideIcons.shoppingBag, label: 'Expenses', route: '/finance/expenses'),
              NavigationItem(icon: LucideIcons.trendingUp, label: 'Analytics', route: '/finance/analytics'),
            ],
          ),
          NavigationItem(
            icon: LucideIcons.users,
            label: 'People',
            route: '/students',
            children: [
              NavigationItem(icon: LucideIcons.users, label: 'Students', route: '/students'),
              NavigationItem(icon: LucideIcons.userCheck, label: 'Staff', route: '/staff'),
              NavigationItem(icon: LucideIcons.userPlus, label: 'Admissions', route: '/admissions'),
              NavigationItem(icon: LucideIcons.creditCard, label: 'ID Cards', route: '/id-cards'),
            ],
          ),
          NavigationItem(
            icon: LucideIcons.school,
            label: 'Academics',
            route: '/classes',
            children: [
              NavigationItem(icon: LucideIcons.school, label: 'Classes', route: '/classes'),
              NavigationItem(icon: LucideIcons.bookOpen, label: 'Subjects', route: '/subjects'),
              NavigationItem(icon: LucideIcons.userCog, label: 'Teacher Assignments', route: '/teacher-assignments'),
            ],
          ),
          NavigationItem(icon: LucideIcons.user, label: 'My Profile', route: '/profile'),
          NavigationItem(icon: LucideIcons.settings, label: 'Settings', route: '/settings'),
        ];
      case UserRole.deputyheadmaster:
      case UserRole.deputyheadmistress:
        return [...commonItems];
      case UserRole.teacher:
        return [
          NavigationItem(icon: LucideIcons.layoutDashboard, label: 'Dashboard', route: '/teacher'),
          NavigationItem(icon: LucideIcons.user, label: 'Profile', route: '/teacher/profile'),
          NavigationItem(icon: LucideIcons.users, label: 'My Students', route: '/my-students'),
          NavigationItem(icon: LucideIcons.school, label: 'My Classes', route: '/teacher/classes'),
          NavigationItem(icon: LucideIcons.bookOpen, label: 'Lesson Notes', route: '/teacher/lesson-notes'),
          NavigationItem(icon: LucideIcons.clipboardCheck, label: 'Attendance', route: '/attendance'),
          if (canAccessExamsTools) ...[
            NavigationItem(icon: LucideIcons.database, label: 'Question Bank', route: '/exams/bank'),
            NavigationItem(icon: LucideIcons.fileText, label: 'Exam Generator', route: '/exams/generate'),
          ],
          NavigationItem(icon: LucideIcons.fileBarChart2, label: 'Reports', route: '/teacher/reports'),
        ];
      case UserRole.accountant:
        return [
          NavigationItem(icon: LucideIcons.layoutDashboard, label: 'Portal', route: '/accountant'),
          NavigationItem(icon: LucideIcons.user, label: 'Profile', route: '/accountant/profile'),
          NavigationItem(icon: LucideIcons.bookOpen, label: 'Ledger', route: '/finance/fees'),
          NavigationItem(icon: LucideIcons.banknote, label: 'Payments', route: '/finance/payments'),
          NavigationItem(icon: LucideIcons.wallet, label: 'Payroll', route: '/finance/payroll'),
          NavigationItem(icon: LucideIcons.shoppingBag, label: 'Expenses', route: '/finance/expenses'),
          NavigationItem(icon: LucideIcons.trendingUp, label: 'Analytics', route: '/finance/analytics'),
        ];
      case UserRole.secretary:
      case UserRole.security:
      case UserRole.ictlab:
      case UserRole.sciencelab:
        return [...commonItems];
      case UserRole.shop:
        return [
          NavigationItem(icon: LucideIcons.layoutDashboard, label: 'Dashboard', route: '/shop/dashboard'),
          NavigationItem(icon: LucideIcons.shoppingCart, label: 'POS', route: '/pos'),
          NavigationItem(icon: LucideIcons.package, label: 'Inventory', route: '/inventory'),
          NavigationItem(icon: LucideIcons.barChart3, label: 'Reports', route: '/shop/reports'),
          NavigationItem(icon: LucideIcons.users, label: 'Suppliers', route: '/shop/suppliers'),
          NavigationItem(icon: LucideIcons.walletCards, label: 'Wallets', route: '/shop/wallet'),
          NavigationItem(icon: LucideIcons.user, label: 'Profile', route: '/shop/profile'),
        ];
      case UserRole.chef:
      case UserRole.infirmary:
      case UserRole.library:
      case UserRole.parent:
        return [...commonItems];
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role.colorCode) {
      case 'slate': return AppTheme.primarySlate;
      case 'indigo': return AppTheme.actionIndigo;
      case 'yellow': return AppTheme.authorityYellow;
      default: return AppTheme.actionIndigo;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    
    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

      final userRole = UserRole.values.firstWhere(
        (role) => roleNameMatches(currentUser.role, role),
        orElse: () => UserRole.admin,
      );

    // Keep the scheduler alive for admins so alarms can fire while the app is running.
    if (userRole == UserRole.admin) {
      ref.watch(alarmSchedulerProvider);
    }
    
    final navigationItems = _getNavigationItems(ref, userRole);
    final roleColor = _getRoleColor(userRole);
    final identityAsync = ref.watch(institutionalIdentityProvider);
    final schoolName = identityAsync.maybeWhen(
      data: (identity) => (identity?.schoolName.trim().isNotEmpty == true)
          ? identity!.schoolName.trim()
          : 'School Management System',
      orElse: () => 'School Management System',
    );
    final portalLabel = supportedPortalRoles.contains(userRole)
        ? '${userRole.displayName.toUpperCase()} PORTAL'
        : 'STAFF ACCESS';
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          const OfflineConnectivityListener(serverModeOnly: true),
          DecoratedBox(
            decoration: BoxDecoration(gradient: AppTheme.appBackgroundGradient),
            child: Row(
              children: [
                // Sidebar
                Container(
                  width: 284,
                  margin: const EdgeInsets.fromLTRB(18, 18, 0, 18),
                  decoration: BoxDecoration(
                    gradient: AppTheme.sidebarGradient,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primarySlate.withValues(alpha: 0.18),
                        blurRadius: 28,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Text(
                          portalLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  roleColor.withValues(alpha: 0.32),
                                  Colors.white.withValues(alpha: 0.08),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: identityAsync.maybeWhen(
                              data: (identity) {
                                final bytes = identity?.logoBytes;
                                if (bytes != null && bytes.isNotEmpty) {
                                  return Image.memory(bytes, fit: BoxFit.cover);
                                }
                                final path = identity?.logoPath;
                                if (path != null && path.trim().isNotEmpty) {
                                  return Image.file(File(path), fit: BoxFit.cover);
                                }
                                return const Icon(LucideIcons.school, size: 22, color: Colors.white70);
                              },
                              orElse: () => const Icon(LucideIcons.school, size: 22, color: Colors.white70),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  schoolName,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                    'Operational workspace',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.white70,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          _NotificationsBell(roleColor: roleColor),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const SyncStatusIndicator(),
                    ],
                  ),
                ),
                
                // Navigation Items
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final matchedLocation = GoRouterState.of(context).matchedLocation;

                      bool isRouteActive(String route) {
                        if (matchedLocation == route) return true;
                        if (matchedLocation.startsWith('$route/')) return true;
                        return false;
                      }

                      bool isItemActive(NavigationItem item) {
                        if (isRouteActive(item.route)) return true;
                        for (final child in item.children) {
                          if (isRouteActive(child.route)) return true;
                        }
                        return false;
                      }

                      Widget buildNavTile(NavigationItem item, {double indent = 0}) {
                        final isActive = indent > 0 ? isRouteActive(item.route) : isItemActive(item);

                        return Padding(
                          padding: EdgeInsets.fromLTRB(12 + indent, 4, 12, 4),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              gradient: isActive
                                  ? LinearGradient(
                                      colors: [
                                        roleColor.withValues(alpha: 0.28),
                                        roleColor.withValues(alpha: 0.12),
                                      ],
                                    )
                                  : null,
                              color: isActive ? null : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isActive ? roleColor.withValues(alpha: 0.18) : Colors.transparent,
                              ),
                            ),
                            child: ListTile(
                              leading: Icon(item.icon, color: isActive ? Colors.white : Colors.white70, size: indent > 0 ? 18 : 20),
                              title: Text(
                                item.label,
                                style: TextStyle(
                                  color: isActive ? Colors.white : Colors.white70,
                                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                                  fontSize: indent > 0 ? 13 : 14,
                                ),
                              ),
                              selected: isActive,
                              selectedTileColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              onTap: () => context.go(item.route),
                            ),
                          ),
                        );
                      }

                      final tiles = <Widget>[];
                      for (final item in navigationItems) {
                        tiles.add(buildNavTile(item));
                        if (item.children.isNotEmpty) {
                          for (final childItem in item.children) {
                            tiles.add(buildNavTile(childItem, indent: 18));
                          }
                        }
                      }

                      return ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: tiles,
                      );
                    },
                  ),
                ),
                
                // User Profile
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08)))),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: roleColor.withValues(alpha: 0.2),
                        child: Text(currentUser.fullName[0].toUpperCase(), style: TextStyle(color: roleColor, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(currentUser.fullName, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                            Text(currentUser.email, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Change password',
                        icon: const Icon(LucideIcons.keyRound),
                        color: Colors.white70,
                        onPressed: () => _showChangePasswordDialog(context, ref, currentUser.id),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.logOut),
                        color: Colors.white70,
                        onPressed: () async {
                          final token = ref.read(sessionTokenProvider);
                          if (token != null) {
                            await ref.read(authServiceProvider).logout(token);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.remove('session_token');
                            ref.read(sessionTokenProvider.notifier).setToken(null);
                            ref.read(currentUserProvider.notifier).setUser(null);
                          }
                        },
                      ),
                    ],
                  ),
                ),

                // Developer Branding
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.16),
                    border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.04))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: const DecorationImage(
                            image: NetworkImage(
                              'https://pub-141831e61e69445289222976a15b6fb3.r2.dev/Image_to_url_V2/OmniWeave-Logo-imagetourl.cloud-1768845152819-xd0lbd.jpeg',
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Powered by OmniWeave',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
                // Main Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.68),
                        borderRadius: BorderRadius.circular(34),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primarySlate.withValues(alpha: 0.08),
                            blurRadius: 28,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(34),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Column(
                            children: [
                // Top header bar
                Container(
                  height: 84,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.72),
                    border: const Border(
                      bottom: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                colors: [
                                  roleColor.withValues(alpha: 0.18),
                                  AppTheme.surfaceMuted,
                                ],
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: identityAsync.maybeWhen(
                              data: (identity) {
                                final bytes = identity?.logoBytes;
                                if (bytes != null && bytes.isNotEmpty) {
                                  return Image.memory(bytes, fit: BoxFit.cover);
                                }
                                final path = identity?.logoPath;
                                if (path != null && path.trim().isNotEmpty) {
                                  return Image.file(File(path), fit: BoxFit.cover);
                                }
                                return const Icon(LucideIcons.school, size: 18, color: AppTheme.textMuted);
                              },
                              orElse: () => const Icon(LucideIcons.school, size: 18, color: AppTheme.textMuted),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                schoolName,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                portalLabel,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.textMuted,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const SyncStatusIndicator(),
                          const SizedBox(width: 18),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                currentUser.fullName,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: roleColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${userRole.displayName} Workspace',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: roleColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Workspace
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Container(
                      key: ValueKey(child.runtimeType),
                      decoration: BoxDecoration(
                        gradient: AppTheme.appBackgroundGradient,
                      ),
                      child: child,
                    ),
                  ),
                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsBell extends ConsumerWidget {
  final Color roleColor;

  const _NotificationsBell({required this.roleColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final importantAsync = ref.watch(importantActivitiesProvider);

    return importantAsync.when(
      data: (items) {
        final count = items.length;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(LucideIcons.bell),
              color: AppTheme.textMuted,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Notifications'),
                    content: SizedBox(
                      width: 360,
                      height: 320,
                      child: count == 0
                          ? Center(
                              child: Text(
                                'No important notifications yet.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppTheme.textMuted),
                              ),
                            )
                          : ListView.separated(
                              itemCount: count,
                              separatorBuilder: (_, index) =>
                                  const Divider(height: 8),
                              itemBuilder: (context, index) {
                                final log = items[index];
                                return ListTile(
                                  leading: Icon(
                                    LucideIcons.activity,
                                    size: 18,
                                    color: roleColor,
                                  ),
                                  title: Text(
                                    log.description,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  subtitle: Text(
                                    '${log.actorName} • ${log.module.toUpperCase()}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                            color: AppTheme.textMuted,
                                            fontSize: 11),
                                  ),
                                );
                              },
                            ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (count > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: roleColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    count > 9 ? '9+' : count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => IconButton(
        icon: const Icon(LucideIcons.bell),
        color: AppTheme.textMuted,
        onPressed: () {},
      ),
      error: (err, stack) => IconButton(
        icon: const Icon(LucideIcons.bellOff),
        color: AppTheme.textMuted,
        onPressed: () {},
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final String label;
  final String route;
  final List<NavigationItem> children;

  NavigationItem({
    required this.icon,
    required this.label,
    required this.route,
    this.children = const [],
  });
}
