import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ghanaclass_school_management/features/dashboard/dashboard_screen.dart';
import 'package:ghanaclass_school_management/features/auth/institutional_registration_screen.dart';
import 'package:ghanaclass_school_management/features/auth/login_screen.dart';
import 'package:ghanaclass_school_management/features/students/students_screen.dart';
import 'package:ghanaclass_school_management/features/students/student_admission_screen.dart';
import 'package:ghanaclass_school_management/features/students/student_profile_screen.dart';
import 'package:ghanaclass_school_management/features/teachers/teacher_students_screen.dart';
import 'package:ghanaclass_school_management/features/teachers/teacher_dashboard_screen.dart';
import 'package:ghanaclass_school_management/features/teachers/teacher_classes_screen.dart';
import 'package:ghanaclass_school_management/features/teachers/teacher_reports_screen.dart';
import 'package:ghanaclass_school_management/features/teachers/teacher_profile_screen.dart';
import 'package:ghanaclass_school_management/features/teachers/teacher_lesson_notes_screen.dart';
import 'package:ghanaclass_school_management/features/teachers/teacher_lesson_note_editor_screen.dart';
import 'package:ghanaclass_school_management/features/academic/classes_screen.dart';
import 'package:ghanaclass_school_management/features/academic/promotion_screen.dart';
import 'package:ghanaclass_school_management/features/academic/subjects_screen.dart';
import 'package:ghanaclass_school_management/features/academic/teacher_assignments_screen.dart';
import 'package:ghanaclass_school_management/features/id_cards/id_cards_screen.dart';
import 'package:ghanaclass_school_management/features/alarms/alarms_screen.dart';
import 'package:ghanaclass_school_management/features/staff/staff_screen.dart';
import 'package:ghanaclass_school_management/features/staff/staff_admission_screen.dart';
import 'package:ghanaclass_school_management/features/staff/staff_profile_screen.dart';
import 'package:ghanaclass_school_management/features/staff/staff_repair_screen.dart';
import 'package:ghanaclass_school_management/features/finance/fees_screen.dart';
import 'package:ghanaclass_school_management/features/finance/fee_payment_screen.dart';
import 'package:ghanaclass_school_management/features/finance/finance_analytics_screen.dart';
import 'package:ghanaclass_school_management/features/finance/payroll_screen.dart';
import 'package:ghanaclass_school_management/features/finance/expense_tracker_screen.dart';
import 'package:ghanaclass_school_management/features/accountant/accountant_portal_screen.dart';
import 'package:ghanaclass_school_management/features/accountant/billing_invoicing_screen.dart';
import 'package:ghanaclass_school_management/features/accountant/arrears_reminders_screen.dart';
import 'package:ghanaclass_school_management/features/accountant/banking_reconciliation_screen.dart';
import 'package:ghanaclass_school_management/features/accountant/assets_inventory_screen.dart';
import 'package:ghanaclass_school_management/features/accountant/security_compliance_screen.dart';
import 'package:ghanaclass_school_management/features/accountant/integrations_automation_screen.dart';
import 'package:ghanaclass_school_management/features/accountant/accountant_profile_screen.dart';
import 'package:ghanaclass_school_management/features/director/director_section_screen.dart';
import 'package:ghanaclass_school_management/features/headmaster/headmaster_portal_screen.dart';
import 'package:ghanaclass_school_management/features/settings/settings_screen.dart';
import 'package:ghanaclass_school_management/features/attendance/attendance_screen.dart';
import 'package:ghanaclass_school_management/features/attendance/staff_attendance_screen.dart';
import 'package:ghanaclass_school_management/features/exams/question_bank_screen.dart';
import 'package:ghanaclass_school_management/features/exams/exam_generator_screen.dart';
import 'package:ghanaclass_school_management/features/admin/admissions_hub_screen.dart';
import 'package:ghanaclass_school_management/features/shop/shop_dashboard_screen.dart';
import 'package:ghanaclass_school_management/features/shop/shop_inventory_screen.dart';
import 'package:ghanaclass_school_management/features/shop/shop_pos_screen.dart';
import 'package:ghanaclass_school_management/features/shop/shop_reports_screen.dart';
import 'package:ghanaclass_school_management/features/shop/shop_suppliers_screen.dart';
import 'package:ghanaclass_school_management/features/shop/shop_wallet_screen.dart';
import 'package:ghanaclass_school_management/core/router/role_routes.dart';
import 'package:ghanaclass_school_management/features/profile/staff_portal_profile_screen.dart';
import 'package:ghanaclass_school_management/shared/layouts/main_layout.dart';
import 'package:ghanaclass_school_management/shared/widgets/exams_tools_access_guard.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>((ref) {
  // IMPORTANT: Don't `watch()` auth providers here.
  // Recreating GoRouter when auth state changes will reset navigation back to
  // `initialLocation` (often making the app look "stuck" on /login).
  // Instead, keep one router instance and refresh redirects when state changes.
  late final GoRouter router;
  router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    redirect: (context, state) {
      final institutionRegistered = ref.read(institutionRegisteredProvider);
      final currentUser = ref.read(currentUserProvider);

      // 1. Wait for registration check to complete initially
      // This prevents premature redirection while we're fetching DB status
      if (institutionRegistered.isLoading) return null;

      final isRegistered = institutionRegistered.value ?? false;
      final isLoggedIn = currentUser != null;
      
      final isAuthPage = state.matchedLocation == '/login' || state.matchedLocation == '/register';

      bool isRemovedPortalRoute() {
        const removedPrefixes = [
          '/parent',
          '/deputy-head',
          '/secretary',
          '/security',
          '/library',
          '/infirmary',
          '/chef',
          '/labs/ict',
          '/labs/science',
          '/communications',
          '/inbox',
          '/messages',
          '/accountant/messages',
          '/shop/messages',
          '/teacher/messages',
          '/director/communication-announcements',
        ];
        const removedExactRoutes = ['/catalog', '/gate'];
        return removedExactRoutes.contains(state.matchedLocation) ||
            removedPrefixes.any((prefix) =>
                state.matchedLocation == prefix ||
                state.matchedLocation.startsWith('$prefix/'));
      }

      // 2. Priority 1: Check Registration
      if (!isRegistered) {
        // If not registered, they MUST stay on /register
        if (state.matchedLocation != '/register') {
          return '/register';
        }
        return null;
      }
      
      // 3. Priority 2: Check Authentication
      if (!isLoggedIn) {
        // If not logged in, allow auth pages, but redirect protected routes to /login
        if (isAuthPage) return null;
        return '/login';
      }

      final staffUser = currentUser;

      bool isDirectorLike() {
        return normalizeRoleToken(staffUser.role).contains(normalizeRoleToken(UserRole.director.name));
      }

      bool isRole(UserRole role) {
        return roleNameMatches(staffUser.role, role);
      }

      bool isAnyRole(List<UserRole> roles) {
        return roleNameIsOneOf(staffUser.role, roles);
      }

      if (isRemovedPortalRoute()) {
        return homeRouteForRoleName(staffUser.role);
      }
      
      // 4. Priority 3: Registered AND Logged In
      if (isLoggedIn && isAuthPage) {
        // Already logged in, no need to be on auth pages
        if (isRole(UserRole.teacher)) {
          return '/teacher';
        }
        if (isRole(UserRole.director) || isDirectorLike()) {
          return '/director/executive-dashboard';
        }
        if (isAnyRole(const [UserRole.headmaster, UserRole.headmistress])) {
          return '/dashboard';
        }
        if (isAnyRole(const [UserRole.deputyheadmaster, UserRole.deputyheadmistress])) {
          return '/dashboard';
        }
        if (isRole(UserRole.accountant)) {
          return '/accountant';
        }
        if (isRole(UserRole.shop)) {
          return '/shop/dashboard';
        }
        return '/dashboard';
      }

      // Teachers use the teacher portal dashboard instead of the general dashboard.
      if (isRole(UserRole.teacher) && state.matchedLocation == '/dashboard') {
        return '/teacher';
      }

      // Directors use the director portal instead of the general dashboard.
      if ((isRole(UserRole.director) || isDirectorLike()) && state.matchedLocation == '/dashboard') {
        return '/director/executive-dashboard';
      }

      // Headmasters/Headmistresses stay on the general dashboard.

      // Deputy heads stay on the general dashboard.

      // Shop staff use POS instead of the general dashboard.
      if (staffUser.role == UserRole.shop.name && state.matchedLocation == '/dashboard') {
        return '/shop/dashboard';
      }

      // Accountants use the accountant portal dashboard instead of the general dashboard.
      if (staffUser.role == UserRole.accountant.name && state.matchedLocation == '/dashboard') {
        return '/accountant';
      }

      if (isRemovedPortalRoute()) {
        return homeRouteForRoleName(staffUser.role);
      }

      // Director portal is restricted to directors (and admins for oversight).
      if (state.matchedLocation.startsWith('/director')) {
        final isAllowed = isRole(UserRole.director) || isDirectorLike() || isRole(UserRole.admin);
        if (!isAllowed) return '/dashboard';
      }

      // Headmaster portal is restricted to headmasters/headmistresses (and admins for oversight).
      if (state.matchedLocation.startsWith('/headmaster')) {
        final isAllowed = isAnyRole(const [UserRole.headmaster, UserRole.headmistress]) || isRole(UserRole.admin);
        if (!isAllowed) return '/dashboard';
      }

      // Accountant portal is restricted to accountants (and admins for oversight).
      if (state.matchedLocation.startsWith('/accountant')) {
        final isAllowed = staffUser.role == UserRole.accountant.name || staffUser.role == UserRole.admin.name;
        if (!isAllowed) return '/dashboard';
      }

      // Route guards: Shop (POS/Inventory) is restricted to shop staff (and admins).
      if ((state.matchedLocation == '/pos' ||
              state.matchedLocation == '/inventory' ||
              state.matchedLocation.startsWith('/shop/'))) {
        final isAllowed = staffUser.role == UserRole.shop.name || staffUser.role == UserRole.admin.name;
        if (!isAllowed) return '/dashboard';
      }

      // 6. Route guards: Alarms are admin-only
      if (state.matchedLocation == '/alarms') {
        final isAllowed =
            isRole(UserRole.admin) ||
            isAnyRole(const [
              UserRole.headmaster,
              UserRole.headmistress,
              UserRole.deputyheadmaster,
              UserRole.deputyheadmistress,
            ]);
        if (!isAllowed) return '/dashboard';
      }
      
      return null;
    },
    routes: [
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const InstitutionalRegistrationScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return MainLayout(child: child);
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/shop/dashboard',
            name: 'shop_dashboard',
            builder: (context, state) => const ShopDashboardScreen(),
          ),
          GoRoute(
            path: '/pos',
            name: 'shop_pos',
            builder: (context, state) => const ShopPosScreen(),
          ),
          GoRoute(
            path: '/inventory',
            name: 'shop_inventory',
            builder: (context, state) => const ShopInventoryScreen(),
          ),
          GoRoute(
            path: '/shop/suppliers',
            name: 'shop_suppliers',
            builder: (context, state) => const ShopSuppliersScreen(),
          ),
          GoRoute(
            path: '/shop/wallet',
            name: 'shop_wallet',
            builder: (context, state) => const ShopWalletScreen(),
          ),
          GoRoute(
            path: '/shop/reports',
            name: 'shop_reports',
            builder: (context, state) => const ShopReportsScreen(),
          ),
          GoRoute(
            path: '/accountant',
            name: 'accountant_portal',
            builder: (context, state) => const AccountantPortalScreen(),
          ),
          GoRoute(
            path: '/director',
            name: 'director_portal',
            builder: (context, state) => const DirectorSectionScreen(sectionId: 'executive-dashboard'),
            routes: [
              GoRoute(
                path: 'settings',
                name: 'director_settings',
                builder: (context, state) => const SettingsScreen(),
              ),
              GoRoute(
                path: ':sectionId',
                name: 'director_section',
                builder: (context, state) {
                  final sectionId = state.pathParameters['sectionId'] ?? '';
                  return DirectorSectionScreen(sectionId: sectionId);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/headmaster',
            name: 'headmaster_portal',
            builder: (context, state) => const HeadmasterPortalScreen(),
          ),
          GoRoute(
            path: '/accountant/profile',
            name: 'accountant_profile',
            builder: (context, state) => const AccountantProfileScreen(),
          ),
          GoRoute(
            path: '/profile',
            name: 'my_profile',
            builder: (context, state) => const StaffPortalProfileScreen(title: 'My Profile'),
          ),
          GoRoute(
            path: '/shop/profile',
            name: 'shop_profile',
            builder: (context, state) => const StaffPortalProfileScreen(title: 'Shop Profile'),
          ),
          GoRoute(
            path: '/students',
            name: 'students',
            builder: (context, state) => const StudentsScreen(),
            routes: [
              GoRoute(
                path: 'admission',
                name: 'admission',
                builder: (context, state) => const StudentAdmissionScreen(),
              ),
                GoRoute(
                  path: ':id',
                  name: 'student_profile',
                  builder: (context, state) {
                    final id = int.parse(state.pathParameters['id']!);
                    return StudentProfileScreen(studentId: id);
                  },
                ),
            ],
          ),
          GoRoute(
            path: '/teacher',
            name: 'teacher_dashboard',
            builder: (context, state) => const TeacherDashboardScreen(),
            routes: [
              GoRoute(
                path: 'classes',
                name: 'teacher_classes',
                builder: (context, state) => const TeacherClassesScreen(),
              ),
              GoRoute(
                path: 'profile',
                name: 'teacher_profile',
                builder: (context, state) => const TeacherProfileScreen(),
              ),
              GoRoute(
                path: 'reports',
                name: 'teacher_reports',
                builder: (context, state) => const TeacherReportsScreen(),
              ),
              GoRoute(
                path: 'lesson-notes',
                name: 'teacher_lesson_notes',
                builder: (context, state) => const TeacherLessonNotesScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    name: 'teacher_lesson_note_editor',
                    builder: (context, state) {
                      final id = int.parse(state.pathParameters['id']!);
                      return TeacherLessonNoteEditorScreen(noteId: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/my-students',
            name: 'my_students',
            builder: (context, state) => const TeacherStudentsScreen(),
          ),
          GoRoute(
            path: '/classes',
            name: 'classes',
            builder: (context, state) => const ClassesScreen(),
            routes: [
              GoRoute(
                path: 'promotion',
                name: 'promotion',
                builder: (context, state) => const PromotionScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/subjects',
            name: 'subjects',
            builder: (context, state) => const SubjectsScreen(),
          ),
          GoRoute(
            path: '/teacher-assignments',
            name: 'teacher_assignments',
            builder: (context, state) => const TeacherAssignmentsScreen(),
          ),
          GoRoute(
            path: '/id-cards',
            name: 'id_cards',
            builder: (context, state) => const IdCardsScreen(),
          ),
          GoRoute(
            path: '/alarms',
            // Keep this unique across the app to avoid GoRouter name collisions.
            name: 'admin_alarms',
            builder: (context, state) => const AlarmsScreen(),
          ),
          GoRoute(
            path: '/exams/bank',
            name: 'question_bank',
            builder: (context, state) => const ExamsToolsAccessGuard(
              title: 'Question Bank',
              child: QuestionBankScreen(),
            ),
          ),
          GoRoute(
            path: '/exams/generate',
            name: 'exam_generator',
            builder: (context, state) => const ExamsToolsAccessGuard(
              title: 'Exam Generator',
              child: ExamGeneratorScreen(),
            ),
          ),
          GoRoute(
            path: '/finance/fees',
            name: 'fees',
            builder: (context, state) => const FeesScreen(),
          ),
          GoRoute(
            path: '/finance/payments',
            name: 'finance_payments',
            builder: (context, state) => const FeePaymentScreen(),
          ),
          GoRoute(
            path: '/finance/payroll',
            name: 'payroll',
            builder: (context, state) => const PayrollScreen(),
          ),
          GoRoute(
            path: '/finance/expenses',
            name: 'expenses',
            builder: (context, state) => const ExpenseTrackerScreen(),
          ),
          GoRoute(
            path: '/finance/analytics',
            name: 'finance_analytics',
            builder: (context, state) => const FinanceAnalyticsScreen(),
          ),
          GoRoute(
            path: '/accountant/invoicing',
            name: 'accountant_invoicing',
            builder: (context, state) => const BillingInvoicingScreen(),
          ),
          GoRoute(
            path: '/accountant/arrears',
            name: 'accountant_arrears',
            builder: (context, state) => const ArrearsRemindersScreen(),
          ),
          GoRoute(
            path: '/accountant/banking',
            name: 'accountant_banking',
            builder: (context, state) => const BankingReconciliationScreen(),
          ),
          GoRoute(
            path: '/accountant/assets',
            name: 'accountant_assets',
            builder: (context, state) => const AssetsInventoryScreen(),
          ),
          GoRoute(
            path: '/accountant/security',
            name: 'accountant_security',
            builder: (context, state) => const SecurityComplianceScreen(),
          ),
          GoRoute(
            path: '/accountant/integrations',
            name: 'accountant_integrations',
            builder: (context, state) => const IntegrationsAutomationScreen(),
          ),
          GoRoute(
            path: '/admissions',
            name: 'admissions',
            builder: (context, state) => const AdmissionsHubScreen(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/attendance',
            name: 'attendance',
            builder: (context, state) {
              final currentUser = ref.read(currentUserProvider);
              final roleName = currentUser?.role ?? '';
              if (roleNameIsOneOf(
                roleName,
                const [
                  UserRole.admin,
                  UserRole.headmaster,
                  UserRole.headmistress,
                  UserRole.deputyheadmaster,
                  UserRole.deputyheadmistress,
                ],
              )) {
                return const StaffAttendanceScreen();
              }
              return const AttendanceScreen();
            },
          ),
          GoRoute(
            path: '/staff',
            name: 'staff',
            builder: (context, state) => const StaffScreen(),
            routes: [
              GoRoute(
                path: 'admission',
                name: 'staff_admission',
                builder: (context, state) => const StaffAdmissionScreen(),
              ),
              GoRoute(
                path: 'repair',
                name: 'staff_repair',
                builder: (context, state) => const StaffRepairScreen(),
              ),
              GoRoute(
                path: ':id',
                name: 'staff_profile',
                builder: (context, state) {
                  final raw = state.pathParameters['id'];
                  final id = int.tryParse(raw ?? '');
                  if (id == null) {
                    return const Scaffold(body: Center(child: Text('Invalid staff id')));
                  }
                  return StaffProfileScreen(staffId: id);
                },
              ),
            ],
          ),
          // Add more shell routes here
        ],
      ),
    ],
  );

  ref.listen<AsyncValue<bool>>(institutionRegisteredProvider, (previous, next) {
    router.refresh();
  });
  ref.listen(currentUserProvider, (previous, next) {
    router.refresh();
  });

  return router;
});
