import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/core/utils/password_hasher.dart';
import 'package:ghanaclass_school_management/core/utils/token_generator.dart';
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';
import 'package:ghanaclass_school_management/core/router/role_routes.dart';
import 'package:ghanaclass_school_management/core/services/remote_auth_api.dart';
import 'package:ghanaclass_school_management/core/config/app_mode.dart';
import 'package:ghanaclass_school_management/core/config/backend_config.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AuthService {
  final AppDatabase _database;
  RemoteAuthApi? _remote;

  AuthService(this._database, {RemoteAuthApi? remote}) : _remote = remote;

  Future<void> _ensureDbReady({Duration timeout = const Duration(minutes: 2)}) async {
    try {
      await _database
          .customSelect('SELECT 1', readsFrom: const {})
          .getSingle()
          .timeout(timeout);
    } on TimeoutException {
      throw Exception(
        'Database is taking too long to open. '
        'Please close other running instances of the app and try again.',
      );
    }
  }

  static const _prefServerEnabled = 'server_enabled';
  static const _prefServerBaseUrl = 'server_base_url';
  static const _prefServerToken = 'server_token';
  static const _prefServerSchoolId = 'server_school_id';
  static const _prefServerSchoolSchema = 'server_school_schema';

  static const _prefInstitutionRegistered = 'institution_registered';
  static const _prefSchoolName = 'school_name';

  // Local branding overrides (used for Server Mode too).
  static const _prefBrandHead = 'brand_head_of_institution';
  static const _prefBrandEmail = 'brand_official_email';
  static const _prefBrandAddress = 'brand_address';
  static const _prefBrandPhone = 'brand_phone_number';
  static const _prefBrandMotto = 'brand_motto';
  static const _prefBrandLogoPath = 'brand_logo_path';

  static const _prefServerUserId = 'server_user_id';
  static const _prefServerUserEmail = 'server_user_email';
  static const _prefServerUserFullName = 'server_user_full_name';
  static const _prefServerUserRole = 'server_user_role';

  Future<File> _brandingLogoFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'ghanaclass_brand_logo.bin'));
  }

  String? _normalizeOptionalText(String? v) {
    final trimmed = v?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  String _normalizeRoleName(String role) {
    final normalized = role.trim().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (normalized.isEmpty) return role.trim();

    // Common variants/synonyms that should map into our canonical roles.
    // Keep this conservative to avoid granting the wrong portal.
    if (normalized.contains('director')) return UserRole.director.name;
    if (normalized.contains('headmistress')) return UserRole.headmistress.name;
    if (normalized.contains('headmaster')) return UserRole.headmaster.name;
    if (normalized.contains('deputyheadmistress')) return UserRole.deputyheadmistress.name;
    if (normalized.contains('deputyheadmaster')) return UserRole.deputyheadmaster.name;

    for (final r in UserRole.values) {
      final candidate = r.name.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
      if (normalized == candidate) return r.name;
    }

    return role.trim();
  }

  String _generateSchoolCode(String schoolName) {
    final normalized = schoolName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '')
        .replaceAll(RegExp(r'\s+'), '');

    final base = normalized.isEmpty ? 'school' : normalized;
    final short = base.length <= 10 ? base : base.substring(0, 10);
    final suffix = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    return '$short$suffix';
  }

  Future<bool> _serverEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return AppMode.resolveServerEnabled(prefs.getBool(_prefServerEnabled));
  }

  Future<RemoteAuthApi?> _remoteApi() async {
    if (_remote == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final configuredBaseUrl = prefs.getString(_prefServerBaseUrl);
    final baseUrl = (configuredBaseUrl == null || configuredBaseUrl.trim().isEmpty)
      ? BackendConfig.defaultApiBaseUrl
        : configuredBaseUrl.trim();

    // Recreate only if baseUrl changed.
    if (_remote!.baseUrl != baseUrl) {
      _remote = RemoteAuthApi(baseUrl: baseUrl);
    }

    return _remote;
  }

  Future<String?> _serverToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefServerToken);
  }

  Future<void> _setServerToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefServerToken, token);
  }

  Future<void> _setServerSchoolSchema(String schema) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefServerSchoolSchema, schema);
  }

  Future<void> _setServerSchoolId(String schoolId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefServerSchoolId, schoolId);
  }

  int? _decodeJwtExpSeconds(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payloadB64 = parts[1];

      String pad(String s) {
        final mod = s.length % 4;
        if (mod == 0) return s;
        return s + '=' * (4 - mod);
      }

      final normalized = pad(payloadB64.replaceAll('-', '+').replaceAll('_', '/'));
      final jsonStr = utf8.decode(base64.decode(normalized));
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) return null;
      final exp = decoded['exp'];
      if (exp is int) return exp;
      if (exp is String) return int.tryParse(exp);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<User?> _serverUserFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_prefServerUserEmail);
    final fullName = prefs.getString(_prefServerUserFullName);
    final role = prefs.getString(_prefServerUserRole);
    final remoteId = prefs.getString(_prefServerUserId);

    if (email == null || email.trim().isEmpty) return null;
    if (fullName == null || fullName.trim().isEmpty) return null;
    if (role == null || role.trim().isEmpty) return null;

    final now = DateTime.now();
    return User(
      id: 1,
      fullName: fullName,
      email: email,
      passwordHash: '',
      role: role,
      photoPath: null,
      phoneNumber: null,
      isActive: true,
      createdAt: now,
      updatedAt: now,
      lastLoginAt: null,
      remoteId: remoteId,
      lastSyncedAt: null,
      isDirty: false,
    );
  }

  Future<void> _storeServerUser({
    required String id,
    required String email,
    required String fullName,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefServerUserId, id);
    await prefs.setString(_prefServerUserEmail, email);
    await prefs.setString(_prefServerUserFullName, fullName);
    await prefs.setString(_prefServerUserRole, role);
  }

  /// Check if institutional identity exists AND an admin user is created
  Future<bool> isInstitutionRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    if (await _serverEnabled()) {
      final token = prefs.getString(_prefServerToken);
      return (prefs.getBool(_prefInstitutionRegistered) ?? false) ||
          (token != null && token.trim().isNotEmpty);
    }

    await _ensureDbReady();

    final adminCount = await _database.getAdminCount().timeout(
          const Duration(seconds: 45),
          onTimeout: () => throw Exception(
            'Database operation timed out (check admin count). '
            'Try Factory Reset if this keeps happening.',
          ),
        );
    return adminCount > 0;
  }

  Future<InstitutionalIdentityData?> getInstitutionalIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    if (await _serverEnabled()) {
      final schoolName = prefs.getString(_prefSchoolName);
      if (schoolName == null || schoolName.trim().isEmpty) return null;

      final brandEmail = _normalizeOptionalText(prefs.getString(_prefBrandEmail));
      final brandHead = _normalizeOptionalText(prefs.getString(_prefBrandHead));
      final brandAddress = _normalizeOptionalText(prefs.getString(_prefBrandAddress));
      final brandPhone = _normalizeOptionalText(prefs.getString(_prefBrandPhone));
      final brandMotto = _normalizeOptionalText(prefs.getString(_prefBrandMotto));

      final officialEmail = brandEmail ?? (prefs.getString(_prefServerUserEmail) ?? '');
      final head = brandHead ?? (prefs.getString(_prefServerUserFullName) ?? 'Administrator');

      final logoPath = _normalizeOptionalText(prefs.getString(_prefBrandLogoPath));
      Uint8List? logoBytes;
      if (logoPath != null) {
        try {
          final f = File(logoPath);
          if (await f.exists()) {
            final b = await f.readAsBytes();
            if (b.isNotEmpty) logoBytes = b;
          }
        } catch (_) {
          // Best-effort; ignore logo read failures in server mode.
        }
      }
      final now = DateTime.now();

      return InstitutionalIdentityData(
        id: 1,
        schoolName: schoolName,
        headOfInstitution: head,
        officialEmail: officialEmail,
        address: brandAddress,
        motto: brandMotto,
        logoPath: logoPath,
        logoBytes: logoBytes,
        phoneNumber: brandPhone,
        masterPasswordHash: '',
        createdAt: now,
        updatedAt: now,
        remoteId: null,
        lastSyncedAt: null,
        isDirty: false,
      );
    }

    return await _database.getInstitutionalIdentity();
  }

  Future<void> updateInstitutionalIdentity(InstitutionalIdentityCompanion entry) async {
    final prefs = await SharedPreferences.getInstance();

    if (await _serverEnabled()) {
      if (entry.schoolName case Value<String>(:final value)) {
        await prefs.setString(_prefSchoolName, value);
      }

      if (entry.headOfInstitution case Value<String>(:final value)) {
        await prefs.setString(_prefBrandHead, value);
      }

      if (entry.officialEmail case Value<String>(:final value)) {
        await prefs.setString(_prefBrandEmail, value);
      }

      if (entry.address case Value<String?>(:final value)) {
        final normalized = _normalizeOptionalText(value);
        if (normalized == null) {
          await prefs.remove(_prefBrandAddress);
        } else {
          await prefs.setString(_prefBrandAddress, normalized);
        }
      }

      if (entry.phoneNumber case Value<String?>(:final value)) {
        final normalized = _normalizeOptionalText(value);
        if (normalized == null) {
          await prefs.remove(_prefBrandPhone);
        } else {
          await prefs.setString(_prefBrandPhone, normalized);
        }
      }

      if (entry.motto case Value<String?>(:final value)) {
        final normalized = _normalizeOptionalText(value);
        if (normalized == null) {
          await prefs.remove(_prefBrandMotto);
        } else {
          await prefs.setString(_prefBrandMotto, normalized);
        }
      }

      // Handle logo updates in server mode by storing a local file path.
      if (entry.logoBytes case Value<Uint8List?>(:final value)) {
        final file = await _brandingLogoFile();
        if (value == null || value.isEmpty) {
          try {
            if (await file.exists()) {
              await file.delete();
            }
          } catch (_) {
            // Best-effort cleanup.
          }
          await prefs.remove(_prefBrandLogoPath);
        } else {
          await file.writeAsBytes(value, flush: true);
          await prefs.setString(_prefBrandLogoPath, file.path);
        }
      }

      // Keep legacy behavior: ensure school name is available to other parts.
      if (entry.schoolName case Value<String>(:final value)) {
        await prefs.setString(_prefSchoolName, value);
      }

      return;
    }

    await _database.upsertInstitutionalIdentity(entry);

    // Sync school name to prefs if it changed
    if (entry.schoolName case Value<String>(:final value)) {
      await prefs.setString(_prefSchoolName, value);
    }
  }

  /// Register institutional identity (first-time setup)
  Future<void> registerInstitution({
    required String schoolName,
    required String headOfInstitution,
    required String officialEmail,
    required String masterPassword,
    String? address,
    String? motto,
    String? logoPath,
  }) async {
    final normalizedEmail = officialEmail.toLowerCase().trim();
    final serverEnabled = await _serverEnabled();

    // Ensure DB is open before doing anything else.
    if (!serverEnabled) {
      await _ensureDbReady();
    }

    // In server mode, the backend is the source of truth. Always register there
    // first and recover to login if the account already exists.
    if (serverEnabled) {
      final remote = await _remoteApi();
      if (remote == null) {
        throw Exception('Server Mode is enabled but no server client is configured');
      }

      Map<String, dynamic> resp;
      try {
        resp = await remote.registerSchool(
          code: _generateSchoolCode(schoolName),
          name: schoolName,
          adminEmail: normalizedEmail,
          adminPassword: masterPassword,
          adminFullName: headOfInstitution,
        );
      } catch (error) {
        final message = error.toString().toLowerCase();
        final looksLikeConflict =
            message.contains('already exists') || message.contains('409');

        if (!looksLikeConflict) {
          rethrow;
        }

        resp = await remote.login(
          email: normalizedEmail,
          password: masterPassword,
          role: UserRole.admin.name,
        );
      }

      final token = resp['token']?.toString();
      if (token == null || token.isEmpty) {
        throw Exception('Server did not return a token');
      }

      await _setServerToken(token);

      final school = resp['school'];
      final schoolId = (school is Map) ? school['id']?.toString() : null;
      final schema = (school is Map) ? school['schema']?.toString() : null;
      final name = (school is Map) ? school['name']?.toString() : schoolName;
      if (schoolId != null && schoolId.isNotEmpty) {
        await _setServerSchoolId(schoolId);
      }
      if (schema != null && schema.isNotEmpty) {
        await _setServerSchoolSchema(schema);
      }

      // Cache local display values.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefInstitutionRegistered, true);
      await prefs.setString(_prefSchoolName, name ?? schoolName);
      await prefs.setBool('just_registered', true);

      // Also cache current user details for UI restore.
      final user = resp['user'];
      if (user is Map) {
        await _storeServerUser(
          id: user['id']?.toString() ?? '',
          email: user['email']?.toString() ?? normalizedEmail,
          fullName: user['fullName']?.toString() ?? headOfInstitution,
          role: user['role']?.toString() ?? UserRole.admin.name,
        );
      }

      return;
    }

    final alreadyRegistered = await isInstitutionRegistered();

    // Best-effort: also register on the server (future Postgres backend)
    // before creating the local admin, so we can store the returned token/schema.
    if (!alreadyRegistered && await _serverEnabled()) {
      try {
        final remote = await _remoteApi();
        if (remote != null) {
          final resp = await remote.registerSchool(
            code: _generateSchoolCode(schoolName),
            name: schoolName,
            adminEmail: normalizedEmail,
            adminPassword: masterPassword,
            adminFullName: headOfInstitution,
          );

          final token = resp['token']?.toString();
          if (token != null && token.isNotEmpty) {
            await _setServerToken(token);
          }

          final school = resp['school'];
          final schoolId = (school is Map) ? school['id']?.toString() : null;
          final schema = (school is Map) ? school['schema']?.toString() : null;
          if (schoolId != null && schoolId.isNotEmpty) {
            await _setServerSchoolId(schoolId);
          }
          if (schema != null && schema.isNotEmpty) {
            await _setServerSchoolSchema(schema);
          }
        }
      } catch (_) {
        // Keep local-only working; server sync can be retried later.
      }
    }

    await _database.transaction(() async {
      // Hash the master password
      final passwordHash = PasswordHasher.hashPassword(masterPassword);

      // Create or Update institutional identity (Handle half-broken states)
      await _database.upsertInstitutionalIdentity(
        InstitutionalIdentityCompanion.insert(
          schoolName: schoolName,
          headOfInstitution: headOfInstitution,
          officialEmail: normalizedEmail,
          masterPasswordHash: passwordHash,
          address: Value(address),
          motto: Value(motto),
          logoPath: Value(logoPath),
        ),
      );

      // Create or reset the primary admin user.
      // If an admin already exists for this email, update their password so login works.
      final existingUser = await _database.getUserByEmail(normalizedEmail);
      if (existingUser == null) {
        final now = DateTime.now();
        await _database.createUser(
          UsersCompanion(
            fullName: Value(headOfInstitution),
            email: Value(normalizedEmail),
            passwordHash: Value(passwordHash),
            role: Value(UserRole.admin.name),
            photoPath: const Value(null),
            phoneNumber: const Value(null),
            isActive: const Value(true),
            createdAt: Value(now),
            updatedAt: Value(now),
            isDirty: const Value(false),
          ),
        );
      } else {
        // Ensure the provided email becomes the admin account for this device.
        // This fixes the case where the email already existed as a staff account.
        await _database.updateUser(
          UsersCompanion(
            id: Value(existingUser.id),
            fullName: Value(headOfInstitution),
            passwordHash: Value(passwordHash),
            role: Value(UserRole.admin.name),
            isActive: const Value(true),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    });

    // Mirror registration state in local storage AFTER successful transaction
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefInstitutionRegistered, true);
    await prefs.setString(_prefSchoolName, schoolName);
  }

  /// Create a new user
  Future<int> createUser({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    String? photoPath,
    String? phoneNumber,
  }) async {
    if (await _serverEnabled()) {
      final remote = await _remoteApi();
      if (remote == null) {
        throw Exception('Server Mode is enabled but no server client is configured');
      }
      final token = await _serverToken();
      if (token == null || token.isEmpty) {
        throw Exception('Missing server token. Log in as an admin first.');
      }

      await remote.registerStaff(
        adminToken: token,
        email: email.toLowerCase().trim(),
        password: password,
        fullName: fullName,
        role: role.name,
      );

      // Backend owns IDs; return 0 as placeholder.
      return 0;
    }

    // Check if user already exists
    final normalizedEmail = email.toLowerCase().trim();
    final existingUser = await _database.getUserByEmail(normalizedEmail);
    if (existingUser != null) {
      throw Exception('User with this email already exists');
    }

    // NOTE: Removing the artificial 3-account limit so real schools can
    // register all staff accounts needed.

    // Hash password
    final passwordHash = PasswordHasher.hashPassword(password);

    // Create user locally (source of truth for offline)
    final now = DateTime.now();
    final localUserId = await _database.createUser(
      UsersCompanion(
        fullName: Value(fullName),
        email: Value(normalizedEmail),
        passwordHash: Value(passwordHash),
        role: Value(role.name),
        photoPath: Value(photoPath),
        phoneNumber: Value(phoneNumber),
        isActive: const Value(true),
        createdAt: Value(now),
        updatedAt: Value(now),
        isDirty: const Value(false),
      ),
    );

    // Best-effort: also create on the server (future Postgres backend)
    try {
      final remote = await _remoteApi();
      if (remote != null && await _serverEnabled()) {
        final token = await _serverToken();
        if (token != null && token.isNotEmpty && role != UserRole.admin) {
          await remote.registerStaff(
            adminToken: token,
            email: normalizedEmail,
            password: password,
            fullName: fullName,
            role: role.name,
          );
        }
      }
    } catch (_) {
      // Keep local-only working; server sync can be retried later.
    }

    return localUserId;
  }

  /// Create or update a non-admin user (staff portals).
  ///
  /// This is used by staff admission so the login ID + password entered during
  /// registration always becomes the staff member's working credential.
  Future<int> createOrUpdateStaffUser({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    String? photoPath,
    String? phoneNumber,
  }) async {
    final normalizedEmail = email.toLowerCase().trim();

    final existingUser = await _database.getUserByEmail(normalizedEmail);
    if (existingUser != null && existingUser.role == UserRole.admin.name) {
      throw Exception('This login email is already used by an Administrator account');
    }

    if (role == UserRole.director) {
      final existingDirector = await (_database.select(_database.users)
            ..where((u) => u.role.equals(UserRole.director.name))
            ..limit(1))
          .getSingleOrNull();
      if (existingDirector != null && existingDirector.id != existingUser?.id) {
        throw Exception('Only one Director account is allowed for a school');
      }
    }

    if (await _serverEnabled()) {
      // Server mode owns auth, but we still maintain a local shadow user so
      // local foreign keys and staff listings continue to work.
      final remote = await _remoteApi();
      if (remote == null) {
        throw Exception('Server Mode is enabled but no server client is configured');
      }
      final token = await _serverToken();
      if (token == null || token.isEmpty) {
        throw Exception('Missing server token. Log in as an admin first.');
      }

      final response = await remote.registerStaff(
        adminToken: token,
        email: normalizedEmail,
        password: password,
        fullName: fullName,
        role: role.name,
      );

      final passwordHash = PasswordHasher.hashPassword(password);
      final now = DateTime.now();
      final remoteUserId = switch (response['user']) {
        Map<String, dynamic> userJson => userJson['id']?.toString(),
        Map userJson => userJson['id']?.toString(),
        _ => null,
      };

      if (existingUser == null) {
        return await _database.createUser(
          UsersCompanion(
            fullName: Value(fullName),
            email: Value(normalizedEmail),
            passwordHash: Value(passwordHash),
            role: Value(role.name),
            photoPath: Value(photoPath),
            phoneNumber: Value(phoneNumber),
            isActive: const Value(true),
            createdAt: Value(now),
            updatedAt: Value(now),
            remoteId: Value(remoteUserId),
            isDirty: const Value(false),
          ),
        );
      }

      await _database.updateUser(
        UsersCompanion(
          id: Value(existingUser.id),
          fullName: Value(fullName),
          passwordHash: Value(passwordHash),
          role: Value(role.name),
          photoPath: Value(photoPath),
          phoneNumber: Value(phoneNumber),
          remoteId: Value(remoteUserId ?? existingUser.remoteId),
          isActive: const Value(true),
          updatedAt: Value(now),
        ),
      );

      return existingUser.id;
    }

    final passwordHash = PasswordHasher.hashPassword(password);
    final now = DateTime.now();

    if (existingUser == null) {
      return await _database.createUser(
        UsersCompanion(
          fullName: Value(fullName),
          email: Value(normalizedEmail),
          passwordHash: Value(passwordHash),
          role: Value(role.name),
          photoPath: Value(photoPath),
          phoneNumber: Value(phoneNumber),
          isActive: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now),
          isDirty: const Value(false),
        ),
      );
    }

    await _database.updateUser(
      UsersCompanion(
        id: Value(existingUser.id),
        fullName: Value(fullName),
        passwordHash: Value(passwordHash),
        role: Value(role.name),
        phoneNumber: Value(phoneNumber),
        isActive: const Value(true),
        updatedAt: Value(now),
      ),
    );

    return existingUser.id;
  }

  /// Authenticate user and create session
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final normalizedEmail = email.toLowerCase().trim();

    Future<T> step<T>(String name, Future<T> future, {Duration timeout = const Duration(seconds: 45)}) async {
      try {
        return await future.timeout(timeout);
      } on TimeoutException {
        throw Exception(
          'Database operation timed out ($name). '
          'Please close other running instances of the app and try again.',
        );
      }
    }

    // Backend-first: when Server Mode is enabled, do not fall back to SQLite.
    final remote = await _remoteApi();
    if (remote != null && await _serverEnabled()) {
      final resp = await remote.login(
        email: normalizedEmail,
        password: password,
        role: role.name,
      );
      final token = resp['token']?.toString();
      final userJson = resp['user'];
      final schoolJson = resp['school'];

      if (token == null || token.isEmpty) {
        throw Exception('Server did not return a token');
      }

      await _setServerToken(token);

      final schoolId = (schoolJson is Map) ? schoolJson['id']?.toString() : null;
      final schema = (schoolJson is Map) ? schoolJson['schema']?.toString() : null;
      final schoolName = (schoolJson is Map) ? schoolJson['name']?.toString() : null;
      if (schoolId != null && schoolId.isNotEmpty) {
        await _setServerSchoolId(schoolId);
      }
      if (schema != null && schema.isNotEmpty) {
        await _setServerSchoolSchema(schema);
      }

      final prefs = await SharedPreferences.getInstance();
      if (schoolName != null && schoolName.trim().isNotEmpty) {
        await prefs.setString(_prefSchoolName, schoolName);
      }
      await prefs.setBool(_prefInstitutionRegistered, true);

      if (userJson is! Map) {
        throw Exception('Server returned an invalid user payload');
      }

      final remoteRole = userJson['role']?.toString() ?? '';
      final normalizedRemoteRole = _normalizeRoleName(remoteRole);

      final hasDirectRoleMatch = normalizeRoleToken(normalizedRemoteRole) == normalizeRoleToken(role.name);
      final isHeadPortal = role == UserRole.headmaster || role == UserRole.headmistress;
      final canAccessHeadPortal =
          isHeadPortal && roleNameIsOneOf(normalizedRemoteRole, const [UserRole.headmaster, UserRole.headmistress]);

      final isDeputyPortal = role == UserRole.deputyheadmaster || role == UserRole.deputyheadmistress;
      final canAccessDeputyPortal = isDeputyPortal &&
          roleNameIsOneOf(normalizedRemoteRole, const [UserRole.deputyheadmaster, UserRole.deputyheadmistress]);

      if (!hasDirectRoleMatch && !canAccessHeadPortal && !canAccessDeputyPortal) {
        throw Exception('You do not have access to this portal');
      }

      final fullName = userJson['fullName']?.toString() ?? 'User';
      final remoteId = userJson['id']?.toString() ?? '';

      await _storeServerUser(
        id: remoteId,
        email: normalizedEmail,
        fullName: fullName,
        role: normalizedRemoteRole,
      );

      final now = DateTime.now();
      final user = User(
        id: 1,
        fullName: fullName,
        email: normalizedEmail,
        passwordHash: '',
        role: normalizedRemoteRole,
        photoPath: null,
        phoneNumber: null,
        isActive: true,
        createdAt: now,
        updatedAt: now,
        lastLoginAt: null,
        remoteId: remoteId,
        lastSyncedAt: null,
        isDirty: false,
      );

      // Provide a best-effort expiry timestamp derived from JWT exp.
      final expSeconds = _decodeJwtExpSeconds(token);
      final expiresAt = expSeconds == null
          ? now.add(const Duration(hours: 12))
          : DateTime.fromMillisecondsSinceEpoch(expSeconds * 1000, isUtc: true)
              .toLocal();

      return {
        'token': token,
        'user': user,
        'expiresAt': expiresAt,
        'serverToken': token,
      };
    }

    // Local login (SQLite)
    // Force the database to open and migrations to complete.
    // This can otherwise look like a "hung" login on some Windows installs.
    await step('open database', _database.customSelect('SELECT 1', readsFrom: const {}).getSingle(), timeout: const Duration(minutes: 2));

    var user = await step('load user', _database.getUserByEmail(normalizedEmail));

    // Self-heal: if admin user record is missing or out of sync with
    // institutional identity, allow admin login using the master password.
    final identity = await step('load institution', _database.getInstitutionalIdentity());
    final isInstitutionAdminLogin =
      role == UserRole.admin &&
      identity != null &&
      PasswordHasher.verifyPassword(password, identity.masterPasswordHash);

    if (user == null) {
      if (isInstitutionAdminLogin) {
        final institutionalIdentity = identity;
        final now = DateTime.now();
        await _database.createUser(
          UsersCompanion(
            fullName: Value(institutionalIdentity.headOfInstitution),
            email: Value(normalizedEmail),
            passwordHash: Value(institutionalIdentity.masterPasswordHash),
            role: Value(UserRole.admin.name),
            photoPath: const Value(null),
            phoneNumber: const Value(null),
            isActive: const Value(true),
            createdAt: Value(now),
            updatedAt: Value(now),
            isDirty: const Value(false),
          ),
        );
        user = await step('reload user', _database.getUserByEmail(normalizedEmail));
        if (user == null) {
          throw Exception('Invalid email or password');
        }
      } else {
        throw Exception('Invalid email or password');
      }
    }

    if (!PasswordHasher.verifyPassword(password, user.passwordHash)) {
      if (isInstitutionAdminLogin && user.role == UserRole.admin.name) {
        final institutionalIdentity = identity;
        // Bring the admin user password back in sync with master password.
        await _database.updateUser(
          UsersCompanion(
            id: Value(user.id),
            passwordHash: Value(institutionalIdentity.masterPasswordHash),
            updatedAt: Value(DateTime.now()),
          ),
        );
      } else {
        throw Exception('Invalid email or password');
      }
    }

    final hasDirectRoleMatch = normalizeRoleToken(user.role) == normalizeRoleToken(role.name);

    final isDirectorPortal = role == UserRole.director;
    final canAccessDirectorPortal =
      isDirectorPortal && normalizeRoleToken(user.role).contains(normalizeRoleToken(UserRole.director.name));

    final isHeadPortal = role == UserRole.headmaster || role == UserRole.headmistress;
    final canAccessHeadPortal =
        isHeadPortal && roleNameIsOneOf(user.role, const [UserRole.headmaster, UserRole.headmistress]);

    final isDeputyPortal = role == UserRole.deputyheadmaster || role == UserRole.deputyheadmistress;
    final canAccessDeputyPortal = isDeputyPortal &&
        roleNameIsOneOf(user.role, const [UserRole.deputyheadmaster, UserRole.deputyheadmistress]);

    if (!hasDirectRoleMatch && !canAccessHeadPortal && !canAccessDeputyPortal && !canAccessDirectorPortal) {
      throw Exception('You do not have access to this portal');
    }

    if (!user.isActive) {
      throw Exception('Your account has been deactivated');
    }

    // Generate session token
    final sessionData = TokenGenerator.generateSessionToken(userId: user.id);

    // Create session in database
    await step(
      'create session',
      _database.createSession(
        SessionsCompanion.insert(
          userId: user.id,
          token: sessionData['token'],
          expiresAt: sessionData['expiresAt'],
        ),
      ),
    );

    // Update last login time
    await step(
      'update last login',
      _database.updateUser(
        UsersCompanion(
          id: Value(user.id),
          lastLoginAt: Value(DateTime.now()),
        ),
      ),
    );

    return {
      'token': sessionData['token'],
      'user': user,
      'expiresAt': sessionData['expiresAt'],
      'serverToken': await _serverToken(),
    };
  }

  /// Validate session token
  Future<User?> validateSession(String token) async {
    if (await _serverEnabled()) {
      final exp = _decodeJwtExpSeconds(token);
      if (exp != null) {
        final nowSeconds = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        if (nowSeconds >= exp) return null;
      }
      return _serverUserFromPrefs();
    }

    // Get session
    final session = await _database.getSessionByToken(token);
    if (session == null) return null;

    // Check if expired
    if (session.expiresAt.isBefore(DateTime.now())) {
      await _database.deleteSession(token);
      return null;
    }

    // Get user
    return await _database.getUserById(session.userId);
  }

  /// Logout (delete session)
  Future<void> logout(String token) async {
    if (await _serverEnabled()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefServerToken);
      await prefs.remove(_prefServerSchoolSchema);
      await prefs.remove(_prefServerUserId);
      await prefs.remove(_prefServerUserEmail);
      await prefs.remove(_prefServerUserFullName);
      await prefs.remove(_prefServerUserRole);
      return;
    }

    await _database.deleteSession(token);
  }

  /// Clean up expired sessions
  Future<void> cleanupExpiredSessions() async {
    await _database.deleteExpiredSessions();
  }

  /// Update user password
  Future<void> updatePassword({
    required int userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    final user = await _database.getUserById(userId);
    if (user == null) {
      throw Exception('User not found');
    }

    // Verify old password
    if (!PasswordHasher.verifyPassword(oldPassword, user.passwordHash)) {
      throw Exception('Current password is incorrect');
    }

    // Hash new password
    final newPasswordHash = PasswordHasher.hashPassword(newPassword);

    // Update user
    await _database.updateUser(
      UsersCompanion(
        id: Value(userId),
        passwordHash: Value(newPasswordHash),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Recover/reset a user's password using the institution master password.
  ///
  /// This is intended for offline/local SQLite mode where email delivery is not available.
  /// For security, we require the master password (stored in institutional identity).
  Future<void> recoverPasswordWithMasterPassword({
    required String email,
    required String masterPassword,
    required String newPassword,
  }) async {
    final normalizedEmail = email.toLowerCase().trim();
    if (normalizedEmail.isEmpty) {
      throw Exception('Please enter your email');
    }
    if (newPassword.trim().length < 4) {
      throw Exception('Password too short (min 4)');
    }

    // Server mode: recovery should be handled by backend.
    if (await _serverEnabled()) {
      throw Exception('Password recovery is not available in Server Mode yet.');
    }

    final identity = await _database.getInstitutionalIdentity();
    if (identity == null) {
      throw Exception('Institution not registered');
    }

    final ok = PasswordHasher.verifyPassword(masterPassword, identity.masterPasswordHash);
    if (!ok) {
      throw Exception('Invalid master password');
    }

    final user = await _database.getUserByEmail(normalizedEmail);
    if (user == null) {
      throw Exception('No account found for this email');
    }

    final newPasswordHash = PasswordHasher.hashPassword(newPassword.trim());
    await _database.updateUser(
      UsersCompanion(
        id: Value(user.id),
        passwordHash: Value(newPasswordHash),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateStaffPortalAccount({
    required String email,
    required String fullName,
    required UserRole role,
    bool? isActive,
  }) async {
    if (!await _serverEnabled()) {
      return;
    }

    final remote = await _remoteApi();
    if (remote == null) {
      throw Exception('Server Mode is enabled but no server client is configured');
    }

    final token = await _serverToken();
    if (token == null || token.isEmpty) {
      throw Exception('Missing server token. Log in as an admin first.');
    }

    await remote.updateStaff(
      adminToken: token,
      email: email.toLowerCase().trim(),
      fullName: fullName,
      role: role.name,
      isActive: isActive,
    );
  }

  /// Emergency reset of all authentication and institutional data
  Future<void> performEmergencyReset() async {
    // 1) Best-effort: close the database to release Windows file locks.
    try {
      await _database.close().timeout(const Duration(seconds: 10));
    } catch (_) {
      // Best-effort.
    }

    // 2) Prefer deleting the database file entirely (fast + reliable).
    bool deleted = false;
    try {
      final dbFile = await getDatabaseFile();
      final wal = File('${dbFile.path}-wal');
      final shm = File('${dbFile.path}-shm');

      if (await wal.exists()) {
        await wal.delete();
      }
      if (await shm.exists()) {
        await shm.delete();
      }
      if (await dbFile.exists()) {
        await dbFile.delete();
      }

      deleted = true;
    } catch (_) {
      deleted = false;
    }

    // 3) Fallback: clear tables if file deletion wasn't possible.
    if (!deleted) {
      try {
        await _ensureDbReady(timeout: const Duration(seconds: 30));
        await _database.emergencyReset().timeout(const Duration(minutes: 2));
      } catch (_) {
        // Ignore; we still clear prefs below.
      }
    }

    // 4) Clear SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
