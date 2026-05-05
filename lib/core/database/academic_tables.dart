import 'package:drift/drift.dart';
import 'tables.dart';

// Students Table
class Students extends Table {
    /// Leadership position or role (e.g., 'School Prefect', 'Class Prefect', etc.)
    TextColumn get position => text().nullable()();
  IntColumn get id => integer().autoIncrement()();
  TextColumn get studentId => text().unique()(); // e.g., "STU2024001"
  TextColumn get firstName => text().withLength(min: 1, max: 100)();
  TextColumn get lastName => text().withLength(min: 1, max: 100)();
  TextColumn get otherNames => text().nullable()();
  TextColumn get gender => text()(); // 'male', 'female'
  DateTimeColumn get dateOfBirth => dateTime()();
  TextColumn get photoPath => text().nullable()();

  // Student services
  BoolColumn get eatsCanteen => boolean().withDefault(const Constant(false))();
  BoolColumn get takesSchoolBus => boolean().withDefault(const Constant(false))();
  
  // Contact Information
  TextColumn get address => text().nullable()();
  TextColumn get phoneNumber => text().nullable()();
  TextColumn get email => text().nullable()();
  
  // Guardian Information
  TextColumn get guardianName => text()();
  TextColumn get guardianPhone => text()();
  TextColumn get guardianEmail => text().nullable()();
  TextColumn get guardianOccupation => text().nullable()();
  TextColumn get guardianRelationship => text()(); // 'parent', 'guardian', etc.
  TextColumn get guardianAddress => text().nullable()();
  
  // Academic Information
  IntColumn get classId => integer().nullable().references(SchoolClasses, #id)();
  DateTimeColumn get admissionDate => dateTime()();
  TextColumn get admissionNumber => text().unique()();
  RealColumn get enrolledFees => real().withDefault(const Constant(0.0))();
  
  // Status
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get status => text().withDefault(const Constant('active'))(); // 'active', 'graduated', 'transferred', 'expelled'
  
  // Metadata
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
}

// Student-Subject Enrollments (subjects a student takes within a class)
class StudentSubjectEnrollments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get studentId => integer().references(Students, #id)();
  IntColumn get classId => integer().references(SchoolClasses, #id)();
  IntColumn get subjectId => integer().references(SchoolSubjects, #id)();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {studentId, classId, subjectId}
      ];
}

// Student Health Records
class HealthRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get studentId => integer().unique().references(Students, #id)();
  TextColumn get bloodGroup => text().nullable()();
  TextColumn get allergies => text().nullable()();
  TextColumn get vaccinations => text().nullable()();
  TextColumn get medications => text().nullable()();
  TextColumn get physicalDisability => text().nullable()();
  TextColumn get emergencyInstructions => text().nullable()();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
}

// Student Academic History (Former schools)
class AcademicHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get studentId => integer().references(Students, #id)();
  TextColumn get formerSchool => text().withLength(min: 1, max: 200)();
  TextColumn get highestClassReached => text().nullable()();
  TextColumn get reasonForLeaving => text().nullable()();
  TextColumn get assessmentScores => text().nullable()(); // JSON or serialized
  TextColumn get certificatesPath => text().nullable()();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
}

// Classes Table
class SchoolClasses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get className => text().withLength(min: 1, max: 100)(); // e.g., "Form 1A", "Grade 5"
  TextColumn get classCode => text().unique()(); // e.g., "F1A", "G5"
  IntColumn get academicYear => integer()(); // e.g., 2024
  IntColumn get capacity => integer().withDefault(const Constant(40))();
  IntColumn get headTeacherId => integer().nullable().references(Users, #id)(); // Head teacher of the class
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
}

// Subjects Table
class SchoolSubjects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get subjectName => text().withLength(min: 1, max: 100)();
  TextColumn get subjectCode => text().unique()();
  TextColumn get description => text().nullable()();
  BoolColumn get isCore => boolean().withDefault(const Constant(false))(); // Core vs Elective
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
}

// Class-Subject Offerings (which subjects are offered in a class)
class ClassSubjectOfferings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get classId => integer().references(SchoolClasses, #id)();
  IntColumn get subjectId => integer().references(SchoolSubjects, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {classId, subjectId} // One offering per subject per class
      ];
}

// Class-Subject-Teacher Mappings
class ClassSubjectTeachers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get classId => integer().references(SchoolClasses, #id)();
  IntColumn get subjectId => integer().references(SchoolSubjects, #id)();
  IntColumn get teacherId => integer().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {classId, subjectId} // One teacher per subject per class
  ];
}

// Staff Table (extends Users for teaching staff)
class Staff extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().unique().references(Users, #id)();
  TextColumn get staffId => text().unique()(); // e.g., "STAFF2024001"
  TextColumn get firstName => text().withLength(min: 1, max: 100)();
  TextColumn get lastName => text().withLength(min: 1, max: 100)();
  TextColumn get gender => text()();
  DateTimeColumn get dateOfBirth => dateTime()();
  TextColumn get photoPath => text().nullable()();
  
  // Contact
  TextColumn get address => text().nullable()();
  TextColumn get phoneNumber => text()();
  TextColumn get emergencyContact => text().nullable()();
  
  // Employment
  TextColumn get position => text()(); // 'teacher', 'admin', 'support'
  TextColumn get department => text().nullable()();
  DateTimeColumn get hireDate => dateTime()();
  RealColumn get baseSalary => real()();
  
    // Contract Details
    TextColumn get contractType => text().nullable()(); // e.g., 'permanent', 'temporary', 'contract'
    DateTimeColumn get contractStartDate => dateTime().nullable()();
    DateTimeColumn get contractEndDate => dateTime().nullable()();
  
    // Qualifications
    TextColumn get qualifications => text().nullable()();
  
  // Status
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  
  // Metadata
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
}
