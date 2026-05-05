import 'package:drift/drift.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/core/services/sync_service.dart';
import 'dart:math';

class BulkStudentImportResult {
  final int requested;
  final int created;
  final int updated;
  final List<String> errors;

  const BulkStudentImportResult({
    required this.requested,
    required this.created,
    required this.updated,
    required this.errors,
  });

  int get imported => created + updated;
  int get failed => errors.length;
}

class BulkStudentActionResult {
  final int requested;
  final int affected;
  final List<int> skippedStudentTableIds;
  final List<String> errors;

  const BulkStudentActionResult({
    required this.requested,
    required this.affected,
    required this.skippedStudentTableIds,
    required this.errors,
  });
}

class StudentService {
  final AppDatabase _database;
  final SyncService? _sync;

  StudentService(this._database, {SyncService? syncService}) : _sync = syncService;

  /// Result for bulk student import.
  ///
  /// `imported` is `created + updated`.
  /// `errors` are formatted as user-facing strings (include row numbers).
  static const _importRowNumberOffset = 2; // Header row is 1.

  

  Future<Student?> getStudentById(int id) async {
    return await (_database.select(_database.students)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<bool> studentIdExists(String studentId) async {
    final normalized = studentId.trim();
    if (normalized.isEmpty) return false;

    final existing = await (_database.select(_database.students)
          ..where((t) => t.studentId.equals(normalized))
          ..limit(1))
        .getSingleOrNull();
    return existing != null;
  }

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

  String _slugToClassCode(String value) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();
    if (cleaned.isEmpty) return 'CLS';
    return cleaned.length <= 8 ? cleaned : cleaned.substring(0, 8);
  }

  /// Ensure a class exists and return its id.
  ///
  /// This is used by the admission form. It creates the class if it doesn't exist.
  Future<int> ensureClassIdForName(String className, {int? academicYear}) async {
    final name = className.trim();
    final year = academicYear ?? DateTime.now().year;
    if (name.isEmpty) {
      throw ArgumentError('className cannot be empty');
    }

    final code = _slugToClassCode(name);

    final existing = await (_database.select(_database.schoolClasses)
          ..where((t) => t.className.equals(name) & t.academicYear.equals(year))
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) return existing.id;

    // In some schemas `class_code` is globally unique (not scoped by academic year).
    // Avoid inserting duplicates by resolving by code first.
    final byCode = await (_database.select(_database.schoolClasses)
          ..where((t) => t.classCode.equals(code))
          ..limit(1))
        .getSingleOrNull();
    if (byCode != null) return byCode.id;

    try {
      return await _database.into(_database.schoolClasses).insert(
            SchoolClassesCompanion.insert(
              className: name,
              classCode: code,
              academicYear: year,
              capacity: const Value(40),
            ),
          );
    } catch (_) {
      // If another flow inserted the same class code concurrently (or legacy DB
      // has a unique constraint we didn't anticipate), fall back to lookup.
      final retry = await (_database.select(_database.schoolClasses)
            ..where((t) => t.classCode.equals(code))
            ..limit(1))
          .getSingleOrNull();
      if (retry != null) return retry.id;
      rethrow;
    }
  }

  DateTime? _tryParseDate(String? raw) {
    final v = raw?.trim();
    if (v == null || v.isEmpty) return null;

    // 1) ISO (yyyy-mm-dd or full)
    final iso = DateTime.tryParse(v);
    if (iso != null) return iso;

    // 2) dd/mm/yyyy or mm/dd/yyyy
    final m = RegExp(r'^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})$').firstMatch(v);
    if (m != null) {
      final a = int.tryParse(m.group(1)!);
      final b = int.tryParse(m.group(2)!);
      final y = int.tryParse(m.group(3)!);
      if (a == null || b == null || y == null) return null;

      // Assume Ghana-style dd/mm/yyyy by default.
      final day = a;
      final month = b;
      final d1 = DateTime.tryParse('$y-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}');
      if (d1 != null) return d1;

      // Fallback: mm/dd/yyyy
      final d2 = DateTime.tryParse('$y-${a.toString().padLeft(2, '0')}-${b.toString().padLeft(2, '0')}');
      return d2;
    }

    return null;
  }

  String _generateStudentId({required int year, required int seed}) {
    final rand = (1000 + (seed % 9000)).toString();
    return 'STU-$year-$rand';
  }

  String _generateAdmissionNumber({required int seed}) {
    final tail = (seed % 1000000).toString().padLeft(6, '0');
    return 'ADM-$tail';
  }

  Future<String> _ensureUniqueStudentId(String? preferred, {required int seed}) async {
    String candidate;
    if (preferred != null && preferred.trim().isNotEmpty) {
      candidate = preferred.trim();
    } else {
      candidate = _generateStudentId(year: DateTime.now().year, seed: seed);
    }

    for (var i = 0; i < 5; i++) {
      final exists = await (_database.select(_database.students)
            ..where((t) => t.studentId.equals(candidate))
            ..limit(1))
          .get();
      if (exists.isEmpty) return candidate;
      candidate = _generateStudentId(year: DateTime.now().year, seed: seed + i + 1);
    }

    return '$candidate-${_uuidV4().split('-').first}';
  }

  Future<String> _ensureUniqueAdmissionNumber(String? preferred, {required int seed}) async {
    String candidate;
    if (preferred != null && preferred.trim().isNotEmpty) {
      candidate = preferred.trim();
    } else {
      candidate = _generateAdmissionNumber(seed: DateTime.now().millisecondsSinceEpoch + seed);
    }

    for (var i = 0; i < 5; i++) {
      final exists = await (_database.select(_database.students)
            ..where((t) => t.admissionNumber.equals(candidate))
            ..limit(1))
          .get();
      if (exists.isEmpty) return candidate;
      candidate = _generateAdmissionNumber(seed: DateTime.now().millisecondsSinceEpoch + seed + i + 1);
    }

    return '$candidate-${seed.toString().padLeft(3, '0')}';
  }

  Future<int?> _getOrCreateClassId({
    required Map<String, int> classCodeToId,
    required Map<String, int> classNameToId,
    required String? className,
    required String? classCode,
    required int academicYear,
  }) async {
    final name = className?.trim();
    final code = classCode?.trim();

    if ((name == null || name.isEmpty) && (code == null || code.isEmpty)) {
      return null;
    }

    if (code != null && code.isNotEmpty) {
      final k = code.toUpperCase();
      final existing = classCodeToId[k];
      if (existing != null) return existing;
    }

    if (name != null && name.isNotEmpty) {
      final k = '${name.toLowerCase()}::$academicYear';
      final existing = classNameToId[k];
      if (existing != null) return existing;
    }

    final finalName = (name == null || name.isEmpty) ? (code ?? 'Class') : name;
    final finalCode = (code == null || code.isEmpty) ? _slugToClassCode(finalName) : code.toUpperCase();

    // Some schemas enforce `class_code` uniqueness globally (not per academic year).
    // If this row did not provide a class code, `finalCode` is derived from the
    // class name, so we must still resolve by code before attempting an insert.
    final existingByCodeInMap = classCodeToId[finalCode];
    if (existingByCodeInMap != null) return existingByCodeInMap;

    final existingByCode = await (_database.select(_database.schoolClasses)
          ..where((t) => t.classCode.equals(finalCode))
          ..limit(1))
        .getSingleOrNull();
    if (existingByCode != null) {
      classCodeToId[existingByCode.classCode.toUpperCase()] = existingByCode.id;
      classNameToId['${existingByCode.className.toLowerCase()}::${existingByCode.academicYear}'] = existingByCode.id;
      return existingByCode.id;
    }

    // Create.
    try {
      final id = await _database.into(_database.schoolClasses).insert(
            SchoolClassesCompanion.insert(
              className: finalName,
              classCode: finalCode,
              academicYear: academicYear,
              capacity: const Value(40),
            ),
          );

      classCodeToId[finalCode] = id;
      classNameToId['${finalName.toLowerCase()}::$academicYear'] = id;
      return id;
    } catch (_) {
      // If an insert fails due to a unique constraint, resolve by code.
      final retry = await (_database.select(_database.schoolClasses)
            ..where((t) => t.classCode.equals(finalCode))
            ..limit(1))
          .getSingleOrNull();
      if (retry != null) {
        classCodeToId[retry.classCode.toUpperCase()] = retry.id;
        classNameToId['${retry.className.toLowerCase()}::${retry.academicYear}'] = retry.id;
        return retry.id;
      }
      rethrow;
    }
  }

  String? _getAny(Map<String, String> row, List<String> keys) {
    for (final key in keys) {
      final v = row[key];
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  /// Bulk import students from parsed rows.
  ///
  /// Expected columns (flexible):
  /// - Class Name / Class / ClassName
  /// - Class Code / ClassCode
  /// - Academic Year
  /// - Student ID (optional)
  /// - Admission Number (optional)
  /// - First Name, Last Name, Other Names
  /// - Gender, DOB
  /// - Guardian Name, Guardian Phone, Guardian Relationship
  /// - Address, Phone Number, Email
  /// - Admission Date, Status, Enrolled Fees
  ///
  /// Automatically creates classes referenced by the file.
  Future<void> bulkImportStudentsFromRows(List<Map<String, String>> rows) async {
    await bulkImportStudentsFromRowsWithResult(rows);
  }

  Future<BulkStudentImportResult> bulkImportStudentsFromRowsWithResult(List<Map<String, String>> rows) async {
    final errors = <String>[];
    var created = 0;
    var updated = 0;

    await _database.transaction(() async {
      final existingClasses = await _database.select(_database.schoolClasses).get();
      final classCodeToId = <String, int>{};
      final classNameToId = <String, int>{};
      for (final c in existingClasses) {
        classCodeToId[c.classCode.toUpperCase()] = c.id;
        classNameToId['${c.className.toLowerCase()}::${c.academicYear}'] = c.id;
      }

      final seenStudentIds = <String, int>{};
      final seenAdmissionNumbers = <String, int>{};

      for (var i = 0; i < rows.length; i++) {
        final row = rows[i];
        final rowNumber = i + _importRowNumberOffset;
        final seed = DateTime.now().microsecondsSinceEpoch + i;

        try {
          final rawStudentId = _getAny(row, ['Student ID', 'StudentId', 'student_id']);
          final rawAdmissionNumber = _getAny(row, ['Admission Number', 'Admission No', 'admission_number']);

          if (rawStudentId != null) {
            final key = rawStudentId.trim();
            final prev = seenStudentIds[key];
            if (prev != null) {
              throw Exception('Duplicate Student ID "$key" (also in row $prev)');
            }
            seenStudentIds[key] = rowNumber;
          }
          if (rawAdmissionNumber != null) {
            final key = rawAdmissionNumber.trim();
            final prev = seenAdmissionNumbers[key];
            if (prev != null) {
              throw Exception('Duplicate Admission Number "$key" (also in row $prev)');
            }
            seenAdmissionNumbers[key] = rowNumber;
          }

          final className = _getAny(row, ['Class Name', 'Class', 'ClassName', 'class', 'class_name']);
          final classCode = _getAny(row, ['Class Code', 'ClassCode', 'class_code']);
          final academicYearStr = _getAny(row, ['Academic Year', 'Year', 'academic_year']);
          final academicYear = int.tryParse(academicYearStr ?? '') ?? DateTime.now().year;

          int? classId;
          try {
            classId = await _getOrCreateClassId(
              classCodeToId: classCodeToId,
              classNameToId: classNameToId,
              className: className,
              classCode: classCode,
              academicYear: academicYear,
            );
          } catch (_) {
            final refreshed = await _database.select(_database.schoolClasses).get();
            classCodeToId.clear();
            classNameToId.clear();
            for (final c in refreshed) {
              classCodeToId[c.classCode.toUpperCase()] = c.id;
              classNameToId['${c.className.toLowerCase()}::${c.academicYear}'] = c.id;
            }
            classId = await _getOrCreateClassId(
              classCodeToId: classCodeToId,
              classNameToId: classNameToId,
              className: className,
              classCode: classCode,
              academicYear: academicYear,
            );
          }

          final firstName = _getAny(row, ['First Name', 'Firstname', 'first_name']);
          final lastName = _getAny(row, ['Last Name', 'Lastname', 'last_name']);
          if (firstName == null || firstName.trim().isEmpty) {
            throw Exception('Missing First Name');
          }
          if (lastName == null || lastName.trim().isEmpty) {
            throw Exception('Missing Last Name');
          }

          final otherNames = _getAny(row, ['Other Names', 'OtherName', 'other_names']);

          final genderRaw = (_getAny(row, ['Gender', 'gender']) ?? 'male').toLowerCase();
          final gender = (genderRaw == 'female' || genderRaw == 'f') ? 'female' : 'male';

          final dobRaw = _getAny(row, ['DOB', 'Date of Birth', 'date_of_birth']);
          final dob = _tryParseDate(dobRaw);
          if (dobRaw != null && dob == null) {
            throw Exception('Invalid DOB "$dobRaw"');
          }
          if (dob == null) {
            throw Exception('Missing DOB');
          }

          final admissionDateRaw = _getAny(row, ['Admission Date', 'admission_date']);
          final admissionDate = _tryParseDate(admissionDateRaw);
          if (admissionDateRaw != null && admissionDate == null) {
            throw Exception('Invalid Admission Date "$admissionDateRaw"');
          }
          final finalAdmissionDate = admissionDate ?? DateTime.now();

          final status = (_getAny(row, ['Status', 'status']) ?? 'active').toLowerCase();
          final enrolledFeesRaw = _getAny(row, ['Enrolled Fees', 'Fees', 'enrolled_fees']);
          final enrolledFees = enrolledFeesRaw == null || enrolledFeesRaw.trim().isEmpty
              ? 0.0
              : double.tryParse(enrolledFeesRaw);
          if (enrolledFeesRaw != null && enrolledFeesRaw.trim().isNotEmpty && enrolledFees == null) {
            throw Exception('Invalid Enrolled Fees "$enrolledFeesRaw"');
          }

          final guardianNameRaw = _getAny(row, [
            'Guardian Name',
            'Parent Name',
            'Parent/Guardian Name',
            'Guardian',
            'guardian_name',
          ]);
          final guardianPhoneRaw = _getAny(row, [
            'Guardian Phone',
            'Parent Phone',
            'Parent/Guardian Phone',
            'Guardian Contact',
            'guardian_phone',
          ]);

          // Guardian fields are required in the DB schema, but many CSVs omit them.
          // Default to safe placeholders to avoid hard-failing entire imports.
          final guardianName = (guardianNameRaw == null || guardianNameRaw.trim().isEmpty) ? 'Unknown' : guardianNameRaw.trim();
          final guardianPhone = (guardianPhoneRaw == null || guardianPhoneRaw.trim().isEmpty) ? '-' : guardianPhoneRaw.trim();

          final guardianEmail = _getAny(row, ['Guardian Email', 'guardian_email']);
          final guardianOccupation = _getAny(row, ['Guardian Occupation', 'guardian_occupation']);
          final guardianRelationship = _getAny(row, ['Guardian Relationship', 'Relationship', 'guardian_relationship']) ?? 'parent';
          final guardianAddress = _getAny(row, ['Guardian Address', 'guardian_address']);

          final address = _getAny(row, ['Address', 'address']);
          final phoneNumber = _getAny(row, ['Phone Number', 'Phone', 'phone_number']);
          final email = _getAny(row, ['Email', 'email']);

          Student? existing;
          if (rawStudentId != null && rawStudentId.trim().isNotEmpty) {
            existing = await (_database.select(_database.students)
                  ..where((t) => t.studentId.equals(rawStudentId.trim()))
                  ..limit(1))
                .getSingleOrNull();
          }
          if (existing == null && rawAdmissionNumber != null && rawAdmissionNumber.trim().isNotEmpty) {
            existing = await (_database.select(_database.students)
                  ..where((t) => t.admissionNumber.equals(rawAdmissionNumber.trim()))
                  ..limit(1))
                .getSingleOrNull();
          }

          if (existing == null) {
            final studentId = await _ensureUniqueStudentId(rawStudentId, seed: seed);
            final admissionNumber = await _ensureUniqueAdmissionNumber(rawAdmissionNumber, seed: seed);

            final studentCompanion = StudentsCompanion.insert(
              studentId: studentId,
              firstName: firstName.trim(),
              lastName: lastName.trim(),
              otherNames: Value(otherNames),
              gender: gender,
              dateOfBirth: dob,
              address: Value(address),
              phoneNumber: Value(phoneNumber),
              email: Value(email),
              guardianName: guardianName,
              guardianPhone: guardianPhone,
              guardianEmail: Value(guardianEmail),
              guardianOccupation: Value(guardianOccupation),
              guardianRelationship: guardianRelationship,
              guardianAddress: Value(guardianAddress),
              classId: Value(classId),
              admissionDate: finalAdmissionDate,
              admissionNumber: admissionNumber,
              enrolledFees: Value(enrolledFees ?? 0.0),
              status: Value(status),
              isActive: Value(status == 'active'),
            );

            final ensuredStudent = studentCompanion.remoteId.present
                ? studentCompanion
                : studentCompanion.copyWith(remoteId: Value<String?>(_uuidV4()));
            final studentLocalId = await _database.into(_database.students).insert(ensuredStudent);
            created++;

            await _ensureStudentRemoteId(studentLocalId);
            await _ensureHealthRecordExists(studentLocalId);
            await _bestEffortEnroll(studentId: studentLocalId, classId: classId);

            try {
              final inserted = await (_database.select(_database.students)..where((t) => t.id.equals(studentLocalId))).getSingle();
              await _sync?.enqueueOutboxOp(
                entityType: 'students',
                operation: 'insert',
                entityLocalId: studentLocalId,
                entityRemoteId: inserted.remoteId,
                payload: inserted.toJson(),
              );
            } catch (_) {
              // Keep local-only working.
            }
          } else {
            final existingStudent = existing;
            final desiredStudentId = rawStudentId != null && rawStudentId.trim().isNotEmpty
              ? rawStudentId.trim()
              : existingStudent.studentId;
            final desiredAdmission = rawAdmissionNumber != null && rawAdmissionNumber.trim().isNotEmpty
              ? rawAdmissionNumber.trim()
              : existingStudent.admissionNumber;

            if (desiredStudentId != existingStudent.studentId) {
              final conflict = await (_database.select(_database.students)
                    ..where((t) => t.studentId.equals(desiredStudentId) & t.id.isNotIn([existingStudent.id]))
                    ..limit(1))
                  .getSingleOrNull();
              if (conflict != null) {
                throw Exception('Student ID "$desiredStudentId" already exists');
              }
            }
            if (desiredAdmission != existingStudent.admissionNumber) {
              final conflict = await (_database.select(_database.students)
                    ..where((t) => t.admissionNumber.equals(desiredAdmission) & t.id.isNotIn([existingStudent.id]))
                    ..limit(1))
                  .getSingleOrNull();
              if (conflict != null) {
                throw Exception('Admission Number "$desiredAdmission" already exists');
              }
            }

            await (_database.update(_database.students)..where((t) => t.id.equals(existingStudent.id))).write(
              StudentsCompanion(
                studentId: Value(desiredStudentId),
                admissionNumber: Value(desiredAdmission),
                firstName: Value(firstName.trim()),
                lastName: Value(lastName.trim()),
                otherNames: Value(otherNames),
                gender: Value(gender),
                dateOfBirth: Value(dob),
                address: Value(address),
                phoneNumber: Value(phoneNumber),
                email: Value(email),
                guardianName: Value(guardianName),
                guardianPhone: Value(guardianPhone),
                guardianEmail: Value(guardianEmail),
                guardianOccupation: Value(guardianOccupation),
                guardianRelationship: Value(guardianRelationship),
                guardianAddress: Value(guardianAddress),
                classId: Value(classId),
                admissionDate: Value(finalAdmissionDate),
                enrolledFees: Value(enrolledFees ?? 0.0),
                status: Value(status),
                isActive: Value(status == 'active'),
                updatedAt: Value(DateTime.now()),
              ),
            );
            updated++;

            await _ensureStudentRemoteId(existingStudent.id);
            await _ensureHealthRecordExists(existingStudent.id);
            await _bestEffortEnroll(studentId: existingStudent.id, classId: classId);

            try {
              final updatedStudent = await (_database.select(_database.students)..where((t) => t.id.equals(existingStudent.id))).getSingle();
              await _sync?.enqueueOutboxOp(
                entityType: 'students',
                operation: 'update',
                entityLocalId: existingStudent.id,
                entityRemoteId: updatedStudent.remoteId,
                payload: updatedStudent.toJson(),
              );
            } catch (_) {
              // Keep local-only working.
            }
          }
        } catch (e) {
          errors.add('Row $rowNumber: $e');
        }
      }
    });

    return BulkStudentImportResult(
      requested: rows.length,
      created: created,
      updated: updated,
      errors: errors,
    );
  }

  Future<void> _bestEffortEnroll({required int studentId, required int? classId}) async {
    try {
      if (classId != null) {
        await _database.ensureStudentEnrolledInClassSubjects(studentId: studentId, classId: classId);
      }
    } catch (_) {
      // Best-effort; ignore.
    }
  }

  Future<void> _ensureHealthRecordExists(int studentLocalId) async {
    final existing = await (_database.select(_database.healthRecords)
          ..where((t) => t.studentId.equals(studentLocalId))
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) return;

    final companion = const HealthRecordsCompanion();
    final ensured = companion.remoteId.present ? companion : companion.copyWith(remoteId: Value<String?>(_uuidV4()));
    final healthId = await _database.into(_database.healthRecords).insert(
          ensured.copyWith(studentId: Value(studentLocalId)),
        );

    try {
      final insertedHealth = await (_database.select(_database.healthRecords)
            ..where((t) => t.id.equals(healthId)))
          .getSingle();
      final student = await (_database.select(_database.students)..where((t) => t.id.equals(studentLocalId))).getSingle();
      await _sync?.enqueueOutboxOp(
        entityType: 'health_records',
        operation: 'insert',
        entityLocalId: healthId,
        entityRemoteId: insertedHealth.remoteId,
        payload: {
          'remoteId': insertedHealth.remoteId,
          'studentRemoteId': student.remoteId,
          'bloodGroup': insertedHealth.bloodGroup,
          'allergies': insertedHealth.allergies,
          'vaccinations': insertedHealth.vaccinations,
          'medications': insertedHealth.medications,
          'physicalDisability': insertedHealth.physicalDisability,
          'emergencyInstructions': insertedHealth.emergencyInstructions,
        },
      );
    } catch (_) {
      // Keep local-only working.
    }
  }

  Future<BulkStudentActionResult> bulkDeactivateStudents(List<int> studentTableIds) async {
    if (studentTableIds.isEmpty) {
      return const BulkStudentActionResult(requested: 0, affected: 0, skippedStudentTableIds: [], errors: []);
    }

    final errors = <String>[];
    final existing = await (_database.select(_database.students)..where((t) => t.id.isIn(studentTableIds))).get();
    final existingIds = existing.map((s) => s.id).toSet();
    final missing = studentTableIds.where((id) => !existingIds.contains(id)).toList();
    for (final id in missing) {
      errors.add('Student id $id not found');
    }

    final now = DateTime.now();
    final affected = await (_database.update(_database.students)..where((t) => t.id.isIn(existingIds.toList()))).write(
      StudentsCompanion(
        isActive: const Value(false),
        status: const Value('inactive'),
        updatedAt: Value(now),
      ),
    );

    return BulkStudentActionResult(
      requested: studentTableIds.length,
      affected: affected,
      skippedStudentTableIds: const [],
      errors: errors,
    );
  }

  Future<BulkStudentActionResult> bulkDeleteStudents(List<int> studentTableIds) async {
    if (studentTableIds.isEmpty) {
      return const BulkStudentActionResult(requested: 0, affected: 0, skippedStudentTableIds: [], errors: []);
    }

    final skipped = <int>[];
    final errors = <String>[];
    var deleted = 0;

    await _database.transaction(() async {
      for (final id in studentTableIds) {
        final student = await (_database.select(_database.students)..where((t) => t.id.equals(id))..limit(1)).getSingleOrNull();
        if (student == null) {
          skipped.add(id);
          errors.add('Student id $id not found');
          continue;
        }

        final hasAttendance = await (_database.select(_database.attendanceRecords)
              ..where((t) => t.studentId.equals(id))
              ..limit(1))
            .getSingleOrNull();
        final hasGrades = await (_database.select(_database.studentGrades)
              ..where((t) => t.studentId.equals(id))
              ..limit(1))
            .getSingleOrNull();
        final hasTermResults = await (_database.select(_database.termResults)
              ..where((t) => t.studentId.equals(id))
              ..limit(1))
            .getSingleOrNull();
        final hasPayments = await (_database.select(_database.payments)
              ..where((t) => t.studentId.equals(id))
              ..limit(1))
            .getSingleOrNull();
        final hasParentAccounts = await (_database.select(_database.parentAccounts)
              ..where((t) => t.studentId.equals(id))
              ..limit(1))
            .getSingleOrNull();
        final hasParentMessages = await (_database.select(_database.parentMessages)
              ..where((t) => t.studentId.equals(id))
              ..limit(1))
            .getSingleOrNull();
        final hasReportSummaries = await (_database.select(_database.reportSummaries)
              ..where((t) => t.studentId.equals(id))
              ..limit(1))
            .getSingleOrNull();

        if (hasAttendance != null ||
            hasGrades != null ||
            hasTermResults != null ||
            hasPayments != null ||
            hasParentAccounts != null ||
            hasParentMessages != null ||
            hasReportSummaries != null) {
          skipped.add(id);
          errors.add('Student "${student.studentId}" cannot be deleted because they have linked records (attendance/grades/payments/reports/parent).');
          continue;
        }

        // Safe to delete student-owned tables first.
        await (_database.delete(_database.studentSubjectEnrollments)..where((t) => t.studentId.equals(id))).go();
        await (_database.delete(_database.healthRecords)..where((t) => t.studentId.equals(id))).go();
        await (_database.delete(_database.academicHistory)..where((t) => t.studentId.equals(id))).go();

        final removed = await (_database.delete(_database.students)..where((t) => t.id.equals(id))).go();
        if (removed > 0) deleted++;
      }
    });

    return BulkStudentActionResult(
      requested: studentTableIds.length,
      affected: deleted,
      skippedStudentTableIds: skipped,
      errors: errors,
    );
  }

  Future<Student?> _ensureStudentRemoteId(int id) async {
    final existing = await (_database.select(_database.students)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) return null;

    final current = existing.remoteId?.trim();
    if (current != null && current.isNotEmpty) return existing;

    final newRemoteId = _uuidV4();
    await (_database.update(_database.students)..where((t) => t.id.equals(id)))
      .write(StudentsCompanion(remoteId: Value<String?>(newRemoteId)));

    return (existing).copyWith(remoteId: Value<String?>(newRemoteId));
  }

  /// Get all students with optional search and filter
  Future<List<Student>> getAllStudents({
    String? searchQuery,
    String? statusFilter,
    int? classId,
  }) async {
    // Basic implementation - can be enhanced with complex queries
    final query = _database.select(_database.students);
    
    if (searchQuery != null && searchQuery.isNotEmpty) {
      query.where((t) => 
        t.firstName.contains(searchQuery) | 
        t.lastName.contains(searchQuery) | 
        t.studentId.contains(searchQuery) |
        t.admissionNumber.contains(searchQuery)
      );
    }
    
    if (statusFilter != null && statusFilter != 'all') {
      query.where((t) => t.status.equals(statusFilter));
    }

    if (classId != null) {
      query.where((t) => t.classId.equals(classId));
    }
    
    return await query.get();
  }

  /// Create a new student with full details (transactional)
  Future<int> admitStudent({
    required StudentsCompanion student,
    required HealthRecordsCompanion health,
    List<AcademicHistoryCompanion>? history,
  }) async {
    return await _database.transaction(() async {
      // 1. Insert student
      final ensuredStudent = student.remoteId.present
          ? student
          : student.copyWith(remoteId: Value<String?>(_uuidV4()));
      final studentId = await _database.into(_database.students).insert(ensuredStudent);

      // Auto-enroll in all offered class subjects.
      try {
        final classId = student.classId.present ? student.classId.value : null;
        if (classId != null) {
          await _database.ensureStudentEnrolledInClassSubjects(studentId: studentId, classId: classId);
        }
      } catch (_) {
        // ignore
      }

      // Ensure we have the inserted student row (with remoteId)
      final insertedStudent = await _ensureStudentRemoteId(studentId) ??
          await (_database.select(_database.students)..where((t) => t.id.equals(studentId))).getSingle();
      final studentRemoteId = insertedStudent.remoteId;
      
      // 2. Insert health records
      final ensuredHealth = health.remoteId.present
          ? health
          : health.copyWith(remoteId: Value<String?>(_uuidV4()));
      final healthId = await _database.into(_database.healthRecords).insert(
            ensuredHealth.copyWith(studentId: Value(studentId)),
          );

      // 2b. Enqueue outbox op for health record (best-effort)
      try {
        final insertedHealth = await (_database.select(_database.healthRecords)
              ..where((t) => t.id.equals(healthId)))
            .getSingle();
        await _sync?.enqueueOutboxOp(
          entityType: 'health_records',
          operation: 'insert',
          entityLocalId: healthId,
          entityRemoteId: insertedHealth.remoteId,
          payload: {
            'remoteId': insertedHealth.remoteId,
            'studentRemoteId': studentRemoteId,
            'bloodGroup': insertedHealth.bloodGroup,
            'allergies': insertedHealth.allergies,
            'vaccinations': insertedHealth.vaccinations,
            'medications': insertedHealth.medications,
            'physicalDisability': insertedHealth.physicalDisability,
            'emergencyInstructions': insertedHealth.emergencyInstructions,
          },
        );
      } catch (_) {
        // Keep local-only working.
      }
      
      // 3. Insert history
      if (history != null && history.isNotEmpty) {
        for (final record in history) {
          final ensuredHistory = record.remoteId.present
              ? record
              : record.copyWith(remoteId: Value<String?>(_uuidV4()));
          final historyId = await _database.into(_database.academicHistory).insert(
                ensuredHistory.copyWith(studentId: Value(studentId)),
              );

          try {
            final insertedHistory = await (_database.select(_database.academicHistory)
                  ..where((t) => t.id.equals(historyId)))
                .getSingle();
            await _sync?.enqueueOutboxOp(
              entityType: 'academic_history',
              operation: 'insert',
              entityLocalId: historyId,
              entityRemoteId: insertedHistory.remoteId,
              payload: {
                'remoteId': insertedHistory.remoteId,
                'studentRemoteId': studentRemoteId,
                'formerSchool': insertedHistory.formerSchool,
                'highestClassReached': insertedHistory.highestClassReached,
                'reasonForLeaving': insertedHistory.reasonForLeaving,
                'assessmentScores': insertedHistory.assessmentScores,
                'certificatesPath': insertedHistory.certificatesPath,
              },
            );
          } catch (_) {
            // Keep local-only working.
          }
        }
      }

      // 4. Enqueue outbox op (best-effort)
      try {
        final inserted = insertedStudent;

        await _sync?.enqueueOutboxOp(
          entityType: 'students',
          operation: 'insert',
          entityLocalId: studentId,
          entityRemoteId: inserted.remoteId,
          payload: inserted.toJson(),
        );
      } catch (_) {
        // Keep local-only working.
      }
      
      return studentId;
    });
  }

  /// Bulk admit students (transactional)
  Future<void> bulkAdmitStudents(List<Map<String, dynamic>> records) async {
    await _database.transaction(() async {
      for (final record in records) {
        final student = record['student'] as StudentsCompanion;
        final health = record['health'] as HealthRecordsCompanion;

        final ensuredStudent = student.remoteId.present
            ? student
          : student.copyWith(remoteId: Value<String?>(_uuidV4()));
        final studentId = await _database.into(_database.students).insert(ensuredStudent);

        final insertedStudent = await _ensureStudentRemoteId(studentId) ??
            await (_database.select(_database.students)..where((t) => t.id.equals(studentId))).getSingle();
        final studentRemoteId = insertedStudent.remoteId;

        final ensuredHealth = health.remoteId.present
            ? health
            : health.copyWith(remoteId: Value<String?>(_uuidV4()));
        final healthId = await _database.into(_database.healthRecords).insert(
              ensuredHealth.copyWith(studentId: Value(studentId)),
            );

        try {
          final insertedHealth = await (_database.select(_database.healthRecords)
                ..where((t) => t.id.equals(healthId)))
              .getSingle();
          await _sync?.enqueueOutboxOp(
            entityType: 'health_records',
            operation: 'insert',
            entityLocalId: healthId,
            entityRemoteId: insertedHealth.remoteId,
            payload: {
              'remoteId': insertedHealth.remoteId,
              'studentRemoteId': studentRemoteId,
              'bloodGroup': insertedHealth.bloodGroup,
              'allergies': insertedHealth.allergies,
              'vaccinations': insertedHealth.vaccinations,
              'medications': insertedHealth.medications,
              'physicalDisability': insertedHealth.physicalDisability,
              'emergencyInstructions': insertedHealth.emergencyInstructions,
            },
          );
        } catch (_) {
          // Keep local-only working.
        }

        try {
          final inserted = insertedStudent;
          await _sync?.enqueueOutboxOp(
            entityType: 'students',
            operation: 'insert',
            entityLocalId: studentId,
            entityRemoteId: inserted.remoteId,
            payload: inserted.toJson(),
          );
        } catch (_) {
          // Keep local-only working.
        }
      }
    });
  }

  /// Get full student profile
  Future<Map<String, dynamic>> getStudentProfile(int id) async {
    final student = await (_database.select(_database.students)..where((t) => t.id.equals(id))).getSingle();
    final health = await _database.getHealthRecordByStudentId(id);
    final history = await _database.getAcademicHistoryByStudentId(id);
    
    return {
      'student': student,
      'health': health,
      'history': history,
    };
  }

  Future<List<SchoolSubject>> getCurrentEnrolledSubjects(int studentId) async {
    return _database.getActiveSubjectsForStudent(studentId);
  }

  Future<List<SchoolSubject>> getOfferedSubjectsForStudentClass(int studentId) async {
    final classId = await _database.getStudentCurrentClassId(studentId);
    if (classId == null) return const <SchoolSubject>[];
    return _database.getOfferedSubjectsForClass(classId);
  }

  Future<void> updateStudentSubjectSelections({
    required int studentId,
    required Set<int> activeSubjectIds,
  }) async {
    final classId = await _database.getStudentCurrentClassId(studentId);
    if (classId == null) return;

    // Ensure default enrollment exists first.
    await _database.ensureStudentEnrolledInClassSubjects(studentId: studentId, classId: classId);

    final offered = await _database.getOfferedSubjectsForClass(classId);
    final offeredIds = offered.map((s) => s.id).toSet();

    await _database.batch((b) {
      for (final subjectId in offeredIds) {
        final shouldBeActive = activeSubjectIds.contains(subjectId);
        b.customStatement(
          'INSERT INTO student_subject_enrollments (student_id, class_id, subject_id, is_active, created_at, updated_at, is_dirty) '
          'VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 0) '
          'ON CONFLICT(student_id, class_id, subject_id) DO UPDATE SET is_active = excluded.is_active, updated_at = CURRENT_TIMESTAMP',
          [studentId, classId, subjectId, shouldBeActive ? 1 : 0],
        );
      }
    });
  }

  /// Update an existing student
  Future<bool> updateStudent(StudentsCompanion student) async {
    final id = student.id.value;
    final before = await (_database.select(_database.students)..where((t) => t.id.equals(id))).getSingleOrNull();

    final ok = await _database.update(_database.students).replace(student);

    // If classId changed, deactivate old enrollments and create new ones.
    try {
      final oldClassId = before?.classId;
      final newClassId = student.classId.present ? student.classId.value : before?.classId;
      if (before != null && oldClassId != newClassId) {
        await _database.syncStudentEnrollmentsAfterClassChange(
          studentId: id,
          oldClassId: oldClassId,
          newClassId: newClassId,
        );
      } else if (newClassId != null) {
        // Ensure enrollments exist even if class didn't change.
        await _database.ensureStudentEnrolledInClassSubjects(studentId: id, classId: newClassId);
      }
    } catch (_) {
      // ignore
    }

    try {
      final updated = await _ensureStudentRemoteId(id) ??
          await (_database.select(_database.students)
                ..where((t) => t.id.equals(id)))
              .getSingle();
      await _sync?.enqueueOutboxOp(
        entityType: 'students',
        operation: 'update',
        entityLocalId: id,
        entityRemoteId: updated.remoteId,
        payload: updated.toJson(),
      );
    } catch (_) {
      // Ignore (missing id / row).
    }

    return ok;
  }

  String? _textOrNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  /// Create or update a student's health record and enqueue outbox ops (best-effort).
  Future<int?> upsertHealthRecordForStudent({
    required int studentLocalId,
    String? bloodGroup,
    String? allergies,
    String? medications,
    String? vaccinations,
    String? physicalDisability,
    String? emergencyInstructions,
  }) async {
    final ensuredStudent = await _ensureStudentRemoteId(studentLocalId) ??
        await (_database.select(_database.students)..where((t) => t.id.equals(studentLocalId))).getSingleOrNull();
    if (ensuredStudent == null) return null;

    final studentRemoteId = ensuredStudent.remoteId;
    final existing = await _database.getHealthRecordByStudentId(studentLocalId);

    if (existing == null) {
      final newRemoteId = _uuidV4();
      final id = await _database.into(_database.healthRecords).insert(
            HealthRecordsCompanion(
              studentId: Value(studentLocalId),
              bloodGroup: Value(_textOrNull(bloodGroup)),
              allergies: Value(_textOrNull(allergies)),
              medications: Value(_textOrNull(medications)),
              vaccinations: Value(_textOrNull(vaccinations)),
              physicalDisability: Value(_textOrNull(physicalDisability)),
              emergencyInstructions: Value(_textOrNull(emergencyInstructions)),
              remoteId: Value<String?>(newRemoteId),
            ),
          );

      try {
        final inserted = await (_database.select(_database.healthRecords)..where((t) => t.id.equals(id))).getSingle();
        await _sync?.enqueueOutboxOp(
          entityType: 'health_records',
          operation: 'insert',
          entityLocalId: id,
          entityRemoteId: inserted.remoteId,
          payload: {
            'remoteId': inserted.remoteId,
            'studentRemoteId': studentRemoteId,
            'bloodGroup': inserted.bloodGroup,
            'allergies': inserted.allergies,
            'vaccinations': inserted.vaccinations,
            'medications': inserted.medications,
            'physicalDisability': inserted.physicalDisability,
            'emergencyInstructions': inserted.emergencyInstructions,
          },
        );
      } catch (_) {
        // Keep local-only working.
      }

      return id;
    }

    final ensuredRemoteId = (existing.remoteId?.trim().isNotEmpty ?? false) ? existing.remoteId! : _uuidV4();

    await (_database.update(_database.healthRecords)..where((t) => t.id.equals(existing.id))).write(
      HealthRecordsCompanion(
        bloodGroup: Value(_textOrNull(bloodGroup)),
        allergies: Value(_textOrNull(allergies)),
        medications: Value(_textOrNull(medications)),
        vaccinations: Value(_textOrNull(vaccinations)),
        physicalDisability: Value(_textOrNull(physicalDisability)),
        emergencyInstructions: Value(_textOrNull(emergencyInstructions)),
        remoteId: Value<String?>(ensuredRemoteId),
      ),
    );

    try {
      final updated = await (_database.select(_database.healthRecords)..where((t) => t.id.equals(existing.id))).getSingle();
      await _sync?.enqueueOutboxOp(
        entityType: 'health_records',
        operation: 'update',
        entityLocalId: existing.id,
        entityRemoteId: updated.remoteId,
        payload: {
          'remoteId': updated.remoteId,
          'studentRemoteId': studentRemoteId,
          'bloodGroup': updated.bloodGroup,
          'allergies': updated.allergies,
          'vaccinations': updated.vaccinations,
          'medications': updated.medications,
          'physicalDisability': updated.physicalDisability,
          'emergencyInstructions': updated.emergencyInstructions,
        },
      );
    } catch (_) {
      // Keep local-only working.
    }

    return existing.id;
  }

  /// Delete a student's health record (with outbox enqueue).
  Future<int> deleteHealthRecordForStudent(int studentLocalId) async {
    final ensuredStudent = await _ensureStudentRemoteId(studentLocalId) ??
        await (_database.select(_database.students)
              ..where((t) => t.id.equals(studentLocalId)))
            .getSingleOrNull();
    final studentRemoteId = ensuredStudent?.remoteId;

    final existing = await _database.getHealthRecordByStudentId(studentLocalId);
    if (existing == null) return 0;

    final ensuredRemoteId = (existing.remoteId?.trim().isNotEmpty ?? false) ? existing.remoteId! : _uuidV4();
    if (!(existing.remoteId?.trim().isNotEmpty ?? false)) {
      try {
        await (_database.update(_database.healthRecords)..where((t) => t.id.equals(existing.id))).write(
          HealthRecordsCompanion(remoteId: Value<String?>(ensuredRemoteId)),
        );
      } catch (_) {
        // ignore
      }
    }

    final affected = await (_database.delete(_database.healthRecords)..where((t) => t.id.equals(existing.id))).go();

    try {
      await _sync?.enqueueOutboxOp(
        entityType: 'health_records',
        operation: 'delete',
        entityLocalId: existing.id,
        entityRemoteId: ensuredRemoteId,
        payload: {
          'remoteId': ensuredRemoteId,
          'studentRemoteId': studentRemoteId,
        },
      );
    } catch (_) {
      // Keep local-only working.
    }

    return affected;
  }

  /// Add a previous-school record for a student (with outbox enqueue).
  Future<int> addAcademicHistoryForStudent({
    required int studentLocalId,
    required String formerSchool,
    String? highestClassReached,
    String? reasonForLeaving,
    String? assessmentScores,
    String? certificatesPath,
  }) async {
    final ensuredStudent = await _ensureStudentRemoteId(studentLocalId) ??
        await (_database.select(_database.students)..where((t) => t.id.equals(studentLocalId))).getSingle();
    final studentRemoteId = ensuredStudent.remoteId;

    final newRemoteId = _uuidV4();
    final id = await _database.into(_database.academicHistory).insert(
          AcademicHistoryCompanion(
            studentId: Value(studentLocalId),
            formerSchool: Value(formerSchool.trim()),
            highestClassReached: Value(_textOrNull(highestClassReached)),
            reasonForLeaving: Value(_textOrNull(reasonForLeaving)),
            assessmentScores: Value(_textOrNull(assessmentScores)),
            certificatesPath: Value(_textOrNull(certificatesPath)),
            remoteId: Value<String?>(newRemoteId),
          ),
        );

    try {
      final inserted = await (_database.select(_database.academicHistory)..where((t) => t.id.equals(id))).getSingle();
      await _sync?.enqueueOutboxOp(
        entityType: 'academic_history',
        operation: 'insert',
        entityLocalId: id,
        entityRemoteId: inserted.remoteId,
        payload: {
          'remoteId': inserted.remoteId,
          'studentRemoteId': studentRemoteId,
          'formerSchool': inserted.formerSchool,
          'highestClassReached': inserted.highestClassReached,
          'reasonForLeaving': inserted.reasonForLeaving,
          'assessmentScores': inserted.assessmentScores,
          'certificatesPath': inserted.certificatesPath,
        },
      );
    } catch (_) {
      // Keep local-only working.
    }

    return id;
  }

  /// Update a previous-school record (with outbox enqueue).
  Future<bool> updateAcademicHistory({
    required AcademicHistoryData existing,
    required String formerSchool,
    String? highestClassReached,
    String? reasonForLeaving,
    String? assessmentScores,
    String? certificatesPath,
  }) async {
    final ensuredStudent = await _ensureStudentRemoteId(existing.studentId) ??
        await (_database.select(_database.students)..where((t) => t.id.equals(existing.studentId))).getSingleOrNull();
    final studentRemoteId = ensuredStudent?.remoteId;

    final ensuredRemoteId = (existing.remoteId?.trim().isNotEmpty ?? false) ? existing.remoteId! : _uuidV4();

    final affected = await (_database.update(_database.academicHistory)..where((t) => t.id.equals(existing.id))).write(
      AcademicHistoryCompanion(
        formerSchool: Value(formerSchool.trim()),
        highestClassReached: Value(_textOrNull(highestClassReached)),
        reasonForLeaving: Value(_textOrNull(reasonForLeaving)),
        assessmentScores: Value(_textOrNull(assessmentScores)),
        certificatesPath: Value(_textOrNull(certificatesPath)),
        remoteId: Value<String?>(ensuredRemoteId),
      ),
    );

    if (affected <= 0) return false;

    try {
      final updated = await (_database.select(_database.academicHistory)..where((t) => t.id.equals(existing.id))).getSingle();
      await _sync?.enqueueOutboxOp(
        entityType: 'academic_history',
        operation: 'update',
        entityLocalId: updated.id,
        entityRemoteId: updated.remoteId,
        payload: {
          'remoteId': updated.remoteId,
          'studentRemoteId': studentRemoteId,
          'formerSchool': updated.formerSchool,
          'highestClassReached': updated.highestClassReached,
          'reasonForLeaving': updated.reasonForLeaving,
          'assessmentScores': updated.assessmentScores,
          'certificatesPath': updated.certificatesPath,
        },
      );
    } catch (_) {
      // Keep local-only working.
    }

    return true;
  }

  /// Delete a previous-school record (with outbox enqueue).
  Future<int> deleteAcademicHistory(AcademicHistoryData existing) async {
    final ensuredStudent = await _ensureStudentRemoteId(existing.studentId) ??
        await (_database.select(_database.students)..where((t) => t.id.equals(existing.studentId))).getSingleOrNull();
    final studentRemoteId = ensuredStudent?.remoteId;

    // Ensure the record has a remoteId so other devices can match the delete.
    final ensuredRemoteId = (existing.remoteId?.trim().isNotEmpty ?? false) ? existing.remoteId! : _uuidV4();
    if (!(existing.remoteId?.trim().isNotEmpty ?? false)) {
      try {
        await (_database.update(_database.academicHistory)..where((t) => t.id.equals(existing.id))).write(
          AcademicHistoryCompanion(remoteId: Value<String?>(ensuredRemoteId)),
        );
      } catch (_) {
        // ignore
      }
    }

    final affected = await (_database.delete(_database.academicHistory)..where((t) => t.id.equals(existing.id))).go();

    try {
      await _sync?.enqueueOutboxOp(
        entityType: 'academic_history',
        operation: 'delete',
        entityLocalId: existing.id,
        entityRemoteId: ensuredRemoteId,
        payload: {
          'remoteId': ensuredRemoteId,
          'studentRemoteId': studentRemoteId,
        },
      );
    } catch (_) {
      // Keep local-only working.
    }

    return affected;
  }

  /// Delete a student (soft delete by setting isActive to false)
  Future<int> deleteStudent(int id) async {
    Student? before;
    try {
      before = await _ensureStudentRemoteId(id) ??
          await (_database.select(_database.students)..where((t) => t.id.equals(id))).getSingleOrNull();
    } catch (_) {
      before = null;
    }

    final affected = await (_database.update(_database.students)
      ..where((t) => t.id.equals(id)))
      .write(const StudentsCompanion(isActive: Value(false), status: Value('inactive')));

    try {
      await _sync?.enqueueOutboxOp(
        entityType: 'students',
        operation: 'delete',
        entityLocalId: id,
        entityRemoteId: before?.remoteId,
        payload: {
          'remoteId': before?.remoteId,
          'studentId': before?.studentId,
          'admissionNumber': before?.admissionNumber,
        },
      );
    } catch (_) {
      // Keep local-only working.
    }

    return affected;
  }

  /// Get student count for cards
  Future<int> getStudentCount() async {
    final countExp = _database.students.id.count();
    final query = _database.selectOnly(_database.students)..addColumns([countExp]);
    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }
}
