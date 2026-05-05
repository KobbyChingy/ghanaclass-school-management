class InstitutionalIdentityModel {
  final int id;
  final String schoolName;
  final String headOfInstitution;
  final String officialEmail;
  final String? address;
  final String? motto;
  final String? logoPath;
  final DateTime createdAt;
  final DateTime updatedAt;

  InstitutionalIdentityModel({
    required this.id,
    required this.schoolName,
    required this.headOfInstitution,
    required this.officialEmail,
    this.address,
    this.motto,
    this.logoPath,
    required this.createdAt,
    required this.updatedAt,
  });
}

class UserModel {
  final int id;
  final String fullName;
  final String email;
  final String role; // UserRole enum as string
  final String? photoPath;
  final String? phoneNumber;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLoginAt;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.photoPath,
    this.phoneNumber,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.lastLoginAt,
  });
}

class SessionModel {
  final int id;
  final int userId;
  final String token;
  final DateTime expiresAt;
  final DateTime createdAt;

  SessionModel({
    required this.id,
    required this.userId,
    required this.token,
    required this.expiresAt,
    required this.createdAt,
  });
}
