import 'dart:convert';

import 'package:bcrypt/bcrypt.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

import 'package:ghanaclass_backend/auth/jwt.dart';
import 'package:ghanaclass_backend/http/http_exceptions.dart';

String _normalizeRoleToken(String role) =>
    role.trim().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

bool _isRoleMatch({required String requestedRole, required String storedRole}) {
  final requested = _normalizeRoleToken(requestedRole);
  final stored = _normalizeRoleToken(storedRole);

  if (requested.isEmpty || stored.isEmpty) return false;
  if (requested == stored) return true;

  const headRoles = {'headmaster', 'headmistress'};
  if (headRoles.contains(requested) && headRoles.contains(stored)) {
    return true;
  }

  const deputyHeadRoles = {'deputyheadmaster', 'deputyheadmistress'};
  if (deputyHeadRoles.contains(requested) && deputyHeadRoles.contains(stored)) {
    return true;
  }

  return false;
}

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final body = await context.request.body();
  final jsonBody = json.decode(body);
  if (jsonBody is! Map<String, dynamic>) {
    throw BadRequestException('Expected a JSON object');
  }

  final email = (jsonBody['email'] as String?)?.trim().toLowerCase();
  final password = jsonBody['password'] as String?;
  // Optional: some clients send a role; we don't rely on it.
  final requestedRole = (jsonBody['role'] as String?)?.trim().toLowerCase();

  if (email == null || email.isEmpty) {
    throw BadRequestException('Missing email');
  }
  if (password == null || password.isEmpty) {
    throw BadRequestException('Missing password');
  }

  final pool = context.read<Pool>();

  final rows = await pool.withConnection((conn) async {
    return conn.execute(
      Sql.named(
        'SELECT '
        'u.id, u.email, u.full_name, u.role, u.password_hash, '
        's.id, s.code, s.name, s.schema_name '
        'FROM public.users u '
        'JOIN public.schools s ON s.id = u.school_id '
        'WHERE lower(u.email) = lower(@email) '
        'AND u.is_active = true '
        'LIMIT 1',
      ),
      parameters: {
        'email': email,
      },
    );
  });

  if (rows.isEmpty) {
    throw UnauthorizedException('Invalid email or password');
  }

  final row = rows.first;
  final storedPasswordHash = row[4] as String;
  if (!BCrypt.checkpw(password, storedPasswordHash)) {
    throw UnauthorizedException('Invalid email or password');
  }
  final userId = row[0].toString();
  final dbEmail = row[1] as String;
  final fullName = row[2] as String;
  final role = row[3] as String;
  final schoolId = row[5].toString();
  final schoolCode = row[6] as String;
  final schoolName = row[7] as String;
  final schoolSchema = row[8] as String;

  // If the client requested a role, fail fast when it doesn't match.
  if (requestedRole != null && requestedRole.isNotEmpty) {
    if (!_isRoleMatch(requestedRole: requestedRole, storedRole: role)) {
      throw ForbiddenException('Role mismatch');
    }
  }

  final token = issueJwt(
    claims: {
      'sub': userId,
      'email': dbEmail,
      'role': role,
      'schoolId': schoolId,
      'schoolSchema': schoolSchema,
      'schoolCode': schoolCode,
    },
  );

  return Response.json(
    body: {
      'token': token,
      'user': {
        'id': userId,
        'email': dbEmail,
        'fullName': fullName,
        'role': role,
      },
      'school': {
        'id': schoolId,
        'code': schoolCode,
        'name': schoolName,
        'schema': schoolSchema,
      },
    },
  );
}
