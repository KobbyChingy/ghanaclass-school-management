import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

import 'package:ghanaclass_backend/auth/auth_context.dart';
import 'package:ghanaclass_backend/http/http_exceptions.dart';

class TenantContext {
  const TenantContext({
    required this.schoolId,
    required this.schoolSchema,
    required this.authenticated,
  });

  final String? schoolId;
  final String schoolSchema;
  final bool authenticated;
}

/// Determines which PostgreSQL schema to use for the request.
///
/// Prefer the authenticated user's school context.
///
/// When authenticated, resolve the schema from `public.schools` using
/// `school_id` first so the backend does not depend on a JWT schema claim.
///
/// The `x-school-schema` header remains as a compatibility fallback for older
/// clients and unauthenticated bootstrap flows.
Future<TenantContext> resolveTenantContext(
  RequestContext context, {
  bool required = false,
  bool allowHeaderFallback = true,
}) async {
  try {
    final authUser = requireAuth(context);
    final pool = context.read<Pool>();
    final rows = await pool.withConnection(
      (conn) => conn.execute(
        Sql.named(
          'SELECT schema_name '
          'FROM public.schools '
          'WHERE id = @schoolId::uuid '
          'LIMIT 1',
        ),
        parameters: {'schoolId': authUser.schoolId},
      ),
    );

    final resolvedSchema = rows.isNotEmpty
        ? rows.first[0]?.toString()
        : authUser.schoolSchema;
    if (resolvedSchema == null || resolvedSchema.isEmpty) {
      throw UnauthorizedException('Invalid tenant context');
    }

    return TenantContext(
      schoolId: authUser.schoolId,
      schoolSchema: resolvedSchema,
      authenticated: true,
    );
  } on UnauthorizedException {
    if (!allowHeaderFallback) rethrow;
    // Fall back to the legacy header-based contract below.
  }

  final header = context.request.headers['x-school-schema'];
  if (header == null || header.trim().isEmpty) {
    if (required) {
      throw BadRequestException('Missing x-school-schema header');
    }
    return const TenantContext(
      schoolId: null,
      schoolSchema: 'public',
      authenticated: false,
    );
  }

  // Very small guardrail: allow only letters, numbers and underscores.
  final value = header.trim();
  final ok = RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value);
  if (!ok) {
    throw BadRequestException('Invalid x-school-schema header');
  }

  return TenantContext(
    schoolId: null,
    schoolSchema: value,
    authenticated: false,
  );
}

Future<String> resolveSchoolSchema(
  RequestContext context, {
  bool required = false,
  bool allowHeaderFallback = true,
}) async {
  return (await resolveTenantContext(
    context,
    required: required,
    allowHeaderFallback: allowHeaderFallback,
  ))
      .schoolSchema;
}
