import 'dart:io';

import 'package:dotenv/dotenv.dart';

final _envMap = (() {
  final env = DotEnv(includePlatformEnvironment: true, quiet: true);
  final cwd = Directory.current.path.replaceAll('\\', '/');
  env.load([
    '$cwd/.env',
    '$cwd/backend/.env',
  ]);
  return env;
})();

String envString(String key, {String? defaultValue}) {
  final value = _envMap[key];
  if (value != null && value.trim().isNotEmpty) return value.trim();
  if (defaultValue != null) return defaultValue;
  throw StateError('Missing required env var: $key');
}

bool envBool(String key, {bool defaultValue = false}) {
  final raw = _envMap[key];
  if (raw == null || raw.trim().isEmpty) return defaultValue;

  final normalized = raw.trim().toLowerCase();
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}

int envInt(String key, {required int defaultValue}) {
  final raw = _envMap[key];
  if (raw == null || raw.trim().isEmpty) return defaultValue;
  return int.parse(raw.trim());
}
