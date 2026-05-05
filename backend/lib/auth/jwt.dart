import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'package:ghanaclass_backend/config/env.dart';

String issueJwt({
  required Map<String, dynamic> claims,
  Duration ttl = const Duration(hours: 12),
}) {
  final now = DateTime.now().toUtc();
  final exp = now.add(ttl).millisecondsSinceEpoch ~/ 1000;

  final header = <String, dynamic>{'alg': 'HS256', 'typ': 'JWT'};

  final payload = <String, dynamic>{
    ...claims,
    'iat': now.millisecondsSinceEpoch ~/ 1000,
    'exp': exp,
  };

  final encodedHeader = _b64UrlUtf8(jsonEncode(header));
  final encodedPayload = _b64UrlUtf8(jsonEncode(payload));
  final signingInput = '$encodedHeader.$encodedPayload';

  final secret = envString('JWT_SECRET', defaultValue: 'dev-secret-change-me');
  final signature = _b64UrlBytes(_hmacSha256(secret, signingInput));

  return '$signingInput.$signature';
}

Map<String, dynamic> verifyJwt(String token) {
  final parts = token.split('.');
  if (parts.length != 3) {
    throw FormatException('Invalid token format');
  }

  final signingInput = '${parts[0]}.${parts[1]}';
  final secret = envString('JWT_SECRET', defaultValue: 'dev-secret-change-me');
  final expectedSig = _b64UrlBytes(_hmacSha256(secret, signingInput));
  if (!_constantTimeEquals(parts[2], expectedSig)) {
    throw FormatException('Invalid token signature');
  }

  final payloadJson = utf8.decode(base64Url.decode(_padBase64(parts[1])));
  final payload = jsonDecode(payloadJson);
  if (payload is! Map<String, dynamic>) {
    throw FormatException('Invalid token payload');
  }

  final exp = payload['exp'];
  final expSeconds = switch (exp) {
    int v => v,
    String v => int.tryParse(v),
    _ => null,
  };

  if (expSeconds == null) {
    throw FormatException('Missing exp');
  }

  final nowSeconds = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
  if (nowSeconds >= expSeconds) {
    throw FormatException('Token expired');
  }

  return payload;
}

String _b64UrlUtf8(String input) => _b64UrlBytes(Uint8List.fromList(utf8.encode(input)));

String _b64UrlBytes(Uint8List bytes) {
  // base64Url.encode already uses URL-safe alphabet. Remove padding to match JWT.
  return base64Url.encode(bytes).replaceAll('=', '');
}

Uint8List _hmacSha256(String secret, String message) {
  final hmac = Hmac(sha256, utf8.encode(secret));
  final digest = hmac.convert(utf8.encode(message));
  return Uint8List.fromList(digest.bytes);
}

String _padBase64(String input) {
  final mod = input.length % 4;
  if (mod == 0) return input;
  return input + '=' * (4 - mod);
}

bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var result = 0;
  for (var i = 0; i < a.length; i++) {
    result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return result == 0;
}
