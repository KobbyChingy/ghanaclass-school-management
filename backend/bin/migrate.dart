import 'dart:io';

import 'package:postgres/postgres.dart';

import 'package:ghanaclass_backend/db/postgres_pool.dart';

List<String> _splitSqlStatements(String sql) {
  final statements = <String>[];
  final buffer = StringBuffer();

  var inSingleQuote = false;
  var inDoubleQuote = false;
  var inLineComment = false;
  var inBlockComment = false;

  String? dollarTag;

  bool startsWithAt(int index, String value) {
    if (index + value.length > sql.length) return false;
    return sql.substring(index, index + value.length) == value;
  }

  for (var i = 0; i < sql.length; i++) {
    final ch = sql[i];

    if (inLineComment) {
      buffer.write(ch);
      if (ch == '\n') {
        inLineComment = false;
      }
      continue;
    }

    if (inBlockComment) {
      buffer.write(ch);
      if (ch == '*' && i + 1 < sql.length && sql[i + 1] == '/') {
        buffer.write('/');
        i++;
        inBlockComment = false;
      }
      continue;
    }

    if (!inSingleQuote && !inDoubleQuote && dollarTag == null) {
      if (ch == '-' && i + 1 < sql.length && sql[i + 1] == '-') {
        buffer.write('--');
        i++;
        inLineComment = true;
        continue;
      }
      if (ch == '/' && i + 1 < sql.length && sql[i + 1] == '*') {
        buffer.write('/*');
        i++;
        inBlockComment = true;
        continue;
      }
    }

    if (dollarTag != null) {
      buffer.write(ch);
      if (ch == r'$' && startsWithAt(i, dollarTag)) {
        buffer.write(dollarTag.substring(1));
        i += dollarTag.length - 1;
        dollarTag = null;
      }
      continue;
    }

    if (!inSingleQuote && !inDoubleQuote && ch == r'$') {
      final nextDollar = sql.indexOf(r'$', i + 1);
      if (nextDollar != -1) {
        final tag = sql.substring(i, nextDollar + 1);
        if (RegExp(r'^\$[A-Za-z0-9_]*\$$').hasMatch(tag)) {
          dollarTag = tag;
          buffer.write(tag);
          i = nextDollar;
          continue;
        }
      }
    }

    if (!inDoubleQuote && ch == "'") {
      buffer.write(ch);
      if (inSingleQuote) {
        if (i + 1 < sql.length && sql[i + 1] == "'") {
          buffer.write("'");
          i++;
        } else {
          inSingleQuote = false;
        }
      } else {
        inSingleQuote = true;
      }
      continue;
    }

    if (!inSingleQuote && ch == '"') {
      buffer.write(ch);
      inDoubleQuote = !inDoubleQuote;
      continue;
    }

    if (!inSingleQuote && !inDoubleQuote && ch == ';') {
      final stmt = buffer.toString().trim();
      if (stmt.isNotEmpty) statements.add(stmt);
      buffer.clear();
      continue;
    }

    buffer.write(ch);
  }

  final last = buffer.toString().trim();
  if (last.isNotEmpty) statements.add(last);

  return statements;
}

Future<void> main(List<String> args) async {
  final migrationsDir = Directory('migrations');
  if (!migrationsDir.existsSync()) {
    stderr.writeln('Missing migrations directory at: ${migrationsDir.path}');
    exitCode = 2;
    return;
  }

  final files = migrationsDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (files.isEmpty) {
    stdout.writeln('No .sql migrations found in ${migrationsDir.path}');
    return;
  }

  final pool = getPool();

  try {
    await pool.withConnection((conn) async {
      for (final file in files) {
        stdout.writeln('Applying migration: ${file.path}');
        final sql = await file.readAsString();
        final statements = _splitSqlStatements(sql);

        for (final statement in statements) {
          await conn.execute(statement);
        }
      }
    });

    stdout.writeln('Migrations applied successfully.');
  } on PgException catch (e) {
    stderr.writeln('Migration failed: ${e.message}');
    exitCode = 1;
  } on SocketException catch (e) {
    stderr.writeln('Migration failed: cannot reach PostgreSQL (${e.message})');
    exitCode = 1;
  } catch (e) {
    stderr.writeln('Migration failed: $e');
    exitCode = 1;
  } finally {
    await pool.close();
  }
}
