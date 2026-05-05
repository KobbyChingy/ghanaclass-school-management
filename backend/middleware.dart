import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

import 'package:ghanaclass_backend/db/postgres_pool.dart';
import 'package:ghanaclass_backend/http/http_exceptions.dart';

/// Provides a PostgreSQL [Pool] to all routes.
Handler middleware(Handler handler) {
  // Note: keep this lazy so the service can start even if DB env vars
  // are not configured yet. Routes that need the DB will fail when they
  // attempt to read the pool.
  final withPool = handler.use(provider<Pool>((_) => getPool()));

  return (context) async {
    try {
      return await withPool(context);
    } on BadRequestException catch (e) {
      return Response.json(statusCode: 400, body: {'error': e.message});
    } on UnauthorizedException catch (e) {
      return Response.json(statusCode: 401, body: {'error': e.message});
    } on ForbiddenException catch (e) {
      return Response.json(statusCode: 403, body: {'error': e.message});
    } on SocketException catch (e) {
      return Response.json(
        statusCode: 500,
        body: {'error': 'Database connection failed', 'details': e.message},
      );
    } on PgException catch (e) {
      return Response.json(
        statusCode: 500,
        body: {'error': 'Database error', 'details': e.message},
      );
    } on StateError catch (e) {
      // Typically missing required env vars for DB.
      return Response.json(statusCode: 500, body: {'error': e.message});
    } on FormatException catch (e) {
      // Typically malformed env vars (e.g. DB_PORT).
      return Response.json(statusCode: 500, body: {'error': e.message});
    }
  };
}
