import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/core/services/remote_sync_api.dart';
import 'package:ghanaclass_school_management/core/config/app_mode.dart';
import 'package:ghanaclass_school_management/core/config/backend_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Offline-first sync using a local outbox + server change log.
///
/// When Server Mode is enabled, this service will:
/// - Push pending `SyncOutbox` operations to the backend `/sync/push`
/// - Pull change log pages from `/sync/pull` and advance a cursor
///
/// Applying pulled changes to specific feature tables is intentionally
/// left to a later step (requires mapping per entity type).
class SyncService {
  SyncService(this._database, {RemoteSyncApi? remote}) : _remote = remote;

  final AppDatabase _database;
  RemoteSyncApi? _remote;

  static const _prefServerEnabled = 'server_enabled';
  static const _prefServerBaseUrl = 'server_base_url';
  static const _prefServerToken = 'server_token';
  static const _prefServerSchoolSchema = 'server_school_schema';
  static const _prefDeviceId = 'device_id';

  static const _metaCursorKey = 'server_change_cursor';

  Future<bool> _serverEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return AppMode.resolveServerEnabled(prefs.getBool(_prefServerEnabled));
  }

  Future<String?> _serverBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_prefServerBaseUrl);
    if (v?.trim().isEmpty ?? true) return BackendConfig.defaultApiBaseUrl;
    return v!.trim();
  }

  Future<String?> _serverToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefServerToken);
  }

  Future<String?> _serverSchoolSchema() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_prefServerSchoolSchema)?.trim();
    if (value == null || value.isEmpty) {
      return BackendConfig.defaultSchoolSchema;
    }
    return value;
  }

  Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_prefDeviceId);
    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }

    final newId = 'device_${_uuidV4()}';
    await prefs.setString(_prefDeviceId, newId);
    return newId;
  }

  Future<RemoteSyncApi?> _remoteApi() async {
    final baseUrl = await _serverBaseUrl();
    if (baseUrl == null) return null;

    if (_remote == null || _remote!.baseUrl != baseUrl) {
      _remote = RemoteSyncApi(baseUrl: baseUrl);
    }
    return _remote;
  }

  /// Runs a single sync cycle (push then pull).
  Future<void> syncOnce() async {
    if (!await _serverEnabled()) return;

    final remote = await _remoteApi();
    final schema = await _serverSchoolSchema();
    final token = await _serverToken();
    final hasSchema = schema != null && schema.trim().isNotEmpty;
    final hasToken = token != null && token.trim().isNotEmpty;
    if (remote == null || (!hasSchema && !hasToken)) {
      return;
    }

    await pushOutbox();
    await pullAndApplyChanges();
  }

  /// Push pending outbox ops to backend `/sync/push`.
  Future<void> pushOutbox() async {
    if (!await _serverEnabled()) return;

    final remote = await _remoteApi();
    final schema = await _serverSchoolSchema();
    final token = await _serverToken();
    final normalizedSchema = schema?.trim();
    final hasSchema = normalizedSchema != null && normalizedSchema.isNotEmpty;
    final hasToken = token != null && token.trim().isNotEmpty;
    if (remote == null || (!hasSchema && !hasToken)) return;

    final ops = await _database.getPendingOutbox(limit: 200);
    if (ops.isEmpty) return;

    final deviceId = await _deviceId();

    final payloadOps = <Map<String, dynamic>>[];

    for (final op in ops) {
      await _database.markOutboxAttempted(op.id);
      await _database.markOutboxStatus(op.id, 'sent');

      Map<String, dynamic> payload;
      try {
        final decoded = jsonDecode(op.payloadJson);
        payload = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      } catch (_) {
        payload = <String, dynamic>{};
      }

      payloadOps.add({
        'opId': op.opId,
        'entityType': op.entityType,
        'operation': op.operation,
        'payload': payload,
      });
    }

    try {
      final resp = await remote.push(
        schoolSchema: normalizedSchema,
        deviceId: deviceId,
        ops: payloadOps,
        bearerToken: token,
      );

      final acked = resp['ackedOpIds'];
      if (acked is List) {
        final ackedIds = acked.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
        for (final op in ops) {
          if (ackedIds.contains(op.opId)) {
            await _database.markOutboxStatus(op.id, 'acked');
          }
        }

        // Keep outbox small.
        await _database.deleteOutboxByOpIds(ackedIds);
      }
    } catch (_) {
      // Mark all attempted as failed; will retry later.
      for (final op in ops) {
        await _database.markOutboxStatus(op.id, 'failed');
      }
    }
  }

  /// Pull change log from backend `/sync/pull`.
  ///
  /// This method does not apply changes.
  Future<List<Map<String, dynamic>>> pullChanges() async {
    if (!await _serverEnabled()) return const [];

    final remote = await _remoteApi();
    final schema = await _serverSchoolSchema();
    final token = await _serverToken();
    final normalizedSchema = schema?.trim();
    final hasSchema = normalizedSchema != null && normalizedSchema.isNotEmpty;
    final hasToken = token != null && token.trim().isNotEmpty;
    if (remote == null || (!hasSchema && !hasToken)) {
      return const [];
    }

    final cursorRaw = await _database.getSyncMetadataValue(_metaCursorKey);
    final cursor = int.tryParse(cursorRaw ?? '') ?? 0;

    final resp = await remote.pull(
          schoolSchema: normalizedSchema,
          since: cursor,
          bearerToken: token,
        );

    final changes = resp['changes'];
    if (changes is List) {
      return changes.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    }

    return const [];
  }

  /// Pull change log, apply supported entities to local tables, then advance cursor.
  Future<void> pullAndApplyChanges() async {
    if (!await _serverEnabled()) return;

    final remote = await _remoteApi();
    final schema = await _serverSchoolSchema();
    final token = await _serverToken();
    final normalizedSchema = schema?.trim();
    final hasSchema = normalizedSchema != null && normalizedSchema.isNotEmpty;
    final hasToken = token != null && token.trim().isNotEmpty;
    if (remote == null || (!hasSchema && !hasToken)) {
      return;
    }

    final cursorRaw = await _database.getSyncMetadataValue(_metaCursorKey);
    final cursor = int.tryParse(cursorRaw ?? '') ?? 0;

    final resp = await remote.pull(
      schoolSchema: normalizedSchema,
      since: cursor,
      bearerToken: token,
    );

    final changesRaw = resp['changes'];
    final changes = changesRaw is List
        ? changesRaw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
        : const <Map<String, dynamic>>[];

    await _applyChanges(changes);

    final newCursor = int.tryParse(resp['cursor']?.toString() ?? '') ?? cursor;
    if (newCursor != cursor) {
      await _database.setSyncMetadataValue(_metaCursorKey, newCursor.toString());
    }
  }

  Future<void> _applyChanges(List<Map<String, dynamic>> changes) async {
    if (changes.isEmpty) return;

    await _database.transaction(() async {
      for (final change in changes) {
        final entityType = change['entityType']?.toString();
        final operation = change['operation']?.toString();

        if (entityType == null || operation == null) continue;

        final payload = _normalizePayload(change['payload']);

        switch (entityType) {
          case 'students':
            await _applyStudentChange(operation: operation, payload: payload);
            break;
          case 'health_records':
            await _applyHealthRecordChange(operation: operation, payload: payload);
            break;
          case 'academic_history':
            await _applyAcademicHistoryChange(operation: operation, payload: payload);
            break;
          default:
            // Unknown entity type; ignore for now.
            break;
        }
      }
    });
  }

  Future<int?> _resolveLocalStudentIdFromRemoteId(String? studentRemoteId) async {
    final rid = studentRemoteId?.trim();
    if (rid == null || rid.isEmpty) return null;

    final s = await (_database.select(_database.students)..where((t) => t.remoteId.equals(rid))).getSingleOrNull();
    return s?.id;
  }

  Future<void> _applyHealthRecordChange({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    final remoteId = payload['remoteId']?.toString().trim();
    final studentRemoteId = payload['studentRemoteId']?.toString();

    final studentId = await _resolveLocalStudentIdFromRemoteId(studentRemoteId);
    if (studentId == null) {
      // Can't apply without mapping to a local student.
      return;
    }

    HealthRecord? existing;
    if (remoteId != null && remoteId.isNotEmpty) {
      existing = await (_database.select(_database.healthRecords)
            ..where((t) => t.remoteId.equals(remoteId)))
          .getSingleOrNull();
    }
    existing ??= await (_database.select(_database.healthRecords)..where((t) => t.studentId.equals(studentId))).getSingleOrNull();

    if (operation == 'delete') {
      if (existing == null) return;
      final existingId = existing.id;
      await (_database.delete(_database.healthRecords)..where((t) => t.id.equals(existingId))).go();
      return;
    }

    final companion = HealthRecordsCompanion(
      studentId: drift.Value(studentId),
      bloodGroup: drift.Value(payload['bloodGroup'] as String?),
      allergies: drift.Value(payload['allergies'] as String?),
      vaccinations: drift.Value(payload['vaccinations'] as String?),
      medications: drift.Value(payload['medications'] as String?),
      physicalDisability: drift.Value(payload['physicalDisability'] as String?),
      emergencyInstructions: drift.Value(payload['emergencyInstructions'] as String?),
      remoteId: drift.Value(remoteId),
      lastSyncedAt: drift.Value(DateTime.now()),
      isDirty: const drift.Value(false),
    );

    if (existing == null) {
      await _database.into(_database.healthRecords).insert(
            HealthRecordsCompanion.insert(
              studentId: studentId,
              bloodGroup: drift.Value(payload['bloodGroup'] as String?),
              allergies: drift.Value(payload['allergies'] as String?),
              vaccinations: drift.Value(payload['vaccinations'] as String?),
              medications: drift.Value(payload['medications'] as String?),
              physicalDisability: drift.Value(payload['physicalDisability'] as String?),
              emergencyInstructions: drift.Value(payload['emergencyInstructions'] as String?),
              remoteId: drift.Value(remoteId),
              lastSyncedAt: drift.Value(DateTime.now()),
              isDirty: const drift.Value(false),
            ),
          );
    } else {
      final existingId = existing.id;
      await (_database.update(_database.healthRecords)..where((t) => t.id.equals(existingId))).write(companion);
    }
  }

  Future<void> _applyAcademicHistoryChange({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    final remoteId = payload['remoteId']?.toString().trim();
    final studentRemoteId = payload['studentRemoteId']?.toString();
    final formerSchool = payload['formerSchool']?.toString();

    if (remoteId == null || remoteId.isEmpty) {
      // Academic history is multi-row; require a stable remoteId.
      return;
    }

    final studentId = await _resolveLocalStudentIdFromRemoteId(studentRemoteId);
    if (studentId == null) return;

    final existing = await (_database.select(_database.academicHistory)
          ..where((t) => t.remoteId.equals(remoteId)))
        .getSingleOrNull();

    if (operation == 'delete') {
      if (existing == null) return;
      final existingId = existing.id;
      await (_database.delete(_database.academicHistory)..where((t) => t.id.equals(existingId))).go();
      return;
    }

    if (formerSchool == null || formerSchool.trim().isEmpty) {
      return;
    }

    final companion = AcademicHistoryCompanion(
      studentId: drift.Value(studentId),
      formerSchool: drift.Value(formerSchool),
      highestClassReached: drift.Value(payload['highestClassReached'] as String?),
      reasonForLeaving: drift.Value(payload['reasonForLeaving'] as String?),
      assessmentScores: drift.Value(payload['assessmentScores'] as String?),
      certificatesPath: drift.Value(payload['certificatesPath'] as String?),
      remoteId: drift.Value(remoteId),
      lastSyncedAt: drift.Value(DateTime.now()),
      isDirty: const drift.Value(false),
    );

    if (existing == null) {
      await _database.into(_database.academicHistory).insert(
            AcademicHistoryCompanion.insert(
              studentId: studentId,
              formerSchool: formerSchool,
              highestClassReached: drift.Value(payload['highestClassReached'] as String?),
              reasonForLeaving: drift.Value(payload['reasonForLeaving'] as String?),
              assessmentScores: drift.Value(payload['assessmentScores'] as String?),
              certificatesPath: drift.Value(payload['certificatesPath'] as String?),
              remoteId: drift.Value(remoteId),
              lastSyncedAt: drift.Value(DateTime.now()),
              isDirty: const drift.Value(false),
            ),
          );
    } else {
      final existingId = existing.id;
      await (_database.update(_database.academicHistory)..where((t) => t.id.equals(existingId))).write(companion);
    }
  }

  Map<String, dynamic> _normalizePayload(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return const <String, dynamic>{};
      }
    }
    return const <String, dynamic>{};
  }

  Future<void> _applyStudentChange({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    // Identify target row by stable keys.
    final remoteId = payload['remoteId']?.toString().trim();
    final studentId = payload['studentId']?.toString().trim();
    final admissionNumber = payload['admissionNumber']?.toString().trim();

    Student? existing;
    if (remoteId != null && remoteId.isNotEmpty) {
      existing = await (_database.select(_database.students)
            ..where((t) => t.remoteId.equals(remoteId)))
          .getSingleOrNull();
    }
    existing ??= studentId != null && studentId.isNotEmpty
        ? await (_database.select(_database.students)
              ..where((t) => t.studentId.equals(studentId)))
            .getSingleOrNull()
        : null;
    existing ??= admissionNumber != null && admissionNumber.isNotEmpty
        ? await (_database.select(_database.students)
              ..where((t) => t.admissionNumber.equals(admissionNumber)))
            .getSingleOrNull()
        : null;

    if (operation == 'delete') {
      if (existing == null) return;
      final existingId = existing.id;
      await (_database.update(_database.students)..where((t) => t.id.equals(existingId))).write(
        StudentsCompanion(
          isActive: const drift.Value(false),
          status: const drift.Value('inactive'),
          lastSyncedAt: drift.Value(DateTime.now()),
          isDirty: const drift.Value(false),
        ),
      );
      return;
    }

    // insert/update (upsert)
    final companion = _studentsCompanionFromPayload(payload);
    if (companion == null) return;

    if (existing == null) {
      await _database.into(_database.students).insert(companion);
    } else {
      final existingId = existing.id;
      await (_database.update(_database.students)..where((t) => t.id.equals(existingId))).write(companion);
    }
  }

  StudentsCompanion? _studentsCompanionFromPayload(Map<String, dynamic> p) {
    DateTime parseDateTime(dynamic v) {
      if (v is DateTime) return v;
      if (v is String) {
        final parsed = DateTime.tryParse(v);
        if (parsed != null) return parsed;
      }
      if (v is int) {
        return DateTime.fromMillisecondsSinceEpoch(v);
      }
      return DateTime.now();
    }

    int? parseInt(dynamic v) {
      if (v is int) return v;
      if (v is String) return int.tryParse(v);
      return null;
    }

    double parseDouble(dynamic v, {double fallback = 0.0}) {
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? fallback;
      return fallback;
    }

    bool parseBool(dynamic v, {bool fallback = false}) {
      if (v is bool) return v;
      if (v is String) {
        final lower = v.toLowerCase();
        if (lower == 'true' || lower == '1') return true;
        if (lower == 'false' || lower == '0') return false;
      }
      if (v is int) return v != 0;
      return fallback;
    }

    final studentId = p['studentId']?.toString();
    final firstName = p['firstName']?.toString();
    final lastName = p['lastName']?.toString();
    final gender = p['gender']?.toString();
    final guardianName = p['guardianName']?.toString();
    final guardianPhone = p['guardianPhone']?.toString();
    final guardianRelationship = p['guardianRelationship']?.toString();
    final admissionNumber = p['admissionNumber']?.toString();

    if (studentId == null ||
        firstName == null ||
        lastName == null ||
        gender == null ||
        guardianName == null ||
        guardianPhone == null ||
        guardianRelationship == null ||
        admissionNumber == null) {
      return null;
    }

    return StudentsCompanion(
      studentId: drift.Value(studentId),
      firstName: drift.Value(firstName),
      lastName: drift.Value(lastName),
      otherNames: drift.Value(p['otherNames'] as String?),
      gender: drift.Value(gender),
      dateOfBirth: drift.Value(parseDateTime(p['dateOfBirth'])),
      photoPath: drift.Value(p['photoPath'] as String?),
      address: drift.Value(p['address'] as String?),
      phoneNumber: drift.Value(p['phoneNumber'] as String?),
      email: drift.Value(p['email'] as String?),
      guardianName: drift.Value(guardianName),
      guardianPhone: drift.Value(guardianPhone),
      guardianEmail: drift.Value(p['guardianEmail'] as String?),
      guardianOccupation: drift.Value(p['guardianOccupation'] as String?),
      guardianRelationship: drift.Value(guardianRelationship),
      guardianAddress: drift.Value(p['guardianAddress'] as String?),
      classId: drift.Value(parseInt(p['classId'])),
      admissionDate: drift.Value(parseDateTime(p['admissionDate'])),
      admissionNumber: drift.Value(admissionNumber),
      enrolledFees: drift.Value(parseDouble(p['enrolledFees'])),
      isActive: drift.Value(parseBool(p['isActive'], fallback: true)),
      status: drift.Value(p['status']?.toString() ?? 'active'),
      createdAt: drift.Value(parseDateTime(p['createdAt'])),
      updatedAt: drift.Value(parseDateTime(p['updatedAt'])),
      remoteId: drift.Value(p['remoteId']?.toString()),
      lastSyncedAt: drift.Value(DateTime.now()),
      isDirty: const drift.Value(false),
    );
  }

  /// Enqueue a local change into the outbox.
  ///
  /// Call this from feature services when making local writes.
  Future<void> enqueueOutboxOp({
    required String entityType,
    required String operation,
    required Map<String, dynamic> payload,
    int? entityLocalId,
    String? entityRemoteId,
  }) async {
    final opId = _uuidV4();
    await _database.into(_database.syncOutbox).insert(
          SyncOutboxCompanion.insert(
            opId: opId,
            entityType: entityType,
            entityLocalId: drift.Value(entityLocalId),
            entityRemoteId: drift.Value(entityRemoteId),
            operation: operation,
            payloadJson: jsonEncode(payload),
          ),
        );
  }

  // Minimal UUIDv4 generator (no extra dependency)
  String _uuidV4() {
    final bytes = Uint8List(16);
    final rnd = Random.secure();
    for (var i = 0; i < 16; i++) {
      bytes[i] = rnd.nextInt(256);
    }
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10

    String hex(int v) => v.toRadixString(16).padLeft(2, '0');
    final b = bytes;
    return '${hex(b[0])}${hex(b[1])}${hex(b[2])}${hex(b[3])}'
        '-${hex(b[4])}${hex(b[5])}'
        '-${hex(b[6])}${hex(b[7])}'
        '-${hex(b[8])}${hex(b[9])}'
        '-${hex(b[10])}${hex(b[11])}${hex(b[12])}${hex(b[13])}${hex(b[14])}${hex(b[15])}';
  }
}
