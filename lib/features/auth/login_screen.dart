import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/core/providers/sync_providers.dart';
import 'package:ghanaclass_school_management/core/config/backend_config.dart';
import 'package:ghanaclass_school_management/core/router/role_routes.dart';
import 'package:ghanaclass_school_management/core/services/app_error_reporter.dart';
import 'package:ghanaclass_school_management/core/config/app_mode.dart';
import 'package:ghanaclass_school_management/shared/widgets/offline_connectivity_listener.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // Network/server logins should fail fast; local SQLite logins may take longer
  // on first open after upgrades/seeding.
  static const Duration _remoteLoginTimeout = Duration(seconds: 20);
  static const Duration _localLoginTimeout = Duration(minutes: 2);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  ProviderSubscription<User?>? _currentUserSubscription;
  
  UserRole _selectedRole = UserRole.admin;
  bool _isLoading = false;
  bool _obscureLoginPassword = true;

  String _routeForRole(String role) => homeRouteForRoleName(role);

  bool _looksLikeLocalServerUrl(String baseUrl) {
    final normalized = baseUrl.trim().toLowerCase();
    return normalized.startsWith('http://localhost') ||
        normalized.startsWith('https://localhost') ||
        normalized.startsWith('http://127.0.0.1') ||
        normalized.startsWith('https://127.0.0.1');
  }

  Future<String> _friendlyLoginError(Object error) async {
    if (AppMode.forceServerModeOff && !AppMode.forceServerModeOn) {
      // In offline/local builds we shouldn't instruct users to connect to internet.
      final raw = error.toString();
      return raw.replaceFirst('Exception: ', '').trim();
    }

    final prefs = await SharedPreferences.getInstance();
    final configuredBaseUrl =
        prefs.getString('server_base_url') ?? BackendConfig.defaultApiBaseUrl;
    final usingLocalServer = _looksLikeLocalServerUrl(configuredBaseUrl);

    if (error is SocketException || error is TimeoutException) {
      if (usingLocalServer) {
        return 'Local backend is not reachable at $configuredBaseUrl. Start the backend server and try again.';
      }
      return 'You are offline. Please connect to an internet source and try again.';
    }

    final raw = error.toString();
    final msg = raw.replaceFirst('Exception: ', '').trim();
    final normalized = msg.toLowerCase();

    if (normalized.contains('failed host lookup') ||
        normalized.contains('connection refused') ||
        normalized.contains('network is unreachable') ||
        normalized.contains('no address associated with hostname')) {
      if (usingLocalServer) {
        return 'Local backend is not reachable at $configuredBaseUrl. Start the backend server and try again.';
      }
      return 'You are offline. Please connect to an internet source and try again.';
    }

    if (normalized.contains('timed out') || normalized.contains('timeout')) {
      if (usingLocalServer) {
        return 'Local backend at $configuredBaseUrl did not respond in time. Check that the backend is running and try again.';
      }
      return 'Connection timed out. Please check your internet and try again.';
    }

    return msg;
  }

  bool _isExpectedAuthErrorMessage(String message) {
    final m = message.toLowerCase();
    return m.contains('invalid email or password') ||
        m.contains('invalid parent email or password') ||
        m.contains('you do not have access to this portal') ||
        m.contains('account has been deactivated') ||
        m.contains('you are offline') ||
        m.contains('connection timed out') ||
        m.contains('password recovery') ||
        m.contains('institution not registered') ||
        m.contains('invalid master password') ||
        m.contains('no account found');
  }

  @override
  void initState() {
    super.initState();

    // Safety net: if auth state updates while we're on /login,
    // navigate to the correct portal immediately.
    _currentUserSubscription = ref.listenManual<User?>(currentUserProvider, (previous, next) {
      if (previous == null && next != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          context.go(_routeForRole(next.role));
        });
      }
    });

    // Pre-fill email if recalled
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final recalledEmail = ref.read(lastUsedEmailProvider);
      if (recalledEmail != null) {
        _emailController.text = recalledEmail;
      }
    });

    // If we just completed registration, show a message on the login screen.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final justRegistered = prefs.getBool('just_registered') ?? false;
      if (!justRegistered) return;
      await prefs.remove('just_registered');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration successful. Log in as Administrator with the email and password you just set.'),
          backgroundColor: Colors.green,
        ),
      );
    });
  }

  @override
  void dispose() {
    _currentUserSubscription?.close();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;

    final formState = _formKey.currentState;
    if (formState == null) return;
    if (!formState.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // If Server Mode is enabled, avoid waiting on a network request when offline.
      final isServerEnabled = await ref.read(serverEnabledProvider.future);
      final isOnline = ref.read(isOnlineProvider);
      if (isServerEnabled && !isOnline) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You are offline. Please connect to an internet source and try again.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final authService = ref.read(authServiceProvider);

        final timeout = isServerEnabled
          ? _remoteLoginTimeout
          : _localLoginTimeout;

      final result = await authService
          .login(
            email: email,
            password: password,
            role: _selectedRole,
          )
          .timeout(timeout);

      final token = result['token'];
      final user = result['user'];
      if (token is! String || token.trim().isEmpty || user is! User) {
        throw Exception('Login failed. Please try again.');
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_used_email', email);
      await prefs.setString('session_token', token);

      await prefs.remove('parent_session_parent_id');

      ref.read(lastUsedEmailProvider.notifier).setEmail(email);
      ref.read(sessionTokenProvider.notifier).setToken(token);
      ref.read(currentUserProvider.notifier).setUser(user);

      // Run slow database maintenance after login (non-blocking).
      // This prevents first-login hangs on devices with large legacy DBs.
      unawaited(ref.read(databaseProvider).runDeferredMaintenance());

      if (mounted) {
        GoRouter.of(context).refresh();
      }

      // Sanity check: if something external cleared state, fail loudly.
      final appliedUser = ref.read(currentUserProvider);
      if (appliedUser == null) {
        throw Exception('Login state could not be applied. Please try again.');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome, ${user.fullName}!'),
            backgroundColor: Colors.green,
          ),
        );

        context.go(homeRouteForRoleName(user.role));
      }
    } catch (e, st) {
      final message = await _friendlyLoginError(e);

      // Only report unexpected errors to the debug overlay.
      if (!_isExpectedAuthErrorMessage(message)) {
        reportUnhandledError(e, st);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showPasswordRecoveryDialog() async {
    final emailController = TextEditingController(text: _emailController.text.trim());
    final masterController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmController = TextEditingController();

    var obscureMaster = true;
    var obscureNew = true;
    var obscureConfirm = true;

    try {
      final submitted = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setLocalState) {
              return AlertDialog(
                title: const Text('Password Recovery'),
                content: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'To reset a password offline, enter your email and the institution master password.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'User Email'),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: masterController,
                        decoration: InputDecoration(
                          labelText: 'Institution Master Password',
                          suffixIcon: IconButton(
                            icon: Icon(obscureMaster ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setLocalState(() => obscureMaster = !obscureMaster),
                          ),
                        ),
                        obscureText: obscureMaster,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: newPassController,
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
                  ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('RESET')),
                ],
              );
            },
          );
        },
      );

      if (submitted != true || !mounted) return;

      final email = emailController.text.trim();
      final master = masterController.text;
      final newPass = newPassController.text;
      final confirm = confirmController.text;

      if (newPass.trim() != confirm.trim()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match'), backgroundColor: Colors.red),
        );
        return;
      }

      await ref.read(authServiceProvider).recoverPasswordWithMasterPassword(
            email: email,
            masterPassword: master,
            newPassword: newPass,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset successfully.'), backgroundColor: Colors.green),
      );
    } catch (e, st) {
      final message = await _friendlyLoginError(e);
      if (!_isExpectedAuthErrorMessage(message)) {
        reportUnhandledError(e, st);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } finally {
      emailController.dispose();
      masterController.dispose();
      newPassController.dispose();
      confirmController.dispose();
    }
  }

  static const _bgTop = Color(0xFF0B1324);
  static const _bgBottom = Color(0xFF060B16);
  static const _cardRadius = 32.0;
  static const _fieldFill = Color(0xFFF7F9FC);
  static const _fieldBorder = Color(0xFFD9E2EF);
  static const _labelColor = Color(0xFF6E86B6);
  static const _hintColor = Color(0xFF9AA7BD);
  static const _primaryButton = Color(0xFF0B1324);
  static const _linkOrange = Color(0xFFF59E0B);

  InputDecoration _fieldDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: _hintColor,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _fieldBorder, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _fieldBorder, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF8AA7FF), width: 1.2),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: _labelColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.3,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final identityAsync = ref.watch(institutionalIdentityProvider);

    final brandTitle = identityAsync.maybeWhen(
      data: (identity) => (identity?.schoolName.trim().isNotEmpty == true)
          ? identity!.schoolName.trim()
          : 'School Management System',
      orElse: () => 'School Management System',
    );

    return Scaffold(
      body: Stack(
        children: [
          const OfflineConnectivityListener(serverModeOnly: true),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_bgTop, _bgBottom],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(_cardRadius),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x26000000),
                                  blurRadius: 28,
                                  offset: Offset(0, 16),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(44, 36, 44, 26),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Center(
                                      child: Container(
                                        width: 68,
                                        height: 68,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: const Color(0xFFE7ECF5), width: 1),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.network(
                                            'https://pub-141831e61e69445289222976a15b6fb3.r2.dev/Image_to_url_V2/OmniWeave-Logo-imagetourl.cloud-1768845152819-xd0lbd.jpeg',
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    Text(
                                      brandTitle,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.2,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'INSTITUTIONAL MANAGEMENT SYSTEM',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 2.2,
                                        color: Color(0xFFA6B1C2),
                                      ),
                                    ),
                                    const SizedBox(height: 30),
                                    _fieldLabel('USER EMAIL'),
                                    TextFormField(
                                      controller: _emailController,
                                      decoration: _fieldDecoration(hintText: 'Email Address'),
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Please enter your email';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 18),
                                    _fieldLabel('SECURE PIN/PASS'),
                                    TextFormField(
                                      controller: _passwordController,
                                      decoration: _fieldDecoration(hintText: '••••••••').copyWith(
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscureLoginPassword ? Icons.visibility_off : Icons.visibility,
                                            color: const Color(0xFF1F2A44),
                                          ),
                                          onPressed: () => setState(
                                            () => _obscureLoginPassword = !_obscureLoginPassword,
                                          ),
                                        ),
                                      ),
                                      obscureText: _obscureLoginPassword,
                                      textInputAction: TextInputAction.next,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter your password';
                                        }
                                        return null;
                                      },
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: _isLoading ? null : _showPasswordRecoveryDialog,
                                        child: const Text(
                                          'Forgot password?',
                                          style: TextStyle(fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    _fieldLabel('PORTAL ACCESS ROLE'),
                                    DropdownButtonFormField<UserRole>(
                                      initialValue: _selectedRole,
                                      icon: const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: Color(0xFF1F2A44),
                                      ),
                                      decoration: _fieldDecoration(hintText: ''),
                                      isExpanded: true,
                                      items: [
                                        // Leadership group
                                        const DropdownMenuItem<UserRole>(
                                          enabled: false,
                                          child: Text(
                                            'LEADERSHIP PORTALS',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        ...[UserRole.admin, UserRole.director, UserRole.headmaster, UserRole.headmistress]
                                            .map(
                                              (role) => DropdownMenuItem<UserRole>(
                                                value: role,
                                                child: Text(
                                                  role.displayName.toUpperCase(),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 0.5,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        // Supported staff portals group
                                        const DropdownMenuItem<UserRole>(
                                          enabled: false,
                                          child: Text(
                                            'STAFF PORTALS',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        ...[UserRole.teacher, UserRole.accountant, UserRole.shop]
                                            .map(
                                              (role) => DropdownMenuItem<UserRole>(
                                                value: role,
                                                child: Text(
                                                  role.displayName.toUpperCase(),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 0.5,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ),
                                            ),
                                      ],
                                      onChanged: (role) {
                                        if (role == null) return;
                                        setState(() => _selectedRole = role);
                                      },
                                    ),
                                    const SizedBox(height: 22),
                                    Container(
                                      height: 56,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x33000000),
                                            blurRadius: 18,
                                            offset: Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _handleLogin,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _primaryButton,
                                          disabledBackgroundColor: _primaryButton.withValues(alpha: 0.65),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                ),
                                              )
                                            : const Text(
                                                'ENTER PORTAL',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 0.8,
                                                  color: Colors.white,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    const Divider(height: 1, color: Color(0xFFE9EEF6)),
                                    const SizedBox(height: 14),
                                    Column(
                                      children: [
                                        const Text(
                                          'Registering a new school?',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        InkWell(
                                          onTap: () => context.push('/register'),
                                          child: const Text(
                                            'GET STARTED HERE',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.8,
                                              color: _linkOrange,
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),
                                    GestureDetector(
                                      onLongPress: () => _showResetConfirmation(context),
                                      child: Column(
                                        children: [
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                width: 18,
                                                height: 18,
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(6),
                                                  image: const DecorationImage(
                                                    image: NetworkImage(
                                                      'https://pub-141831e61e69445289222976a15b6fb3.r2.dev/Image_to_url_V2/OmniWeave-Logo-imagetourl.cloud-1768845152819-xd0lbd.jpeg',
                                                    ),
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const Text(
                                                'POWERED BY\nOMNIWEAVE SOFTWARES',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  height: 1.1,
                                                  letterSpacing: 1.2,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFFB5BFCE),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Troubleshoot Utility'),
        content: const Text(
          'If you are having trouble logging in or the system says "Already Registered" incorrectly, '
          'use this button to reset the authentication state and start setup fresh.\n\n'
          'WARNING: This will clear institutional identity and admin accounts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              setState(() => _isLoading = true);
              Timer? watchdog;
              try {
                watchdog = Timer(const Duration(seconds: 45), () {
                  if (!mounted) return;
                  if (!_isLoading) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Still resetting... If it stays stuck, close the app completely and try again. '
                        'Also ensure no other GhanaClass window is running.',
                      ),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 8),
                    ),
                  );
                });

                await ref.read(authServiceProvider).performEmergencyReset();
                ref.invalidate(databaseProvider);
                ref.invalidate(authServiceProvider);
                ref.read(currentUserProvider.notifier).setUser(null);
                ref.read(sessionTokenProvider.notifier).setToken(null);
                ref.read(lastUsedEmailProvider.notifier).setEmail(null);
                ref.invalidate(institutionRegisteredProvider);
                ref.invalidate(institutionalIdentityProvider);
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('System Reset. Refreshing...')),
                );
                // Force a hard reload of the app state
                this.context.go('/register');
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text('Reset Failed: $e'), backgroundColor: Colors.red),
                );
              } finally {
                watchdog?.cancel();
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );
  }
}

