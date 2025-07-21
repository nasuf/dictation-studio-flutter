import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';

class TokenManager {
  // Use the same token keys as UI project
  static const String _accessTokenKey = 'ds_a_token';
  static const String _refreshTokenKey = 'ds_r_token';
  static const String _baseUrl = 'https://www.dictationstudio.com/ds';

  // Token refresh threshold (10 minutes in seconds)
  static const int _tokenRefreshThreshold = 600;

  // Get access token from shared preferences
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  // Get refresh token from shared preferences
  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  // Save access token to shared preferences
  static Future<void> saveAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, token);
    AppLogger.info('✅ Access token saved with key: $_accessTokenKey');
  }

  // Save refresh token to shared preferences
  static Future<void> saveRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_refreshTokenKey, token);
    AppLogger.info('✅ Refresh token saved with key: $_refreshTokenKey');
  }

  // Clear all tokens
  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    AppLogger.info('🗑️ All tokens cleared');
  }

  // Simple JWT payload decoder (without verification)
  static Map<String, dynamic>? _decodeJWTPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      // Decode the payload (second part)
      final payload = parts[1];

      // Add padding if needed
      String normalizedPayload = payload;
      switch (payload.length % 4) {
        case 0:
          break;
        case 2:
          normalizedPayload += '==';
          break;
        case 3:
          normalizedPayload += '=';
          break;
        default:
          return null;
      }

      final decoded = base64Url.decode(normalizedPayload);
      final payloadString = utf8.decode(decoded);
      return jsonDecode(payloadString) as Map<String, dynamic>;
    } catch (e) {
      AppLogger.warning('⚠️ Error decoding JWT payload: $e');
      return null;
    }
  }

  // Check if access token is expired or about to expire
  static Future<bool> isTokenExpiringSoon() async {
    final accessToken = await getAccessToken();
    if (accessToken == null) return true;

    final payload = _decodeJWTPayload(accessToken);
    if (payload == null) return true;

    if (payload['exp'] != null) {
      final expirationTime = payload['exp'] as int;
      final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Check if token expires within the threshold
      return (expirationTime - currentTime) < _tokenRefreshThreshold;
    }

    return false;
  }

  // Refresh access token using refresh token
  static Future<String?> refreshAccessToken() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) {
      AppLogger.warning('❌ No refresh token available');
      return null;
    }

    try {
      AppLogger.info('🔄 Refreshing access token...');

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/refresh-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $refreshToken',
        },
      );

      AppLogger.info('Refresh token response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        // Extract new access token from headers
        final newAccessToken = response.headers['x-ds-access-token'];
        final newRefreshToken = response.headers['x-ds-refresh-token'];

        if (newAccessToken != null) {
          await saveAccessToken(newAccessToken);

          // Save new refresh token if provided
          if (newRefreshToken != null) {
            await saveRefreshToken(newRefreshToken);
          }

          AppLogger.info('✅ Access token refreshed successfully');
          return newAccessToken;
        } else {
          AppLogger.warning('❌ No access token in refresh response headers');
          return null;
        }
      } else {
        AppLogger.warning('❌ Token refresh failed: ${response.statusCode}');
        // If refresh fails, clear all tokens
        await clearTokens();
        return null;
      }
    } catch (e) {
      AppLogger.error('❌ Error refreshing token: $e');
      await clearTokens();
      return null;
    }
  }

  // Get valid access token (refresh if necessary)
  static Future<String?> getValidAccessToken() async {
    // Check if current token is about to expire
    if (await isTokenExpiringSoon()) {
      AppLogger.info('🔄 Token is expiring soon, refreshing...');
      return await refreshAccessToken();
    }

    // Return current token if it's still valid
    return await getAccessToken();
  }

  // Extract tokens from HTTP response headers (matching UI project logic)
  static Future<void> handleTokensFromResponse(http.Response response) async {
    // Match UI project header names: x-ds-access-token and x-ds-refresh-token
    final accessToken = response.headers['x-ds-access-token'];
    final refreshToken = response.headers['x-ds-refresh-token'];

    AppLogger.info('Checking response headers for tokens...');
    AppLogger.info('x-ds-access-token found: ${accessToken != null}');
    AppLogger.info('x-ds-refresh-token found: ${refreshToken != null}');

    if (accessToken != null) {
      await saveAccessToken(accessToken);
    }

    if (refreshToken != null) {
      await saveRefreshToken(refreshToken);
    }
  }

  // Get authorization headers for API requests (simplified version)
  static Future<Map<String, String>> getAuthHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // Get valid token (with automatic refresh if needed)
    final accessToken = await getValidAccessToken();
    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
      AppLogger.info('🔐 Authorization header added');
    } else {
      AppLogger.warning('⚠️ No valid access token available');
    }

    return headers;
  }
}
