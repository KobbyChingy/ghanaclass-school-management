import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class PasswordHasher {
  static const int _saltLength = 16;
  static const int _iterations = 10000;

  /// Generate a random salt
  static String _generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(_saltLength, (_) => random.nextInt(256));
    return base64Encode(saltBytes);
  }

  /// Hash a password with a salt
  static String hashPassword(String password) {
    final salt = _generateSalt();
    final hash = _hashWithSalt(password, salt);
    return '$salt:$hash';
  }

  /// Verify a password against a hash
  static bool verifyPassword(String password, String storedHash) {
    final parts = storedHash.split(':');
    if (parts.length != 2) return false;

    final salt = parts[0];
    final hash = parts[1];
    final computedHash = _hashWithSalt(password, salt);

    return hash == computedHash;
  }

  /// Internal method to hash password with salt
  static String _hashWithSalt(String password, String salt) {
    var bytes = utf8.encode(password + salt);
    
    // Perform multiple iterations for security
    for (var i = 0; i < _iterations; i++) {
      bytes = Uint8List.fromList(sha256.convert(bytes).bytes);
    }
    
    return base64Encode(bytes);
  }
}
