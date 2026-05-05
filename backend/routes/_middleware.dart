import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

import 'package:ghanaclass_backend/db/postgres_pool.dart';
import 'package:ghanaclass_backend/http/http_exceptions.dart';

/// Basic JSON + error handling middleware.
Handler middleware(Handler handler) {
  final withPool = handler
      .use(provider<Pool>((_) => getPool()))
      .use(requestLogger());

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
      return Response.json(statusCode: 500, body: {'error': e.message});
    } on FormatException catch (e) {
      return Response.json(statusCode: 500, body: {'error': e.message});
    }
  };
}
