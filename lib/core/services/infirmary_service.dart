import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:ghanaclass_school_management/core/database/app_database.dart';

class InfirmaryVisitWithStudent {
  final InfirmaryVisit visit;
  final Student student;

  const InfirmaryVisitWithStudent({required this.visit, required this.student});
}

class StudentAllergyAlertWithStudent {
  final Student student;
  final StudentAllergyAlert alert;

  const StudentAllergyAlertWithStudent({required this.student, required this.alert});
}

class StudentChronicConditionWithStudent {
  final Student student;
  final StudentChronicCondition condition;

  const StudentChronicConditionWithStudent({required this.student, required this.condition});
}

class StudentMedicationWithStudent {
  final Student student;
  final StudentMedication medication;

  const StudentMedicationWithStudent({required this.student, required this.medication});
}

class MedicationAdministrationLogWithStudentAndMedication {
  final Student student;
  final StudentMedication medication;
  final MedicationAdministrationLog log;

  const MedicationAdministrationLogWithStudentAndMedication({
    required this.student,
    required this.medication,
    required this.log,
  });
}

class StudentImmunizationWithStudent {
  final Student student;
  final StudentImmunization immunization;

  const StudentImmunizationWithStudent({required this.student, required this.immunization});
}

class StudentCheckupWithStudent {
  final Student student;
  final StudentCheckup checkup;

  const StudentCheckupWithStudent({required this.student, required this.checkup});
}

class InfirmaryService {
  final AppDatabase _db;

  InfirmaryService(this._db);

  Value<String> _textValueOrAbsent(String? text) {
    final v = text?.trim();
    if (v == null || v.isEmpty) return const Value.absent();
    return Value(v);
  }

  // -------- Students --------

  Stream<List<Student>> watchStudents({String? query}) {
    final q = _db.select(_db.students);

    final trimmed = query?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      final like = '%$trimmed%';
      q.where(
        (t) =>
            t.firstName.like(like) |
            t.lastName.like(like) |
            t.otherNames.like(like) |
            t.studentId.like(like),
      );
    }

    q.orderBy([
      (t) => OrderingTerm(expression: t.lastName),
      (t) => OrderingTerm(expression: t.firstName),
    ]);

