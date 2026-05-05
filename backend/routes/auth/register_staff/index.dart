import 'dart:convert';

import 'package:bcrypt/bcrypt.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

import 'package:ghanaclass_backend/auth/auth_context.dart';
import 'package:ghanaclass_backend/http/http_exceptions.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final authUser = requireAuth(context, requiredRole: 'admin');

  final body = await context.request.body();
  final jsonBody = jsonDecode(body);
  if (jsonBody is! Map<String, dynamic>) {
    throw BadRequestException('Expected a JSON object');
  }

  final email = (jsonBody['email'] as String?)?.trim().toLowerCase();
  final password = jsonBody['password'] as String?;
  final fullName = (jsonBody['fullName'] as String?)?.trim();
  final role = (jsonBody['role'] as String?)?.trim().toLowerCase();

  if (email == null || email.isEmpty) throw BadRequestException('Missing email');
  if (password == null || password.isEmpty) {
    throw BadRequestException('Missing password');
  }
  if (fullName == null || fullName.isEmpty) {
    throw BadRequestException('Missing fullName');
  }
  if (role == null || role.isEmpty) throw BadRequestException('Missing role');

  // Allowlist for staff user creation.
  // Keep legacy values (e.g. "staff") to avoid breaking older clients.
  const allowedRoles = {
    'admin',
    'director',
    'headmaster',
    'headmistress',
    'teacher',
    'accountant',
    'shop',
    // legacy / compatibility
    'staff',
    'student',
  };
  if (!allowedRoles.contains(role)) {
    throw BadRequestException('Invalid role');
  }


  final pool = context.read<Pool>();
  final passwordHash = BCrypt.hashpw(password, BCrypt.gensalt());

  try {
    final rows = await pool.withConnection((conn) async {
      if (role == 'director') {
        final existingDirector = await conn.execute(
          Sql.named(
            'SELECT id FROM public.users '
            'WHERE school_id = @schoolId::uuid AND LOWER(role) = @role '
            'LIMIT 1',
          ),
          parameters: {
            'schoolId': authUser.schoolId,
            'role': role,
          },
        );

        if (existingDirector.isNotEmpty) {
          throw ConflictException('A Director account already exists for this school');
        }
      }

      return conn.execute(
        Sql.named(
          'INSERT INTO public.users(school_id, email, password_hash, full_name, role) '
          'VALUES (@schoolId::uuid, @email, @passwordHash, @fullName, @role) '
          'RETURNING id, email, full_name, role, created_at',
        ),
        parameters: {
          'schoolId': authUser.schoolId,
          'email': email,
          'passwordHash': passwordHash,
          'fullName': fullName,
          'role': role,
        },
      );
    });

    final row = rows.first;

    return Response.json(
      statusCode: 201,
      body: {
        'user': {
          'id': row[0].toString(),
          'email': row[1] as String,
          'fullName': row[2] as String,
          'role': row[3] as String,
          'createdAt': (row[4] as DateTime).toUtc().toIso8601String(),
        },
      },
    );
  } on ConflictException catch (e) {
    return Response.json(statusCode: 409, body: {'error': e.message});
  } on ServerException catch (e) {
    final code = e.code;
    if (code == '23505') {
      return Response.json(statusCode: 409, body: {'error': 'Email already exists'});
    }
    rethrow;
  }
}
