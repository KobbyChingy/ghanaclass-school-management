import 'package:ghanaclass_school_management/core/constants/user_roles.dart';

/// Normalizes role strings for tolerant comparisons.
///
/// Examples:
/// - "Science Lab" -> "sciencelab"
/// - "Deputy Headmaster" -> "deputyheadmaster"
/// - " HEAD-MISTRESS " -> "headmistress"
String normalizeRoleToken(String raw) {
  return raw.trim().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
}

bool roleNameMatches(String roleName, UserRole role) {
  return normalizeRoleToken(roleName) == normalizeRoleToken(role.name);
}

bool roleNameIsOneOf(String roleName, Iterable<UserRole> roles) {
  final token = normalizeRoleToken(roleName);
  for (final r in roles) {
    if (token == normalizeRoleToken(r.name)) return true;
  }
  return false;
}

/// Returns the most appropriate landing route for a given role string.
///
/// Handles minor formatting differences like "Science Lab" vs "sciencelab".
String homeRouteForRoleName(String roleName) {
  final token = normalizeRoleToken(roleName);

  if (token == normalizeRoleToken(UserRole.director.name) || token.contains(normalizeRoleToken(UserRole.director.name))) {
    return '/director';
  }
  if (token == normalizeRoleToken(UserRole.headmaster.name)) return '/dashboard';
  if (token == normalizeRoleToken(UserRole.headmistress.name)) return '/dashboard';
  if (token == normalizeRoleToken(UserRole.teacher.name)) return '/teacher';
  if (token == normalizeRoleToken(UserRole.accountant.name)) return '/accountant';
  if (token == normalizeRoleToken(UserRole.shop.name)) return '/shop/dashboard';

  // Admin and unknown roles fall back to the main dashboard.
  return '/dashboard';
}

String homeRouteForRole(UserRole role) => homeRouteForRoleName(role.name);
