import 'dart:convert';

import 'package:http/http.dart' as http;

class RemoteSyncApi {
  RemoteSyncApi({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Uri _uri(String path) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalizedBase$normalizedPath');
  }

  Future<Map<String, dynamic>> push({
    String? schoolSchema,
    required String deviceId,
    required List<Map<String, dynamic>> ops,
    String? bearerToken,
  }) async {
    return _postJson(
      '/sync/push',
      schoolSchema: schoolSchema,
      bearerToken: bearerToken,
      body: {
        'deviceId': deviceId,
        'ops': ops,
      },
    );
  }

  Future<Map<String, dynamic>> pull({
    String? schoolSchema,
    required int since,
    String? bearerToken,
  }) async {
    return _postJson(
      '/sync/pull',
      schoolSchema: schoolSchema,
      bearerToken: bearerToken,
      body: {
        'since': since,
      },
    );
  }

  Future<Map<String, dynamic>> _postJson(
    String path, {
    String? schoolSchema,
    required Map<String, dynamic> body,
    String? bearerToken,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final normalizedSchema = schoolSchema?.trim();
    if (normalizedSchema != null && normalizedSchema.isNotEmpty) {
      headers['x-school-schema'] = normalizedSchema;
    }

    final token = bearerToken?.trim();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final resp = await _client.post(
      _uri(path),
      headers: headers,
      body: jsonEncode(body),
    );

    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) {
        json = decoded;
      }
    } catch (_) {
      // Ignore parse errors; we'll throw generic below.
    }

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return json ?? <String, dynamic>{};
    }

    final error = json?['error']?.toString();
    final details = json?['details']?.toString();

    if (error != null && error.isNotEmpty) {
      throw Exception(details == null || details.isEmpty ? error : '$error ($details)');
    }

    throw Exception('Server request failed (${resp.statusCode})');
  }
}
