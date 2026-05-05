import 'package:dart_frog/dart_frog.dart';

import 'package:ghanaclass_backend/auth/jwt.dart';
import 'package:ghanaclass_backend/http/http_exceptions.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.role,
    required this.schoolId,
    this.schoolSchema,
  });

  final String id;
  final String email;
  final String role;
  final String schoolId;
  final String? schoolSchema;
}

AuthUser requireAuth(RequestContext context, {String? requiredRole}) {
  final authHeader = context.request.headers['authorization'] ??
      context.request.headers['Authorization'];

  if (authHeader == null || authHeader.trim().isEmpty) {
    throw UnauthorizedException('Missing Authorization header');
  }

  final parts = authHeader.trim().split(' ');
  if (parts.length != 2 || parts[0].toLowerCase() != 'bearer') {
    throw UnauthorizedException('Invalid Authorization header');
  }

  final token = parts[1].trim();
  final payload = verifyJwt(token);

  final userId = payload['sub']?.toString();
  final email = payload['email']?.toString();
  final role = payload['role']?.toString();
  final schoolId = payload['schoolId']?.toString();
  final schoolSchema = payload['schoolSchema']?.toString();

  if (userId == null ||
      userId.isEmpty ||
      email == null ||
      email.isEmpty ||
      role == null ||
      role.isEmpty ||
      schoolId == null ||
      schoolId.isEmpty) {
    throw UnauthorizedException('Invalid token payload');
  }

  if (requiredRole != null && role.toLowerCase() != requiredRole.toLowerCase()) {
    throw ForbiddenException('Insufficient permissions');
  }

  return AuthUser(
    id: userId,
    email: email,
    role: role,
    schoolId: schoolId,
    schoolSchema: schoolSchema,
  );
}
