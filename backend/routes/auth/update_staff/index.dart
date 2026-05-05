import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

import 'package:ghanaclass_backend/auth/auth_context.dart';
import 'package:ghanaclass_backend/http/http_exceptions.dart';

const _allowedRoles = {
  'admin',
  'director',
  'headmaster',
  'headmistress',
  'teacher',
  'accountant',
  'shop',
  'staff',
  'student',
};

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
  final fullName = (jsonBody['fullName'] as String?)?.trim();
  final role = (jsonBody['role'] as String?)?.trim().toLowerCase();
  final isActive = jsonBody['isActive'] as bool?;

  if (email == null || email.isEmpty) {
    throw BadRequestException('Missing email');
  }
  if ((fullName == null || fullName.isEmpty) && role == null && isActive == null) {
    throw BadRequestException('No updates provided');
  }
  if (role != null && !_allowedRoles.contains(role)) {
    throw BadRequestException('Invalid role');
  }

  final pool = context.read<Pool>();

  try {
    final rows = await pool.withConnection((conn) async {
      final existingRows = await conn.execute(
        Sql.named(
          'SELECT id, role '
          'FROM public.users '
          'WHERE school_id = @schoolId::uuid '
          'AND lower(email) = lower(@email) '
          'LIMIT 1',
        ),
        parameters: {
          'schoolId': authUser.schoolId,
          'email': email,
        },
      );

      if (existingRows.isEmpty) {
        return <ResultRow>[];
      }

      final userId = existingRows.first[0].toString();

      if (role == 'director') {
        final existingDirector = await conn.execute(
          Sql.named(
            'SELECT id FROM public.users '
            'WHERE school_id = @schoolId::uuid '
            'AND lower(role) = @role '
            'AND id <> @userId::uuid '
            'LIMIT 1',
          ),
          parameters: {
            'schoolId': authUser.schoolId,
            'role': role,
            'userId': userId,
          },
        );

        if (existingDirector.isNotEmpty) {
          throw ConflictException('A Director account already exists for this school');
        }
      }

      return conn.execute(
        Sql.named(
          'UPDATE public.users '
          'SET full_name = COALESCE(@fullName, full_name), '
          'role = COALESCE(@role, role), '
          'is_active = COALESCE(@isActive, is_active) '
          'WHERE school_id = @schoolId::uuid '
          'AND lower(email) = lower(@email) '
          'RETURNING id, email, full_name, role, is_active',
        ),
        parameters: {
          'schoolId': authUser.schoolId,
          'email': email,
          'fullName': fullName,
          'role': role,
          'isActive': isActive,
        },
      );
    });

    if (rows.isEmpty) {
      return Response.json(statusCode: 404, body: {'error': 'Staff portal account not found'});
    }

    final row = rows.first;
    return Response.json(
      body: {
        'user': {
          'id': row[0].toString(),
          'email': row[1] as String,
          'fullName': row[2] as String,
          'role': row[3] as String,
          'isActive': row[4] as bool,
        },
      },
    );
  } on ConflictException catch (e) {
    return Response.json(statusCode: 409, body: {'error': e.message});
  }
}