class StudentModel {
  final int id;
  final String studentId;
  final String firstName;
  final String lastName;
  final String? otherNames;
  final String gender;
  final DateTime dateOfBirth;
  final String? photoPath;
  final String? address;
  final String? phoneNumber;
  final String? email;
  final String guardianName;
  final String guardianPhone;
  final String? guardianEmail;
  final String? guardianOccupation;
  final String guardianRelationship;
  final String? guardianAddress;
  final int? classId;
  final DateTime admissionDate;
  final String admissionNumber;
  final double enrolledFees;
  final bool isActive;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  StudentModel({
    required this.id,
    required this.studentId,
    required this.firstName,
    required this.lastName,
    this.otherNames,
    required this.gender,
    required this.dateOfBirth,
    this.photoPath,
    this.address,
    this.phoneNumber,
    this.email,
    required this.guardianName,
    required this.guardianPhone,
    this.guardianEmail,
    this.guardianOccupation,
    required this.guardianRelationship,
    this.guardianAddress,
    this.classId,
    required this.admissionDate,
    required this.admissionNumber,
    required this.enrolledFees,
    required this.isActive,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  String get fullName => '$firstName $lastName${otherNames != null ? " $otherNames" : ""}';
  
  int get age {
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month || 
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }
}

class ClassModel {
  final int id;
  final String className;
  final String classCode;
  final int academicYear;
  final int capacity;
  final int? teacherId;
  final bool isActive;
  final DateTime createdAt;

  ClassModel({
    required this.id,
    required this.className,
    required this.classCode,
    required this.academicYear,
    required this.capacity,
    this.teacherId,
    required this.isActive,
    required this.createdAt,
  });
}

class SubjectModel {
  final int id;
  final String subjectName;
  final String subjectCode;
  final String? description;
  final bool isCore;
  final bool isActive;
  final DateTime createdAt;

  SubjectModel({
    required this.id,
    required this.subjectName,
    required this.subjectCode,
    this.description,
    required this.isCore,
    required this.isActive,
    required this.createdAt,
  });
}

class StaffModel {
  final int id;
  final int userId;
  final String staffId;
  final String firstName;
  final String lastName;
  final String gender;
  final DateTime dateOfBirth;
  final String? photoPath;
  final String? address;
  final String phoneNumber;
  final String? emergencyContact;
  final String position;
  final String? department;
  final DateTime hireDate;
  final double baseSalary;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  StaffModel({
    required this.id,
    required this.userId,
    required this.staffId,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.dateOfBirth,
    this.photoPath,
    this.address,
    required this.phoneNumber,
    this.emergencyContact,
    required this.position,
    this.department,
    required this.hireDate,
    required this.baseSalary,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  String get fullName => '$firstName $lastName';
}
