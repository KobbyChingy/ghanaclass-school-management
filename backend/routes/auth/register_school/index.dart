import 'dart:convert';

import 'package:bcrypt/bcrypt.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

import 'package:ghanaclass_backend/http/http_exceptions.dart';
import 'package:ghanaclass_backend/auth/jwt.dart';

String _defaultSchemaFromCode(String code) {
  final normalized = code
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return 'school_$normalized';
}

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final body = await context.request.body();
  final jsonBody = jsonDecode(body);
  if (jsonBody is! Map<String, dynamic>) {
    throw BadRequestException('Expected a JSON object');
  }

  final code = (jsonBody['code'] as String?)?.trim();
  final name = (jsonBody['name'] as String?)?.trim();
  final adminEmail = (jsonBody['adminEmail'] as String?)?.trim().toLowerCase();
  final adminPassword = jsonBody['adminPassword'] as String?;
  final adminFullName = (jsonBody['adminFullName'] as String?)?.trim() ?? 'Admin';

  if (code == null || code.isEmpty) throw BadRequestException('Missing code');
  if (name == null || name.isEmpty) throw BadRequestException('Missing name');
  if (adminEmail == null || adminEmail.isEmpty) {
    throw BadRequestException('Missing adminEmail');
  }
  if (adminPassword == null || adminPassword.isEmpty) {
    throw BadRequestException('Missing adminPassword');
  }

  final schema = _defaultSchemaFromCode(code);
  final passwordHash = BCrypt.hashpw(adminPassword, BCrypt.gensalt());
  final pool = context.read<Pool>();

  try {
    return await pool.withConnection((conn) async {
      await conn.execute('BEGIN');
      try {
        final schoolRows = await conn.execute(
          Sql.named(
            'INSERT INTO public.schools(code, name, schema_name) '
            'VALUES (@code, @name, @schema) '
            'RETURNING id, code, name, schema_name, created_at',
          ),
          parameters: {
            'code': code,
            'name': name,
            'schema': schema,
          },
        );

        final school = schoolRows.first;
        final schoolId = school[0].toString();
        final createdAt = (school[4] as DateTime).toUtc().toIso8601String();

        await conn.execute(
          Sql.named('SELECT public.create_school_schema(@schema)'),
          parameters: {'schema': schema},
        );

        final userRows = await conn.execute(
          Sql.named(
            'INSERT INTO public.users(school_id, email, password_hash, full_name, role) '
            'VALUES (@schoolId::uuid, @email, @passwordHash, @fullName, @role) '
            'RETURNING id, email, full_name, role, created_at',
          ),
          parameters: {
            'schoolId': schoolId,
            'email': adminEmail,
            'passwordHash': passwordHash,
            'fullName': adminFullName,
            'role': 'admin',
          },
        );

        final user = userRows.first;
        final userId = user[0].toString();

        await conn.execute('COMMIT');

        final token = issueJwt(
          claims: {
            'sub': userId,
            'email': adminEmail,
            'role': 'admin',
            'schoolId': schoolId,
            'schoolSchema': schema,
            'schoolCode': code,
          },
        );

        return Response.json(
          statusCode: 201,
          body: {
            'school': {
              'id': schoolId,
              'code': code,
              'name': name,
              'schema': schema,
              'createdAt': createdAt,
            },
            'user': {
              'id': userId,
              'email': adminEmail,
              'fullName': user[2] as String,
              'role': user[3] as String,
              'createdAt': (user[4] as DateTime).toUtc().toIso8601String(),
            },
            'token': token,
          },
        );
      } catch (e) {
        await conn.execute('ROLLBACK');
        rethrow;
      }
    });
  } on PgException catch (e) {
    // 23505 = unique_violation
    final code = e is ServerException ? e.code : null;
    if (code == '23505') {
      return Response.json(
        statusCode: 409,
        body: {'error': 'School or email already exists'},
      );
    }
    rethrow;
  }
}