    return q.watch();
  }

  Stream<HealthRecord?> watchHealthRecordForStudent(int studentId) {
    final q = _db.select(_db.healthRecords)..where((t) => t.studentId.equals(studentId));
    return q.watchSingleOrNull();
  }

  // -------- Emergency contacts / physician --------

  Stream<List<StudentEmergencyContact>> watchEmergencyContacts(int studentId) {
    final q = _db.select(_db.studentEmergencyContacts)..where((t) => t.studentId.equals(studentId));
    q.orderBy([(t) => OrderingTerm(expression: t.isPrimary, mode: OrderingMode.desc)]);
    return q.watch();
  }

  Future<int> addEmergencyContact({
    required int studentId,
    required String name,
    required String relationship,
    required String phoneNumber,
    bool isPrimary = false,
    String? notes,
  }) async {
    return _db.into(_db.studentEmergencyContacts).insert(
          StudentEmergencyContactsCompanion.insert(
            studentId: studentId,
            name: name.trim(),
            relationship: relationship.trim(),
            phoneNumber: phoneNumber.trim(),
            isPrimary: Value(isPrimary),
            notes: Value(notes?.trim().isEmpty ?? true ? null : notes!.trim()),
          ),
        );
  }

  Future<int> setPrimaryEmergencyContact({
    required int studentId,
    required int contactId,
  }) async {
    await (_db.update(_db.studentEmergencyContacts)..where((t) => t.studentId.equals(studentId))).write(
      const StudentEmergencyContactsCompanion(isPrimary: Value(false)),
    );

    return (_db.update(_db.studentEmergencyContacts)..where((t) => t.id.equals(contactId))).write(
      const StudentEmergencyContactsCompanion(isPrimary: Value(true)),
    );
  }

  Stream<StudentPhysicianDetail?> watchPhysicianDetails(int studentId) {
    final q = _db.select(_db.studentPhysicianDetails)..where((t) => t.studentId.equals(studentId));
    return q.watchSingleOrNull();
  }

  Future<void> upsertPhysicianDetails({
    required int studentId,
    String? physicianName,
    String? phoneNumber,
    String? facilityName,
    String? notes,
  }) async {
    await _db.into(_db.studentPhysicianDetails).insertOnConflictUpdate(
          StudentPhysicianDetailsCompanion.insert(
            studentId: studentId,
            physicianName: Value(_textOrNull(physicianName)),
            phoneNumber: Value(_textOrNull(phoneNumber)),
            facilityName: Value(_textOrNull(facilityName)),
            notes: Value(_textOrNull(notes)),
          ),
        );
  }

  // -------- Vitals --------

  Stream<List<StudentVitalsLog>> watchVitalsLogs(int studentId) {
    final q = _db.select(_db.studentVitalsLogs)..where((t) => t.studentId.equals(studentId));
    q.orderBy([(t) => OrderingTerm(expression: t.measuredAt, mode: OrderingMode.desc)]);
    return q.watch();
  }

  Future<int> addVitalsLog({
    required int studentId,
    DateTime? measuredAt,
    double? heightCm,
    double? weightKg,
    double? temperatureC,
    String? notes,
    int? recordedByUserId,
  }) async {
    final bmi = (heightCm != null && weightKg != null && heightCm > 0)
        ? weightKg / ((heightCm / 100) * (heightCm / 100))
        : null;

    return _db.into(_db.studentVitalsLogs).insert(
          StudentVitalsLogsCompanion.insert(
            studentId: studentId,
            measuredAt: Value(measuredAt ?? DateTime.now()),
            heightCm: Value(heightCm),
            weightKg: Value(weightKg),
            bmi: Value(bmi),
            temperatureC: Value(temperatureC),
            notes: Value(_textOrNull(notes)),
            recordedByUserId: Value(recordedByUserId),
          ),
        );
  }

  // -------- Documents --------

  Stream<List<StudentHealthDocument>> watchDocuments(int studentId) {
    final q = _db.select(_db.studentHealthDocuments)..where((t) => t.studentId.equals(studentId));
    q.orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]);
    return q.watch();
  }

  Future<int> addDocumentFromFile({
    required int studentId,
    required String sourcePath,
    required String title,
    String documentType = 'other',
    String? notes,
    int? uploadedByUserId,
  }) async {
    final destPath = await _copyIntoAppDocs(sourcePath: sourcePath, studentId: studentId);
    return _db.into(_db.studentHealthDocuments).insert(
          StudentHealthDocumentsCompanion.insert(
            studentId: studentId,
            documentType: Value(documentType.trim().isEmpty ? 'other' : documentType.trim()),
            title: title.trim(),
            localPath: destPath,
            notes: Value(_textOrNull(notes)),
            uploadedByUserId: Value(uploadedByUserId),
          ),
        );
  }

  Future<int> deleteDocument(int documentId) async {
    final doc = await (_db.select(_db.studentHealthDocuments)..where((t) => t.id.equals(documentId))).getSingleOrNull();
    final affected = await (_db.delete(_db.studentHealthDocuments)..where((t) => t.id.equals(documentId))).go();

    if (doc != null) {
      try {
        final f = File(doc.localPath);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {
        // Best-effort.
      }
    }

    return affected;
  }

  Future<String> _copyIntoAppDocs({
    required String sourcePath,
    required int studentId,
  }) async {
    final src = File(sourcePath);
    final ext = p.extension(sourcePath);
    final safeExt = ext.isEmpty ? '.bin' : ext;

    final dir = await getApplicationSupportDirectory();
    final destDir = Directory(p.join(dir.path, 'infirmary', 'students', '$studentId'));
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    final fileName = 'doc_${DateTime.now().millisecondsSinceEpoch}$safeExt';
    final destPath = p.join(destDir.path, fileName);
    await src.copy(destPath);
    return destPath;
  }

  // -------- Allergy / risk alerts --------

  Stream<List<StudentAllergyAlert>> watchAllergyAlerts(int studentId) {
    final q = _db.select(_db.studentAllergyAlerts)..where((t) => t.studentId.equals(studentId));
    q.orderBy([(t) => OrderingTerm(expression: t.isActive, mode: OrderingMode.desc)]);
    return q.watch();
  }

  Stream<List<StudentAllergyAlertWithStudent>> watchActiveAllergyAlertsWithStudent() {
    final alerts = _db.studentAllergyAlerts;
    final students = _db.students;

    final q = _db.select(alerts).join([
      innerJoin(students, students.id.equalsExp(alerts.studentId)),
    ]);

    q.where(alerts.isActive.equals(true));
    q.orderBy([
      OrderingTerm.desc(alerts.severity),
      OrderingTerm.asc(students.lastName),
      OrderingTerm.asc(students.firstName),
      OrderingTerm.desc(alerts.createdAt),
    ]);

    return q.watch().map(
          (rows) => rows
              .map(
                (r) => StudentAllergyAlertWithStudent(
                  student: r.readTable(students),
                  alert: r.readTable(alerts),
                ),
              )
              .toList(growable: false),
        );
  }

  Future<int> addAllergyAlert({
    required int studentId,
    required String description,
    String allergyType = 'other',
    String severity = 'medium',
    String? triggers,
  }) async {
    return _db.into(_db.studentAllergyAlerts).insert(
          StudentAllergyAlertsCompanion.insert(
            studentId: studentId,
            allergyType: Value(allergyType.trim().isEmpty ? 'other' : allergyType.trim()),
            description: description.trim(),
            severity: Value(severity.trim().isEmpty ? 'medium' : severity.trim()),
            triggers: Value(_textOrNull(triggers)),
          ),
        );
  }

  Future<int> setAllergyAlertActive({
    required int alertId,
    required bool isActive,
  }) async {
    return (_db.update(_db.studentAllergyAlerts)..where((t) => t.id.equals(alertId))).write(
      StudentAllergyAlertsCompanion(isActive: Value(isActive)),
    );
  }

  Stream<List<StudentChronicCondition>> watchChronicConditions(int studentId) {
    final q = _db.select(_db.studentChronicConditions)..where((t) => t.studentId.equals(studentId));
    q.orderBy([(t) => OrderingTerm(expression: t.isActive, mode: OrderingMode.desc)]);
    return q.watch();
  }

  Stream<List<StudentChronicConditionWithStudent>> watchActiveChronicConditionsWithStudent() {
    final conditions = _db.studentChronicConditions;
    final students = _db.students;

    final q = _db.select(conditions).join([
      innerJoin(students, students.id.equalsExp(conditions.studentId)),
    ]);

    q.where(conditions.isActive.equals(true));
    q.orderBy([
      OrderingTerm.asc(students.lastName),
      OrderingTerm.asc(students.firstName),
      OrderingTerm.desc(conditions.createdAt),
    ]);

    return q.watch().map(
          (rows) => rows
              .map(
                (r) => StudentChronicConditionWithStudent(
                  student: r.readTable(students),
                  condition: r.readTable(conditions),
                ),
              )
              .toList(growable: false),
        );
  }

  Future<int> addChronicCondition({
    required int studentId,
    required String conditionName,
    String? notes,
  }) async {
    return _db.into(_db.studentChronicConditions).insert(
          StudentChronicConditionsCompanion.insert(
            studentId: studentId,
            conditionName: conditionName.trim(),
            notes: Value(_textOrNull(notes)),
          ),
        );
  }

  Future<int> setChronicConditionActive({
    required int conditionId,
    required bool isActive,
  }) async {
    return (_db.update(_db.studentChronicConditions)..where((t) => t.id.equals(conditionId))).write(
      StudentChronicConditionsCompanion(isActive: Value(isActive)),
    );
  }

  // -------- Visits / interventions --------

  Stream<List<InfirmaryVisit>> watchVisits({DateTime? from, DateTime? to}) {
    final q = _db.select(_db.infirmaryVisits);

    if (from != null) {
      q.where((t) => t.timeIn.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      q.where((t) => t.timeIn.isSmallerOrEqualValue(to));
    }

    q.orderBy([(t) => OrderingTerm(expression: t.timeIn, mode: OrderingMode.desc)]);
    return q.watch();
  }

  Stream<List<InfirmaryVisitWithStudent>> watchVisitsWithStudent({DateTime? from, DateTime? to}) {
    final visits = _db.infirmaryVisits;
    final students = _db.students;

    final q = _db.select(visits).join([
      innerJoin(students, students.id.equalsExp(visits.studentId)),
    ]);

    if (from != null) {
      q.where(visits.timeIn.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      q.where(visits.timeIn.isSmallerOrEqualValue(to));
    }

    q.orderBy([OrderingTerm.desc(visits.timeIn)]);

    return q.watch().map(
          (rows) => rows
              .map(
                (r) => InfirmaryVisitWithStudent(
                  visit: r.readTable(visits),
                  student: r.readTable(students),
                ),
              )
              .toList(growable: false),
        );
  }

  Stream<List<InfirmaryVisit>> watchVisitsForStudent(int studentId) {
    final q = _db.select(_db.infirmaryVisits)..where((t) => t.studentId.equals(studentId));
    q.orderBy([(t) => OrderingTerm(expression: t.timeIn, mode: OrderingMode.desc)]);
    return q.watch();
  }

  Future<int> recordVisit({
    required int studentId,
    required String reason,
    String category = 'checkup',
    String? symptoms,
    String? treatmentProvided,
    String? outcome,
    DateTime? timeIn,
    DateTime? timeOut,
    bool sentHome = false,
    bool referredToHospital = false,
    String? referralNotes,
    String? nurseNotes,
    int? recordedByUserId,
    bool notifyParent = false,
  }) async {
    final id = await _db.into(_db.infirmaryVisits).insert(
          InfirmaryVisitsCompanion.insert(
            studentId: studentId,
            category: Value(category.trim().isEmpty ? 'checkup' : category.trim()),
            reason: reason.trim(),
            symptoms: Value(_textOrNull(symptoms)),
            treatmentProvided: Value(_textOrNull(treatmentProvided)),
            outcome: Value(_textOrNull(outcome)),
            timeIn: Value(timeIn ?? DateTime.now()),
            timeOut: Value(timeOut),
            sentHome: Value(sentHome),
            referredToHospital: Value(referredToHospital),
            referralNotes: Value(_textOrNull(referralNotes)),
            nurseNotes: Value(_textOrNull(nurseNotes)),
            recordedByUserId: Value(recordedByUserId),
            updatedAt: Value(DateTime.now()),
          ),
        );

    if (notifyParent) {
      await _queueParentVisitSms(studentId: studentId, visitId: id, createdByUserId: recordedByUserId);
    }

    return id;
  }

  Future<int> updateVisit({
    required int visitId,
    String? category,
    String? reason,
    String? symptoms,
    String? treatmentProvided,
    String? outcome,
    DateTime? timeOut,
    bool? sentHome,
    bool? referredToHospital,
    String? referralNotes,
    String? nurseNotes,
  }) async {
    return (_db.update(_db.infirmaryVisits)..where((t) => t.id.equals(visitId))).write(
      InfirmaryVisitsCompanion(
        category: _textValueOrAbsent(category),
        reason: _textValueOrAbsent(reason),
        symptoms: Value(_textOrNull(symptoms)),
        treatmentProvided: Value(_textOrNull(treatmentProvided)),
        outcome: Value(_textOrNull(outcome)),
        timeOut: Value(timeOut),
        sentHome: sentHome == null ? const Value.absent() : Value(sentHome),
        referredToHospital: referredToHospital == null ? const Value.absent() : Value(referredToHospital),
        referralNotes: Value(_textOrNull(referralNotes)),
        nurseNotes: Value(_textOrNull(nurseNotes)),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> _queueParentVisitSms({
    required int studentId,
    required int visitId,
    required int? createdByUserId,
  }) async {
    final parentId = await _parentAccountIdForStudent(studentId);
    if (parentId == null) return;

    final student = await (_db.select(_db.students)..where((s) => s.id.equals(studentId))).getSingleOrNull();
    final visit = await (_db.select(_db.infirmaryVisits)..where((v) => v.id.equals(visitId))).getSingleOrNull();
    if (student == null || visit == null) return;

    final sentHomeSuffix = visit.sentHome ? ' Sent home.' : '';
    final message =
      '${student.firstName} ${student.lastName} visited the infirmary for ${visit.reason}.$sentHomeSuffix';

    await _db.into(_db.notifications).insert(
          NotificationsCompanion.insert(
            recipientId: Value(parentId),
            recipientType: 'parent',
            channel: 'sms',
            subject: const Value('Infirmary Visit'),
            message: message,
            status: 'pending',
            externalId: const Value.absent(),
            sentAt: const Value.absent(),
            createdBy: createdByUserId ?? 1,
          ),
        );
  }

  Future<int?> _parentAccountIdForStudent(int studentId) async {
    final q = _db.select(_db.parentAccounts)..where((p) => p.studentId.equals(studentId) & p.isActive.equals(true));
    final parent = await q.getSingleOrNull();
    return parent?.id;
  }

  // -------- Medications --------

  Stream<List<StudentMedicationWithStudent>> watchMedicationsWithStudent({bool activeOnly = true}) {
    final meds = _db.studentMedications;
    final students = _db.students;

    final q = _db.select(meds).join([
      innerJoin(students, students.id.equalsExp(meds.studentId)),
    ]);

    if (activeOnly) {
      q.where(meds.isActive.equals(true));
    }

    q.orderBy([
      OrderingTerm.asc(students.lastName),
      OrderingTerm.asc(students.firstName),
      OrderingTerm.desc(meds.isActive),
      OrderingTerm.asc(meds.medicationName),
    ]);

    return q.watch().map(
          (rows) => rows
              .map(
                (r) => StudentMedicationWithStudent(
                  student: r.readTable(students),
                  medication: r.readTable(meds),
                ),
              )
              .toList(growable: false),
        );
  }

  /// filter: 'all' | 'given' | 'missed' | 'held'
  Stream<List<MedicationAdministrationLogWithStudentAndMedication>> watchMedicationAdministrationLogsWithStudent({
    String filter = 'all',
  }) {
    final logs = _db.medicationAdministrationLogs;
    final meds = _db.studentMedications;
    final students = _db.students;

    final q = _db.select(logs).join([
      innerJoin(meds, meds.id.equalsExp(logs.studentMedicationId)),
      innerJoin(students, students.id.equalsExp(meds.studentId)),
    ]);

    final f = filter.trim().isEmpty ? 'all' : filter.trim();
    if (f != 'all') {
      q.where(logs.status.equals(f));
    }

    q.orderBy([
      OrderingTerm.desc(logs.administeredAt),
      OrderingTerm.asc(students.lastName),
      OrderingTerm.asc(students.firstName),
      OrderingTerm.asc(meds.medicationName),
    ]);

    return q.watch().map(
          (rows) => rows
              .map(
                (r) => MedicationAdministrationLogWithStudentAndMedication(
                  student: r.readTable(students),
                  medication: r.readTable(meds),
                  log: r.readTable(logs),
                ),
              )
              .toList(growable: false),
        );
  }

  Stream<List<StudentMedication>> watchMedicationsForStudent(int studentId) {
    final q = _db.select(_db.studentMedications)..where((t) => t.studentId.equals(studentId));
    q.orderBy([(t) => OrderingTerm(expression: t.isActive, mode: OrderingMode.desc)]);
    return q.watch();
  }

  Future<int> addMedication({
    required int studentId,
    required String medicationName,
    String? dosage,
    String? schedule,
    String? instructions,
    DateTime? startDate,
    DateTime? endDate,
    bool requiresConsent = false,
    int? consentDocumentId,
  }) async {
    return _db.into(_db.studentMedications).insert(
          StudentMedicationsCompanion.insert(
            studentId: studentId,
            medicationName: medicationName.trim(),
            dosage: Value(_textOrNull(dosage)),
            schedule: Value(_textOrNull(schedule)),
            instructions: Value(_textOrNull(instructions)),
            startDate: Value(startDate),
            endDate: Value(endDate),
            requiresConsent: Value(requiresConsent),
            consentDocumentId: Value(consentDocumentId),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  Future<int> setMedicationActive({
    required int medicationId,
    required bool isActive,
  }) async {
    return (_db.update(_db.studentMedications)..where((t) => t.id.equals(medicationId))).write(
      StudentMedicationsCompanion(isActive: Value(isActive), updatedAt: Value(DateTime.now())),
    );
  }

  Stream<List<MedicationAdministrationLog>> watchAdministrationLogsForMedication(int medicationId) {
    final q = _db.select(_db.medicationAdministrationLogs)
      ..where((t) => t.studentMedicationId.equals(medicationId));
    q.orderBy([(t) => OrderingTerm(expression: t.administeredAt, mode: OrderingMode.desc)]);
    return q.watch();
  }

  Future<int> logMedicationAdministration({
    required int medicationId,
    String status = 'given',
    DateTime? administeredAt,
    int? administeredByUserId,
    int? relatedVisitId,
    String? notes,
    bool notifyParent = false,
  }) async {
    final id = await _db.into(_db.medicationAdministrationLogs).insert(
          MedicationAdministrationLogsCompanion.insert(
            studentMedicationId: medicationId,
            status: Value(status.trim().isEmpty ? 'given' : status.trim()),
            administeredAt: Value(administeredAt ?? DateTime.now()),
            administeredByUserId: Value(administeredByUserId),
            relatedVisitId: Value(relatedVisitId),
            notes: Value(_textOrNull(notes)),
          ),
        );

    if (notifyParent) {
      await _queueParentMedicationSms(medicationId: medicationId, createdByUserId: administeredByUserId);
    }

    return id;
  }

  Future<void> _queueParentMedicationSms({
    required int medicationId,
    required int? createdByUserId,
  }) async {
    final med = await (_db.select(_db.studentMedications)..where((m) => m.id.equals(medicationId))).getSingleOrNull();
    if (med == null) return;

    final parentId = await _parentAccountIdForStudent(med.studentId);
    if (parentId == null) return;

    final student = await (_db.select(_db.students)..where((s) => s.id.equals(med.studentId))).getSingleOrNull();
    if (student == null) return;

    final dosageSuffix = med.dosage == null ? '' : ' (${med.dosage})';
    final message =
      '${student.firstName} ${student.lastName} was given ${med.medicationName}$dosageSuffix.';

    await _db.into(_db.notifications).insert(
          NotificationsCompanion.insert(
            recipientId: Value(parentId),
            recipientType: 'parent',
            channel: 'sms',
            subject: const Value('Medication Administered'),
            message: message,
            status: 'pending',
            externalId: const Value.absent(),
            sentAt: const Value.absent(),
            createdBy: createdByUserId ?? 1,
          ),
        );
  }

  // -------- Immunizations / checkups --------

  Stream<List<StudentImmunizationWithStudent>> watchImmunizationsWithStudent() {
    final imms = _db.studentImmunizations;
    final students = _db.students;

    final q = _db.select(imms).join([
      innerJoin(students, students.id.equalsExp(imms.studentId)),
    ]);

    q.orderBy([
      OrderingTerm.desc(imms.givenAt),
      OrderingTerm.asc(students.lastName),
      OrderingTerm.asc(students.firstName),
      OrderingTerm.asc(imms.vaccineName),
    ]);

    return q.watch().map(
          (rows) => rows
              .map(
                (r) => StudentImmunizationWithStudent(
                  student: r.readTable(students),
                  immunization: r.readTable(imms),
                ),
              )
              .toList(growable: false),
        );
  }

  Stream<List<StudentCheckupWithStudent>> watchCheckupsWithStudent() {
    final checkups = _db.studentCheckups;
    final students = _db.students;

    final q = _db.select(checkups).join([
      innerJoin(students, students.id.equalsExp(checkups.studentId)),
    ]);

    q.orderBy([
      OrderingTerm.desc(checkups.checkedAt),
      OrderingTerm.asc(students.lastName),
      OrderingTerm.asc(students.firstName),
      OrderingTerm.asc(checkups.checkupType),
    ]);

    return q.watch().map(
          (rows) => rows
              .map(
                (r) => StudentCheckupWithStudent(
                  student: r.readTable(students),
                  checkup: r.readTable(checkups),
                ),
              )
              .toList(growable: false),
        );
  }

  Stream<List<StudentImmunization>> watchImmunizations(int studentId) {
    final q = _db.select(_db.studentImmunizations)..where((t) => t.studentId.equals(studentId));
    q.orderBy([(t) => OrderingTerm(expression: t.givenAt, mode: OrderingMode.desc)]);
    return q.watch();
  }

  Future<int> addImmunization({
    required int studentId,
    required String vaccineName,
    required DateTime givenAt,
    String? provider,
    String? batchNumber,
    DateTime? nextDueAt,
    String? notes,
  }) async {
    return _db.into(_db.studentImmunizations).insert(
          StudentImmunizationsCompanion.insert(
            studentId: studentId,
            vaccineName: vaccineName.trim(),
            givenAt: givenAt,
            provider: Value(_textOrNull(provider)),
            batchNumber: Value(_textOrNull(batchNumber)),
            nextDueAt: Value(nextDueAt),
            notes: Value(_textOrNull(notes)),
          ),
        );
  }

  Stream<List<StudentCheckup>> watchCheckups(int studentId) {
    final q = _db.select(_db.studentCheckups)..where((t) => t.studentId.equals(studentId));
    q.orderBy([(t) => OrderingTerm(expression: t.checkedAt, mode: OrderingMode.desc)]);
    return q.watch();
  }

  Future<int> addCheckup({
    required int studentId,
    String checkupType = 'general',
    required DateTime checkedAt,
    String? outcome,
    String? notes,
    DateTime? nextDueAt,
  }) async {
    return _db.into(_db.studentCheckups).insert(
          StudentCheckupsCompanion.insert(
            studentId: studentId,
            checkupType: Value(checkupType.trim().isEmpty ? 'general' : checkupType.trim()),
            checkedAt: checkedAt,
            outcome: Value(_textOrNull(outcome)),
            notes: Value(_textOrNull(notes)),
            nextDueAt: Value(nextDueAt),
          ),
        );
  }

  // -------- Inventory --------

  Stream<List<InfirmaryInventoryItem>> watchInventoryItems() {
    final q = _db.select(_db.infirmaryInventoryItems)..where((t) => t.isActive.equals(true));
    q.orderBy([(t) => OrderingTerm(expression: t.name)]);
    return q.watch();
  }

  Stream<List<InfirmaryInventoryItem>> watchLowStockItems() {
    final q = _db.select(_db.infirmaryInventoryItems)
      ..where((t) => t.isActive.equals(true) & t.quantityOnHand.isSmallerOrEqual(t.reorderLevel));
    q.orderBy([(t) => OrderingTerm(expression: t.quantityOnHand)]);
    return q.watch();
  }

  Future<int> upsertInventoryItem({
    int? id,
    required String name,
    String category = 'other',
    String unit = 'pcs',
    double quantityOnHand = 0,
    double reorderLevel = 0,
    String? supplierName,
    String? notes,
    bool isActive = true,
  }) async {
    if (id == null) {
      return _db.into(_db.infirmaryInventoryItems).insert(
            InfirmaryInventoryItemsCompanion.insert(
              name: name.trim(),
              category: Value(category.trim().isEmpty ? 'other' : category.trim()),
              unit: Value(unit.trim().isEmpty ? 'pcs' : unit.trim()),
              quantityOnHand: Value(quantityOnHand),
              reorderLevel: Value(reorderLevel),
              supplierName: Value(_textOrNull(supplierName)),
              notes: Value(_textOrNull(notes)),
              isActive: Value(isActive),
              updatedAt: Value(DateTime.now()),
            ),
          );
    }

    await (_db.update(_db.infirmaryInventoryItems)..where((t) => t.id.equals(id))).write(
      InfirmaryInventoryItemsCompanion(
        name: Value(name.trim()),
        category: Value(category.trim().isEmpty ? 'other' : category.trim()),
        unit: Value(unit.trim().isEmpty ? 'pcs' : unit.trim()),
        quantityOnHand: Value(quantityOnHand),
        reorderLevel: Value(reorderLevel),
        supplierName: Value(_textOrNull(supplierName)),
        notes: Value(_textOrNull(notes)),
        isActive: Value(isActive),
        updatedAt: Value(DateTime.now()),
      ),
    );

    return id;
  }

  Stream<List<InfirmaryInventoryTransaction>> watchInventoryTransactions({int? itemId}) {
    final q = _db.select(_db.infirmaryInventoryTransactions);
    if (itemId != null) {
      q.where((t) => t.itemId.equals(itemId));
    }
    q.orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]);
    return q.watch();
  }

  Stream<List<Notification>> watchInfirmaryNotifications({String? status}) {
    final q = _db.select(_db.notifications)
      ..where(
        (t) =>
            t.channel.equals('sms') &
            (t.subject.equals('Infirmary Visit') | t.subject.equals('Medication Administered')),
      );

    final s = status?.trim();
    if (s != null && s.isNotEmpty && s != 'all') {
      q.where((t) => t.status.equals(s));
    }

    q.orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]);
    return q.watch();
  }

  Future<int> updateNotificationStatus({
    required int notificationId,
    required String status,
    DateTime? sentAt,
    String? externalId,
  }) {
    return (_db.update(_db.notifications)..where((t) => t.id.equals(notificationId))).write(
      NotificationsCompanion(
        status: Value(status.trim()),
        sentAt: Value(sentAt),
        externalId: Value(_textOrNull(externalId)),
      ),
    );
  }

  Future<int> recordInventoryTransaction({
    required int itemId,
    required double quantityDelta,
    String transactionType = 'use',
    int? relatedVisitId,
    String? notes,
    int? createdByUserId,
  }) async {
    await _db.transaction(() async {
      await _db.into(_db.infirmaryInventoryTransactions).insert(
            InfirmaryInventoryTransactionsCompanion.insert(
              itemId: itemId,
              transactionType: Value(transactionType.trim().isEmpty ? 'use' : transactionType.trim()),
              quantityDelta: quantityDelta,
              relatedVisitId: Value(relatedVisitId),
              notes: Value(_textOrNull(notes)),
              createdByUserId: Value(createdByUserId),
            ),
          );

      final item = await (_db.select(_db.infirmaryInventoryItems)..where((t) => t.id.equals(itemId))).getSingle();
      final newQty = item.quantityOnHand + quantityDelta;
      await (_db.update(_db.infirmaryInventoryItems)..where((t) => t.id.equals(itemId))).write(
        InfirmaryInventoryItemsCompanion(
          quantityOnHand: Value(newQty < 0 ? 0 : newQty),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });

    // Return last insert id is not available in the transaction closure; do a lookup.
    final last = await (_db.select(_db.infirmaryInventoryTransactions)
          ..where((t) => t.itemId.equals(itemId))
          ..orderBy([(t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc)])
          ..limit(1))
        .getSingle();
    return last.id;
  }

  // -------- Helpers --------

  String? _textOrNull(String? s) {
    final v = s?.trim();
    if (v == null || v.isEmpty) return null;
    return v;
  }
}
