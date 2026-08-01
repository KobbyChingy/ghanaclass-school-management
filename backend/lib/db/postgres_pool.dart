import 'dart:io';
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
  final uri = Uri.parse(value);

  if (uri.scheme.isEmpty) {
    throw FormatException('Invalid DATABASE_URL: missing scheme');
  }

  if (uri.host.isEmpty) {
    throw FormatException(
      'Invalid DATABASE_URL: missing host. Ensure the URL follows postgres://user:password@host:port/database?sslmode=require',
    );
  }

  final userInfo = uri.userInfo;
  if (userInfo.isEmpty || !userInfo.contains(':')) {
    throw FormatException('Invalid DATABASE_URL: missing user info or password');
  }

  final colonIndex = userInfo.indexOf(':');
  final username = Uri.decodeComponent(userInfo.substring(0, colonIndex));
  final password = Uri.decodeComponent(userInfo.substring(colonIndex + 1));
  final database = uri.pathSegments.isEmpty ? 'postgres' : uri.pathSegments.last;

  return _ParsedDatabaseUrl(
    host: uri.host,
    port: uri.hasPort ? uri.port : 5432,
    database: database,
    username: username,
    password: password,
    queryParameters: uri.queryParameters,
  );
}

bool _isProbablyValidHost(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return false;
  if (trimmed == 'localhost') return true;
  if (trimmed.startsWith('127.') || trimmed.startsWith('192.') || trimmed.startsWith('::1')) {
    return true;
  }
  return trimmed.contains('.') && !trimmed.contains('@');
}

({Endpoint endpoint, bool useSsl}) _buildSettingsFromEnvVars({required bool useSsl}) {
  final dbHost = envString('DB_HOST', defaultValue: '').trim();
  final dbName = envString('DB_NAME', defaultValue: '').trim();
  final dbUser = envString('DB_USER', defaultValue: '').trim();
  final dbPassword = envString('DB_PASSWORD', defaultValue: '').trim();

  if (dbHost.isEmpty || dbName.isEmpty || dbUser.isEmpty) {
    throw StateError(
      'Database environment variables are incomplete. ' 
      'Set DATABASE_URL or all of DB_HOST, DB_NAME, DB_USER, and DB_PASSWORD.',
    );
  }

  if (dbHost == dbUser) {
    throw StateError(
      'Invalid database configuration: DB_HOST is the same as DB_USER. ' 
      'Check for swapped environment variables or a malformed DATABASE_URL.',
    );
  }

  if (!_isProbablyValidHost(dbHost)) {
    throw StateError(
      'Invalid DB_HOST value: "$dbHost". ' 
      'DB_HOST should be a valid host or IP address for the Postgres server.',
    );
  }

  return (
    endpoint: Endpoint(
      host: dbHost,
      port: envInt('DB_PORT', defaultValue: 5432),
      database: dbName,
      username: dbUser,
      password: dbPassword,
    ),
    useSsl: useSsl,
  );
}

({Endpoint endpoint, bool useSsl}) _resolveConnectionSettings() {
  final databaseUrl = envString('DATABASE_URL', defaultValue: '').trim();
  if (databaseUrl.isNotEmpty) {
    try {
      final parsed = _parseDatabaseUrl(databaseUrl);
      final sslMode = (parsed.queryParameters['sslmode'] ?? '').trim().toLowerCase();

      if (parsed.host == parsed.username) {
        throw FormatException(
          'Invalid DATABASE_URL: parsed host matches the username. '
          'This usually means the URL is malformed or missing the @ separator. '
          'Check your DATABASE_URL environment variable.',
        );
      }

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
    } on FormatException catch (error) {
      final fallbackHost = envString('DB_HOST', defaultValue: '').trim();
      final fallbackName = envString('DB_NAME', defaultValue: '').trim();
      final fallbackUser = envString('DB_USER', defaultValue: '').trim();
      final fallbackPass = envString('DB_PASSWORD', defaultValue: '').trim();
      final fallbackSsl = envBool('DB_SSL', defaultValue: false);

      if (fallbackHost.isNotEmpty && fallbackName.isNotEmpty && fallbackUser.isNotEmpty) {
        stderr.writeln(
          'WARNING: Invalid DATABASE_URL; falling back to DB_* env vars. ${error.message}',
        );
        if (fallbackHost == fallbackUser) {
          throw FormatException(
            'Invalid DB_HOST/DB_USER configuration: DB_HOST is the same as DB_USER. '
            'Verify your backend environment variables.',
          );
        }

        return _buildSettingsFromEnvVars(useSsl: fallbackSsl);
      }

      rethrow;
    }
  }

  return _buildSettingsFromEnvVars(useSsl: envBool('DB_SSL', defaultValue: false));
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
