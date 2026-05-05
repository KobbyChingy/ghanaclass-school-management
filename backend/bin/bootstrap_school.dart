import 'dart:io';

import 'package:postgres/postgres.dart';

import 'package:ghanaclass_backend/db/postgres_pool.dart';

String _required(String key) {
  final value = Platform.environment[key];
  if (value == null || value.trim().isEmpty) {
    throw StateError('Missing required env var: $key');
  }
  return value.trim();
}

String _defaultSchemaFromCode(String code) {
  final normalized = code
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return 'school_$normalized';
}

Future<void> main(List<String> args) async {
  final code = _required('SCHOOL_CODE');
  final name = _required('SCHOOL_NAME');
  final schema =
      (Platform.environment['SCHOOL_SCHEMA']?.trim().isNotEmpty ?? false)
          ? Platform.environment['SCHOOL_SCHEMA']!.trim()
          : _defaultSchemaFromCode(code);

  final pool = getPool();

  try {
    await pool.withConnection((conn) async {
      await conn.execute(
        Sql.named(
          'INSERT INTO public.schools(code, name, schema_name) '
          'VALUES (@code, @name, @schema) '
          'ON CONFLICT (code) DO UPDATE SET '
          'name = EXCLUDED.name, schema_name = EXCLUDED.schema_name',
        ),
        parameters: {
          'code': code,
          'name': name,
          'schema': schema,
        },
      );

      await conn.execute(
        Sql.named('SELECT public.create_school_schema(@schema)'),
        parameters: {'schema': schema},
      );

      stdout.writeln('Bootstrapped school: code=$code schema=$schema');
    });
  } on SocketException catch (e) {
    stderr.writeln('Bootstrap failed: cannot reach PostgreSQL (${e.message})');
    exitCode = 1;
  } on PgException catch (e) {
    stderr.writeln('Bootstrap failed: ${e.message}');
    exitCode = 1;
  } catch (e) {
    stderr.writeln('Bootstrap failed: $e');
    exitCode = 1;
  } finally {
    await pool.close();
  }
}
