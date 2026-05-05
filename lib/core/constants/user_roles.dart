// User roles enum
enum UserRole {
  admin,
  director,
  headmaster,
  headmistress,
  deputyheadmaster,
  deputyheadmistress,
  teacher,
  accountant,
  secretary,
  security,
  ictlab,
  sciencelab,
  shop,
  chef,
  infirmary,
  library,
  parent,
}

const List<UserRole> supportedPortalRoles = [
  UserRole.admin,
  UserRole.director,
  UserRole.headmaster,
  UserRole.headmistress,
  UserRole.teacher,
  UserRole.accountant,
  UserRole.shop,
];

const List<UserRole> supportedStaffPortalRoles = [
  UserRole.director,
  UserRole.headmaster,
  UserRole.headmistress,
  UserRole.teacher,
  UserRole.accountant,
  UserRole.shop,
];

// Extension for role display names
extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.director:
        return 'Director';
      case UserRole.headmaster:
        return 'Headmaster';
      case UserRole.headmistress:
        return 'Headmistress';
      case UserRole.deputyheadmaster:
        return 'Deputy Headmaster';
      case UserRole.deputyheadmistress:
        return 'Deputy Headmistress';
      case UserRole.teacher:
        return 'Teacher';
      case UserRole.accountant:
        return 'Accountant';
      case UserRole.secretary:
        return 'Secretary';
      case UserRole.security:
        return 'Security';
      case UserRole.ictlab:
        return 'ICT Lab';
      case UserRole.sciencelab:
        return 'Science Lab';
      case UserRole.shop:
        return 'Shop';
      case UserRole.chef:
        return 'Chef';
      case UserRole.infirmary:
        return 'Infirmary';
      case UserRole.library:
        return 'Library';
      case UserRole.parent:
        return 'Parent';
    }
  }

  String get colorCode {
    switch (this) {
      case UserRole.admin:
      case UserRole.director:
      case UserRole.headmaster:
      case UserRole.headmistress:
      case UserRole.deputyheadmaster:
      case UserRole.deputyheadmistress:
      case UserRole.secretary:
        return 'slate'; // Authority
      case UserRole.teacher:
      case UserRole.accountant:
      case UserRole.library:
        return 'indigo'; // Student-related
      case UserRole.security:
      case UserRole.ictlab:
      case UserRole.sciencelab:
      case UserRole.shop:
      case UserRole.chef:
      case UserRole.infirmary:
        return 'yellow'; // Staff/Operations
      case UserRole.parent:
        return 'green'; // Parent/Guardian
    }
  }
}
