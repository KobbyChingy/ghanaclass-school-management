import 'dart:convert';

import 'package:http/http.dart' as http;

class RemoteAuthApi {
  RemoteAuthApi({
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

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    String? role,
  }) async {
    return _postJson(
      '/auth/login',
      body: {
        'email': email,
        'password': password,
        if (role != null && role.trim().isNotEmpty) 'role': role.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> registerSchool({
    required String code,
    required String name,
    required String adminEmail,
    required String adminPassword,
    required String adminFullName,
  }) async {
    return _postJson(
      '/auth/register_school',
      body: {
        'code': code,
        'name': name,
        'adminEmail': adminEmail,
        'adminPassword': adminPassword,
        'adminFullName': adminFullName,
      },
    );
  }

  Future<Map<String, dynamic>> registerStaff({
    required String adminToken,
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    return _postJson(
      '/auth/register_staff',
      headers: {
        'Authorization': 'Bearer $adminToken',
      },
      body: {
        'email': email,
        'password': password,
        'fullName': fullName,
        'role': role,
      },
    );
  }

  Future<Map<String, dynamic>> updateStaff({
    required String adminToken,
    required String email,
    String? fullName,
    String? role,
    bool? isActive,
  }) async {
    return _postJson(
      '/auth/update_staff',
      headers: {
        'Authorization': 'Bearer $adminToken',
      },
      body: {
        'email': email,
        if (fullName != null && fullName.trim().isNotEmpty) 'fullName': fullName,
        if (role != null && role.trim().isNotEmpty) 'role': role,
        if (isActive != null) 'isActive': isActive,
      },
    );
  }

  Future<Map<String, dynamic>> _postJson(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    final resp = await _client.post(
      _uri(path),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...?headers,
      },
      body: jsonEncode(body),
    );

    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) {
        json = decoded;
      }
    } catch (_) {
      // Ignore parse errors; we'll throw a generic error below.
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
