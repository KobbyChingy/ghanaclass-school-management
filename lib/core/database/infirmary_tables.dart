import 'package:drift/drift.dart';

import 'academic_tables.dart';
import 'tables.dart';

/// Infirmary / Sick Bay module tables.
///
/// Design goals (from CSV): everything is student-linked, supports visit logging,
/// medication administration, allergies/risk alerts, immunizations/checkups,
/// documents/consents, and first-aid inventory with low-stock tracking.

class StudentEmergencyContacts extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get studentId => integer().references(Students, #id)();

  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get relationship => text().withLength(min: 1, max: 80)();
  TextColumn get phoneNumber => text().withLength(min: 1, max: 40)();

  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {studentId, phoneNumber}
      ];
}

class StudentPhysicianDetails extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get studentId => integer().unique().references(Students, #id)();

  TextColumn get physicianName => text().nullable()();
  TextColumn get phoneNumber => text().nullable()();
  TextColumn get facilityName => text().nullable()();
  TextColumn get notes => text().nullable()();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class StudentVitalsLogs extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get studentId => integer().references(Students, #id)();
  DateTimeColumn get measuredAt => dateTime().withDefault(currentDateAndTime)();

  /// Height in centimeters.
  RealColumn get heightCm => real().nullable()();

  /// Weight in kilograms.
  RealColumn get weightKg => real().nullable()();

  /// BMI is optional and may be computed at write-time.
  RealColumn get bmi => real().nullable()();

  /// Optional vitals.
  RealColumn get temperatureC => real().nullable()();

  TextColumn get notes => text().nullable()();

  IntColumn get recordedByUserId => integer().nullable().references(Users, #id)();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class StudentHealthDocuments extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get studentId => integer().references(Students, #id)();

  /// medical_cert | prescription | consent | other
  TextColumn get documentType => text().withDefault(const Constant('other'))();

  TextColumn get title => text().withLength(min: 1, max: 200)();

  /// Local path to a copied file in app storage.
  TextColumn get localPath => text()();

  TextColumn get notes => text().nullable()();

  IntColumn get uploadedByUserId => integer().nullable().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class StudentAllergyAlerts extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get studentId => integer().references(Students, #id)();

  /// food | medication | insect | environment | other
  TextColumn get allergyType => text().withDefault(const Constant('other'))();

  TextColumn get description => text().withLength(min: 1, max: 240)();

  /// low | medium | high
  TextColumn get severity => text().withDefault(const Constant('medium'))();

  TextColumn get triggers => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class StudentChronicConditions extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get studentId => integer().references(Students, #id)();

  TextColumn get conditionName => text().withLength(min: 1, max: 200)();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class InfirmaryVisits extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get studentId => integer().references(Students, #id)();

  /// first_aid | medication_admin | checkup | referral | other
  TextColumn get category => text().withDefault(const Constant('checkup'))();

  TextColumn get reason => text().withLength(min: 1, max: 240)();
  TextColumn get symptoms => text().nullable()();

  TextColumn get treatmentProvided => text().nullable()();
  TextColumn get outcome => text().nullable()();

  DateTimeColumn get timeIn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get timeOut => dateTime().nullable()();

  BoolColumn get sentHome => boolean().withDefault(const Constant(false))();
  BoolColumn get referredToHospital => boolean().withDefault(const Constant(false))();
  TextColumn get referralNotes => text().nullable()();

  TextColumn get nurseNotes => text().nullable()();

  IntColumn get recordedByUserId => integer().nullable().references(Users, #id)();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class StudentMedications extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get studentId => integer().references(Students, #id)();

  TextColumn get medicationName => text().withLength(min: 1, max: 180)();
  TextColumn get dosage => text().nullable()();

  /// Free-form schedule string (e.g. "1 tab 8am, 1 tab 6pm").
  TextColumn get schedule => text().nullable()();

  TextColumn get instructions => text().nullable()();

  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get endDate => dateTime().nullable()();

  BoolColumn get requiresConsent => boolean().withDefault(const Constant(false))();
  IntColumn get consentDocumentId => integer().nullable().references(StudentHealthDocuments, #id)();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class MedicationAdministrationLogs extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get studentMedicationId => integer().references(StudentMedications, #id)();

  /// given | missed | held
  TextColumn get status => text().withDefault(const Constant('given'))();

  DateTimeColumn get administeredAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get administeredByUserId => integer().nullable().references(Users, #id)();

  IntColumn get relatedVisitId => integer().nullable().references(InfirmaryVisits, #id)();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class StudentImmunizations extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get studentId => integer().references(Students, #id)();

  TextColumn get vaccineName => text().withLength(min: 1, max: 200)();
  DateTimeColumn get givenAt => dateTime()();

  TextColumn get provider => text().nullable()();
  TextColumn get batchNumber => text().nullable()();

  DateTimeColumn get nextDueAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class StudentCheckups extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get studentId => integer().references(Students, #id)();

  /// vision | dental | general | other
  TextColumn get checkupType => text().withDefault(const Constant('general'))();

  DateTimeColumn get checkedAt => dateTime()();

  TextColumn get outcome => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get nextDueAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class InfirmaryInventoryItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 180)();

  /// bandage | antiseptic | medication | equipment | other
  TextColumn get category => text().withDefault(const Constant('other'))();

  TextColumn get unit => text().withDefault(const Constant('pcs'))();

  RealColumn get quantityOnHand => real().withDefault(const Constant(0))();
  RealColumn get reorderLevel => real().withDefault(const Constant(0))();

  TextColumn get supplierName => text().nullable()();
  TextColumn get notes => text().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class InfirmaryInventoryTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get itemId => integer().references(InfirmaryInventoryItems, #id)();

  /// restock | use | adjust
  TextColumn get transactionType => text().withDefault(const Constant('use'))();

  /// Quantity change (positive for restock, negative for use).
  RealColumn get quantityDelta => real()();

  IntColumn get relatedVisitId => integer().nullable().references(InfirmaryVisits, #id)();

  TextColumn get notes => text().nullable()();

  IntColumn get createdByUserId => integer().nullable().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
