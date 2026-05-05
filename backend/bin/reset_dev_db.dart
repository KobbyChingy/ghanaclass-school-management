import 'dart:io';

import 'package:postgres/postgres.dart';

import 'package:ghanaclass_backend/db/postgres_pool.dart';

Future<void> main(List<String> args) async {
  final pool = getPool();

  try {
    await pool.withConnection((conn) async {
      final schoolSchemaRows = await conn.execute(
        'SELECT schema_name FROM public.schools ORDER BY schema_name ASC',
      );

      for (final row in schoolSchemaRows) {
        final schemaName = row[0] as String;
        stdout.writeln('Dropping school schema: $schemaName');
        await conn.execute(
          Sql.named('DROP SCHEMA IF EXISTS @schemaName:name CASCADE'),
          parameters: {'schemaName': schemaName},
        );
      }

      stdout.writeln('Dropping public tables and helper function...');
      await conn.execute('DROP TABLE IF EXISTS public.users CASCADE');
      await conn.execute('DROP TABLE IF EXISTS public.applied_ops CASCADE');
      await conn.execute('DROP TABLE IF EXISTS public.schools CASCADE');
      await conn.execute('DROP FUNCTION IF EXISTS public.create_school_schema(text) CASCADE');
    });

    stdout.writeln('Development database reset complete.');
  } on PgException catch (e) {
    stderr.writeln('Database reset failed: ${e.message}');
    exitCode = 1;
  } catch (e) {
    stderr.writeln('Database reset failed: $e');
    exitCode = 1;
  } finally {
    await pool.close();
  }
}