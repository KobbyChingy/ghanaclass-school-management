import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

import 'package:ghanaclass_backend/http/http_exceptions.dart';
import 'package:ghanaclass_backend/tenancy/tenant_schema.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final tenant = await resolveTenantContext(
    context,
    required: true,
    allowHeaderFallback: false,
  );
  final schoolId = tenant.schoolId;
  final schema = tenant.schoolSchema;

  final body = await context.request.body();
  final jsonBody = json.decode(body);
  if (jsonBody is! Map<String, dynamic>) {
    throw BadRequestException('Expected a JSON object');
  }

  final sinceRaw = jsonBody['since'];
  final since = switch (sinceRaw) {
    int v => v,
    String v => int.tryParse(v) ?? 0,
    _ => 0,
  };

  final pool = context.read<Pool>();

  final rows = await pool.withConnection((conn) async {
    await conn.execute('SET search_path TO $schema, public');

    return conn.execute(
      Sql.named(
        'SELECT seq, entity_type, operation, payload, changed_at '
        'FROM change_log '
        'WHERE seq > @since '
        'ORDER BY seq ASC '
        'LIMIT 1000',
      ),
      parameters: {'since': since},
    );
  });

  var cursor = since;
  final changes = <Map<String, dynamic>>[];

  for (final row in rows) {
    final seq = row[0] as int;
    final entityType = row[1] as String;
    final operation = row[2] as String;
    final payload = row[3];
    final changedAt = row[4] as DateTime;

    if (seq > cursor) cursor = seq;

    changes.add({
      'seq': seq,
      'entityType': entityType,
      'operation': operation,
      'payload': payload,
      'changedAt': changedAt.toUtc().toIso8601String(),
    });
  }

  return Response.json(
    body: {
      'cursor': cursor,
      'schoolId': schoolId,
      'schoolSchema': schema,
      'changes': changes,
    },
  );
}
