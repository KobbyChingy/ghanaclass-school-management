import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

import 'package:ghanaclass_backend/http/http_exceptions.dart';
import 'package:ghanaclass_backend/tenancy/tenant_schema.dart';

final _uuidRegExp = RegExp(
  r'^[0-9a-fA-F]{8}-'
  r'[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{12}$',
);

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

  final deviceId = (jsonBody['deviceId'] as String?)?.trim();
  final ops = jsonBody['ops'];

  if (deviceId == null || deviceId.isEmpty) {
    throw BadRequestException('Missing deviceId');
  }
  if (ops is! List) {
    throw BadRequestException('Missing ops list');
  }

  final pool = context.read<Pool>();

  final acked = <String>[];

  await pool.withConnection((conn) async {
    await conn.execute('SET search_path TO $schema, public');

    for (final raw in ops) {
      if (raw is! Map) {
        continue;
      }

      final opId = (raw['opId'] as String?)?.trim();
      final entityType = (raw['entityType'] as String?)?.trim();
      final operation = (raw['operation'] as String?)?.trim();
      final payload = raw['payload'];

      if (opId == null || !_uuidRegExp.hasMatch(opId)) {
        continue;
      }
      if (entityType == null || entityType.isEmpty) {
        continue;
      }
      if (operation == null || operation.isEmpty) {
        continue;
      }

      final applied = await conn.execute(
        Sql.named(
          'INSERT INTO public.applied_ops(op_id, school_id, school_schema, device_id) '
          'VALUES (@opId::uuid, @schoolId::uuid, @schoolSchema, @deviceId) '
          'ON CONFLICT (op_id) DO NOTHING',
        ),
        parameters: {
          'opId': opId,
          'schoolId': schoolId,
          'schoolSchema': schema,
          'deviceId': deviceId,
        },
      );

      // If 0 rows inserted, it means the op was already applied.
      // We still return it as acked to keep the client moving.
      if (applied.affectedRows > 0) {
        await conn.execute(
          Sql.named(
            'INSERT INTO change_log(entity_type, operation, payload) '
            'VALUES (@entityType, @operation, @payload::jsonb)',
          ),
          parameters: {
            'entityType': entityType,
            'operation': operation,
            'payload': jsonEncode(payload ?? const {}),
          },
        );
      }

      acked.add(opId);
    }
  });

  return Response.json(
    body: {
      'ackedOpIds': acked,
      'schoolId': schoolId,
      'schoolSchema': schema,
      'serverTime': DateTime.now().toUtc().toIso8601String(),
    },
  );
}
