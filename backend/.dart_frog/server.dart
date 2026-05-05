// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, implicit_dynamic_list_literal

import 'dart:io';

import 'package:dart_frog/dart_frog.dart';


import '../routes/index.dart' as index;
import '../routes/sync/push/index.dart' as sync_push_index;
import '../routes/sync/pull/index.dart' as sync_pull_index;
import '../routes/auth/update_staff/index.dart' as auth_update_staff_index;
import '../routes/auth/register_staff/index.dart' as auth_register_staff_index;
import '../routes/auth/register_school/index.dart' as auth_register_school_index;
import '../routes/auth/login/index.dart' as auth_login_index;

import '../routes/_middleware.dart' as middleware;

void main() async {
  final address = InternetAddress.tryParse('') ?? InternetAddress.anyIPv6;
  final port = int.tryParse(Platform.environment['PORT'] ?? '8081') ?? 8081;
  hotReload(() => createServer(address, port));
}

Future<HttpServer> createServer(InternetAddress address, int port) {
  final handler = Cascade().add(buildRootHandler()).handler;
  return serve(handler, address, port);
}

Handler buildRootHandler() {
  final pipeline = const Pipeline().addMiddleware(middleware.middleware);
  final router = Router()
    ..mount('/auth/login', (context) => buildAuthLoginHandler()(context))
    ..mount('/auth/register_school', (context) => buildAuthRegisterSchoolHandler()(context))
    ..mount('/auth/register_staff', (context) => buildAuthRegisterStaffHandler()(context))
    ..mount('/auth/update_staff', (context) => buildAuthUpdateStaffHandler()(context))
    ..mount('/sync/pull', (context) => buildSyncPullHandler()(context))
    ..mount('/sync/push', (context) => buildSyncPushHandler()(context))
    ..mount('/', (context) => buildHandler()(context));
  return pipeline.addHandler(router);
}

Handler buildAuthLoginHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/', (context) => auth_login_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildAuthRegisterSchoolHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/', (context) => auth_register_school_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildAuthRegisterStaffHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/', (context) => auth_register_staff_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildAuthUpdateStaffHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/', (context) => auth_update_staff_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildSyncPullHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/', (context) => sync_pull_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildSyncPushHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/', (context) => sync_push_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/', (context) => index.onRequest(context,));
  return pipeline.addHandler(router);
}

