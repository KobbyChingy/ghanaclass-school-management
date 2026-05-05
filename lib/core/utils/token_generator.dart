import 'dart:convert';
import 'dart:math';

class TokenGenerator {
  static const int _tokenLength = 32;

  /// Generate a secure random token
  static String generateToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(_tokenLength, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  /// Generate a session token with expiry (24 hours default)
  static Map<String, dynamic> generateSessionToken({
    required int userId,
    Duration expiry = const Duration(hours: 24),
  }) {
    final token = generateToken();
    final expiresAt = DateTime.now().add(expiry);

    return {
      'token': token,
      'userId': userId,
      'expiresAt': expiresAt,
    };
  }
}
