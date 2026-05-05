import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/core/providers/database_provider.dart';
import 'package:ghanaclass_school_management/core/services/auth_service.dart';
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';
import 'package:ghanaclass_school_management/core/services/remote_auth_api.dart';
import 'package:ghanaclass_school_management/core/config/app_mode.dart';
import 'package:ghanaclass_school_management/core/config/backend_config.dart';

export 'database_provider.dart';

// Shared Preferences provider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(); // Initialized in main or via provider override
});

// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  final database = ref.watch(databaseProvider);

  // Base URL is loaded lazily inside AuthService via SharedPreferences.
  // We still create a RemoteAuthApi with a sensible default.
  final remote = RemoteAuthApi(baseUrl: BackendConfig.defaultApiBaseUrl);
  return AuthService(database, remote: remote);
});

class CurrentUserNotifier extends Notifier<User?> {
  @override
  User? build() => null;

  void setUser(User? user) => state = user;
}

class SessionTokenNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setToken(String? token) => state = token;
}

class LastUsedEmailNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setEmail(String? email) => state = email;
}

// Current user provider (nullable - null when not logged in)
final currentUserProvider = NotifierProvider<CurrentUserNotifier, User?>(
  CurrentUserNotifier.new,
);

// Current session token provider
final sessionTokenProvider = NotifierProvider<SessionTokenNotifier, String?>(
  SessionTokenNotifier.new,
);

// Last used email provider (for recall)
final lastUsedEmailProvider = NotifierProvider<LastUsedEmailNotifier, String?>(
  LastUsedEmailNotifier.new,
);

// Auth initialization provider
final authInitProvider = FutureProvider<void>((ref) async {
  final authService = ref.watch(authServiceProvider);
  final prefs = await SharedPreferences.getInstance();

  if (AppMode.forceServerModeOn) {
    await prefs.setBool('server_enabled', true);
    if ((prefs.getString('server_base_url') ?? '').trim().isEmpty) {
      await prefs.setString('server_base_url', BackendConfig.defaultApiBaseUrl);
    }
    if ((prefs.getString('server_school_schema') ?? '').trim().isEmpty) {
      await prefs.setString('server_school_schema', BackendConfig.defaultSchoolSchema);
    }
  }

  if (AppMode.forceServerModeOff) {
    await prefs.setBool('server_enabled', false);
    await prefs.remove('server_token');
    await prefs.remove('server_school_id');
    await prefs.remove('server_school_schema');
    await prefs.remove('server_user_id');
    await prefs.remove('server_user_email');
    await prefs.remove('server_user_full_name');
    await prefs.remove('server_user_role');
  }

  final serverEnabled = AppMode.resolveServerEnabled(prefs.getBool('server_enabled'));
  
  // Recall last used email
  final lastEmail = prefs.getString('last_used_email');
  if (lastEmail != null) {
    ref.read(lastUsedEmailProvider.notifier).setEmail(lastEmail);
  }

  // Recall session
  final token = prefs.getString('session_token');
  if (token != null) {
    // In server mode, validateSession reads from prefs + JWT exp check.
    // In local mode, it checks SQLite sessions.
    final user = await authService.validateSession(token);
    if (user != null) {
      ref.read(sessionTokenProvider.notifier).setToken(token);
      ref.read(currentUserProvider.notifier).setUser(user);
    } else {
      // Invalid or expired token
      await prefs.remove('session_token');
      if (serverEnabled) {
        // Also clear server token so we don't think we're still logged in.
        await prefs.remove('server_token');
        await prefs.remove('server_school_id');
      }
    }
  }
});

// Institution registered check provider
final institutionRegisteredProvider = FutureProvider<bool>((ref) async {
  final authService = ref.watch(authServiceProvider);
  final prefs = await SharedPreferences.getInstance();

  if (AppMode.forceServerModeOn) {
    await prefs.setBool('server_enabled', true);
    if ((prefs.getString('server_base_url') ?? '').trim().isEmpty) {
      await prefs.setString('server_base_url', BackendConfig.defaultApiBaseUrl);
    }
    if ((prefs.getString('server_school_schema') ?? '').trim().isEmpty) {
      await prefs.setString('server_school_schema', BackendConfig.defaultSchoolSchema);
    }
  }

  // In Server Mode, registration is driven by server token / cached flag.
  if (AppMode.forceServerModeOff) {
    await prefs.setBool('server_enabled', false);
  }

  final serverEnabled = AppMode.resolveServerEnabled(prefs.getBool('server_enabled'));
  if (serverEnabled) {
    final token = prefs.getString('server_token');
    final isRegistered = (prefs.getBool('institution_registered') ?? false) ||
        (token != null && token.trim().isNotEmpty);
    await prefs.setBool('institution_registered', isRegistered);
    return isRegistered;
  }
  
  // 1. Check SQLite (Source of Truth)
  final isRegisteredDb = await authService.isInstitutionRegistered();
  
  // 2. Sync SharedPreferences to match SQLite
  if (isRegisteredDb) {
    await prefs.setBool('institution_registered', true);
  } else {
    // If not in DB, it definitely shouldn't be in Prefs
    await prefs.setBool('institution_registered', false);
  }
  
  return isRegisteredDb;
});

// Institutional identity provider
final institutionalIdentityProvider = FutureProvider<InstitutionalIdentityData?>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.getInstitutionalIdentity();
});

// Login provider
final loginProvider = FutureProvider.family<Map<String, dynamic>, LoginCredentials>(
  (ref, credentials) async {
    final authService = ref.watch(authServiceProvider);
    return await authService.login(
      email: credentials.email,
      password: credentials.password,
      role: credentials.role,
    );
  },
);

// Logout provider
final logoutProvider = FutureProvider.autoDispose<void>((ref) async {
  final authService = ref.watch(authServiceProvider);
  final token = ref.read(sessionTokenProvider);
  
  if (token != null) {
    await authService.logout(token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_token');
    ref.read(sessionTokenProvider.notifier).setToken(null);
    ref.read(currentUserProvider.notifier).setUser(null);
  }
});

// Helper class for login credentials
class LoginCredentials {
  final String email;
  final String password;
  final UserRole role;

  LoginCredentials({
    required this.email,
    required this.password,
    required this.role,
  });
}

// Helper class for registration data
class RegistrationData {
  final String schoolName;
  final String headOfInstitution;
  final String officialEmail;
  final String masterPassword;
  final String? address;
  final String? motto;
  final String? logoPath;

  RegistrationData({
    required this.schoolName,
    required this.headOfInstitution,
    required this.officialEmail,
    required this.masterPassword,
    this.address,
    this.motto,
    this.logoPath,
  });
}
