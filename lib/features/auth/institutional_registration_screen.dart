import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InstitutionalRegistrationScreen extends ConsumerStatefulWidget {
  const InstitutionalRegistrationScreen({super.key});

  @override
  ConsumerState<InstitutionalRegistrationScreen> createState() =>
      _InstitutionalRegistrationScreenState();
}

class _InstitutionalRegistrationScreenState
    extends ConsumerState<InstitutionalRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _schoolNameController = TextEditingController();
  final _headOfInstitutionController = TextEditingController();
  final _emailController = TextEditingController();
  final _masterPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  static const Duration _registrationTimeout = Duration(minutes: 2);

  static const _cardMaxWidth = 520.0;
  static const _cardRadius = 44.0;
  static const _fieldRadius = 12.0;

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.4,
              color: const Color(0xFF7B8AA6),
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFF9AA7BC),
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFE),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: const BorderSide(color: Color(0xFFE3EAF6), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: const BorderSide(color: Color(0xFF7B8AA6), width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
    );
  }

  @override
  void dispose() {
    _schoolNameController.dispose();
    _headOfInstitutionController.dispose();
    _emailController.dispose();
    _masterPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);

      // If already registered, we treat this as a re-setup (update identity + reset admin password).
      // This avoids a confusing hard failure and fixes cases where the admin password got out of sync.
      final wasRegistered = await authService
          .isInstitutionRegistered()
          .timeout(_registrationTimeout);
      
      await authService
          .registerInstitution(
            schoolName: _schoolNameController.text.trim(),
            headOfInstitution: _headOfInstitutionController.text.trim(),
            officialEmail: _emailController.text.trim(),
            masterPassword: _masterPasswordController.text,
            address: null,
            motto: null,
            logoPath: null,
          )
          .timeout(_registrationTimeout);

      // Ensure routing/providers see the updated registration state immediately.
      ref.invalidate(institutionRegisteredProvider);
      ref.invalidate(institutionalIdentityProvider);
      
      if (mounted) {
        if (wasRegistered) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('last_used_email', _emailController.text.trim().toLowerCase());
          if (!mounted) return;
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Registration Updated'),
              content: const Text(
                'This device already had an institution registered. The school profile was updated and the Administrator password was reset for the email you provided.\n\n'
                'You can now log in using the same email + password.\n\n'
                'If you intended to register a completely different school, use Settings → Danger Zone → FACTORY RESET (or the hidden reset on the Login screen) and then register again.',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/login');
                  },
                  child: const Text('Go to Login'),
                ),
              ],
            ),
          );
        } else {
          final email = _emailController.text.trim().toLowerCase();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('just_registered', true);
          await prefs.setString('last_used_email', email);
          if (!mounted) return;
          context.go('/login');
        }
      }
    } catch (e) {
      final message = e is TimeoutException
          ? 'Registration timed out. If this keeps happening, run Factory Reset and try again.'
          : 'Registration failed: $e';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF060D1D),
                  Color(0xFF0B1A2D),
                ],
              ),
            ),
            child: const SizedBox.expand(),
          ),
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.35),
                radius: 1.2,
                colors: [
                  Color(0x332B3C55),
                  Color(0x00000000),
                ],
              ),
            ),
            child: const SizedBox.expand(),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _cardMaxWidth),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(_cardRadius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 60,
                          offset: const Offset(0, 28),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(44, 40, 44, 30),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Column(
                                children: [
                                  Container(
                                    width: 62,
                                    height: 62,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 16,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.all(10),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.network(
                                        'https://pub-141831e61e69445289222976a15b6fb3.r2.dev/Image_to_url_V2/OmniWeave-Logo-imagetourl.cloud-1768845152819-xd0lbd.jpeg',
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: const Color(0xFFF3F6FC),
                                            alignment: Alignment.center,
                                            child: const Icon(Icons.school, size: 28, color: Color(0xFF7B8AA6)),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    brandTitle,
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.2,
                                          color: const Color(0xFF0B1220),
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'INSTITUTIONAL MANAGEMENT SYSTEM',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          letterSpacing: 2.6,
                                          color: const Color(0xFF93A0B5),
                                          fontWeight: FontWeight.w700,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 30),

                          _buildLabel('Institution Name'),
                          TextFormField(
                            controller: _schoolNameController,
                            decoration: _inputDecoration(
                              hintText: 'e.g. Morning Star Academy',
                            ),
                            style: const TextStyle(
                              color: Color(0xFF0B1220),
                              fontWeight: FontWeight.w600,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Institution name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                          _buildLabel('Head of Institution'),
                          TextFormField(
                            controller: _headOfInstitutionController,
                            decoration: _inputDecoration(hintText: 'Full Name'),
                            style: const TextStyle(
                              color: Color(0xFF0B1220),
                              fontWeight: FontWeight.w600,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Head of institution is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          _buildLabel('Official Email'),
                          TextFormField(
                            controller: _emailController,
                            decoration: _inputDecoration(hintText: 'admin@school.com'),
                            style: const TextStyle(
                              color: Color(0xFF0B1220),
                              fontWeight: FontWeight.w600,
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Official email is required';
                              }
                              if (!value.contains('@')) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          _buildLabel('Access Password'),
                          TextFormField(
                            controller: _masterPasswordController,
                            decoration: _inputDecoration(hintText: '••••••••').copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                                  size: 18,
                                  color: const Color(0xFF93A0B5),
                                ),
                                onPressed: () {
                                  setState(() => _obscurePassword = !_obscurePassword);
                                },
                              ),
                            ),
                            obscureText: _obscurePassword,
                            style: const TextStyle(
                              color: Color(0xFF0B1220),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Access password is required';
                              }
                              if (value.length < 8) {
                                return 'Password must be at least 8 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Submit Button
                          SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleRegistration,
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFF0B1220),
                                      Color(0xFF08101D),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.22),
                                      blurRadius: 28,
                                      offset: const Offset(0, 16),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'ACTIVATE ACCOUNT',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.3,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          Center(
                            child: TextButton(
                              onPressed: () => context.go('/login'),
                              child: Text(
                                'BACK TO PORTAL',
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      letterSpacing: 1.2,
                                      color: const Color(0xFF6B7A92),
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          Center(
                            child: Text(
                              'POWERED BY\nOMNIWEAVE SOFTWARES',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: const Color(0xFF9AA7BC),
                                    letterSpacing: 1.0,
                                    fontWeight: FontWeight.w600,
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
          ),
      ),
        ],
      ),
    );
  }

}
