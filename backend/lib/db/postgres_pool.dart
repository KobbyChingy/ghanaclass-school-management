import 'package:postgres/postgres.dart';

import 'package:ghanaclass_backend/config/env.dart';

Pool? _pool;

class _ParsedDatabaseUrl {
  const _ParsedDatabaseUrl({
    required this.host,
    required this.port,
    required this.database,
    required this.username,
    required this.password,
    required this.queryParameters,
  });

  final String host;
  final int port;
  final String database;
  final String username;
  final String password;
  final Map<String, String> queryParameters;
}

_ParsedDatabaseUrl _parseDatabaseUrl(String raw) {
  final value = raw.trim();
  final schemeSeparator = value.indexOf('://');
  if (schemeSeparator <= 0) {
    throw FormatException('Invalid DATABASE_URL: missing scheme');
  }

  final remainder = value.substring(schemeSeparator + 3);
  final atIndex = remainder.lastIndexOf('@');
  if (atIndex <= 0 || atIndex >= remainder.length - 1) {
    throw FormatException('Invalid DATABASE_URL: missing user info or host');
  }

  final userInfo = remainder.substring(0, atIndex);
  final hostAndPath = remainder.substring(atIndex + 1);
  final colonIndex = userInfo.indexOf(':');
  final username = colonIndex == -1
      ? Uri.decodeComponent(userInfo)
      : Uri.decodeComponent(userInfo.substring(0, colonIndex));
  final password = colonIndex == -1
      ? ''
      : Uri.decodeComponent(userInfo.substring(colonIndex + 1));

  final normalized = Uri.parse(
    '${value.substring(0, schemeSeparator + 3)}placeholder:placeholder@$hostAndPath',
  );

  final database = normalized.pathSegments.isEmpty ? 'postgres' : normalized.pathSegments.last;

  return _ParsedDatabaseUrl(
    host: normalized.host,
    port: normalized.hasPort ? normalized.port : 5432,
    database: database,
    username: username,
    password: password,
    queryParameters: normalized.queryParameters,
  );
}

({Endpoint endpoint, bool useSsl}) _resolveConnectionSettings() {
  final databaseUrl = envString('DATABASE_URL', defaultValue: '').trim();
  if (databaseUrl.isNotEmpty) {
    final parsed = _parseDatabaseUrl(databaseUrl);
    final sslMode = (parsed.queryParameters['sslmode'] ?? '').trim().toLowerCase();

    return (
      endpoint: Endpoint(
        host: parsed.host,
        port: parsed.port,
        database: parsed.database,
        username: parsed.username,
        password: parsed.password,
      ),
      useSsl: sslMode == 'require' || sslMode == 'verify-full' || sslMode == 'verify-ca',
    );
  }

  final endpoint = Endpoint(
    host: envString('DB_HOST'),
    port: envInt('DB_PORT', defaultValue: 5432),
    database: envString('DB_NAME'),
    username: envString('DB_USER'),
    password: envString('DB_PASSWORD'),
  );

  final useSsl = envBool('DB_SSL', defaultValue: false);
  return (endpoint: endpoint, useSsl: useSsl);
}

Pool getPool() {
  final existing = _pool;
  if (existing != null) return existing;

  final settings = _resolveConnectionSettings();

  _pool = Pool.withEndpoints(
    [settings.endpoint],
    settings: PoolSettings(
      sslMode: settings.useSsl ? SslMode.require : SslMode.disable,
      maxConnectionCount: 10,
    ),
  );

  return _pool!;
}
