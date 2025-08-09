import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

class PasswordEncryptionService {
  /// Encrypts password deterministically using PBKDF2 to match React implementation
  static Future<String> encryptPasswordDeterministic(String password, String email) async {
    try {
      // Step 1: Create deterministic salt from email (same as React)
      final emailBytes = utf8.encode(email.toLowerCase().trim());
      final emailHashBytes = sha256.convert(emailBytes).bytes;
      final salt = Uint8List.fromList(emailHashBytes.take(16).toList()); // First 16 bytes
      
      // Step 2: Apply PBKDF2 with same parameters as React
      final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
        ..init(Pbkdf2Parameters(salt, 50000, 16)); // 50k iterations, 16 bytes output
      
      final passwordBytes = utf8.encode(password);
      final derivedKey = pbkdf2.process(passwordBytes);
      
      // Step 3: Encode to Base64 (same as React)
      final saltBase64 = base64.encode(salt);
      final hashBase64 = base64.encode(derivedKey);
      
      // Step 4: Format as salt.hash (same as React)
      final result = '$saltBase64.$hashBase64';
      
      // Step 5: Ensure length constraint for Supabase
      if (result.length > 72) {
        throw Exception('Encrypted password too long for Supabase: ${result.length} characters');
      }
      
      return result;
    } catch (e) {
      throw Exception('Password encryption failed: $e');
    }
  }
  
  /// Validates if a password matches the encrypted version
  static Future<bool> validatePassword(String password, String email, String encryptedPassword) async {
    try {
      final encrypted = await encryptPasswordDeterministic(password, email);
      return encrypted == encryptedPassword;
    } catch (e) {
      return false;
    }
  }
}