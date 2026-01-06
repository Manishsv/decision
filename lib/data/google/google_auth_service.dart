/// Google OAuth authentication service using flutter_appauth

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:http/http.dart' as http;
import 'package:decision_agent/core/config/oauth_config.dart';
import 'package:decision_agent/data/db/app_db.dart';
import 'package:decision_agent/data/db/dao.dart';

/// Helper function to extract email from ID token (JWT)
String? _extractEmailFromIdToken(String idToken) {
  try {
    final parts = idToken.split('.');
    if (parts.length < 2) {
      return null;
    }

    // Decode the payload (second part)
    final payload = parts[1];
    final padded = payload.padRight((payload.length + 3) ~/ 4 * 4, '=');
    final base64Payload = padded.replaceAll('-', '+').replaceAll('_', '/');
    final decoded = base64Decode(base64Payload);
    final jsonString = utf8.decode(decoded);
    final payloadJson = json.decode(jsonString) as Map<String, dynamic>;

    // Extract email from claims
    return payloadJson['email'] as String?;
  } catch (e) {
    debugPrint('Error extracting email from ID token: $e');
    return null;
  }
}

const String _refreshTokenKey = 'google_refresh_token';
const String _accessTokenKey = 'google_access_token';
const String _userEmailKey = 'user_email';

class GoogleAuthService {
  static const _appAuth = FlutterAppAuth();
  final AppDatabase _db;
  String? _userEmail;
  String? _cachedAccessToken; // Memory cache for performance

  GoogleAuthService(AppDatabase db) : _db = db;

  /// Sign in with Google OAuth
  Future<void> signIn() async {
    try {
      OAuthConfig.validate();

      debugPrint('Starting Google OAuth2 Sign-In with PKCE...');

      // For macOS, ensure the app is activated before showing sign-in dialog
      if (!kIsWeb) {
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Perform authorization with PKCE
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          OAuthConfig.clientId,
          OAuthConfig.redirectUri,
          discoveryUrl: OAuthConfig.discoveryUrl,
          scopes: OAuthConfig.scopes,
          clientSecret: OAuthConfig.clientSecret,
        ),
      );

      if (result.accessToken == null) {
        throw Exception('Failed to obtain access token');
      }

      debugPrint('OAuth2 authorization successful');

      // Get user email
      String? email;

      try {
        // Fetch user info using the access token
        final response = await http
            .get(
              Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'),
              headers: {'Authorization': 'Bearer ${result.accessToken}'},
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final userInfo = json.decode(response.body) as Map<String, dynamic>;
          email = userInfo['email'] as String?;
        }
      } catch (e) {
        debugPrint('Could not fetch user info: $e');
        // Try to extract email from ID token as fallback
        if (result.idToken != null && result.idToken!.isNotEmpty) {
          email = _extractEmailFromIdToken(result.idToken!);
        }
      }

      if (email == null || email.isEmpty) {
        throw Exception('Could not determine user email');
      }

      _userEmail = email;

      // Store tokens in database (cross-platform, works on Windows, macOS, Linux)
      if (result.accessToken != null) {
        await _db.saveCredential(_accessTokenKey, result.accessToken!);
        _cachedAccessToken =
            result.accessToken; // Cache in memory for performance
        debugPrint('Access token stored in database');
      }
      if (result.refreshToken != null) {
        await _db.saveCredential(_refreshTokenKey, result.refreshToken!);
        debugPrint('Refresh token stored in database');
      }
      await _db.saveCredential(_userEmailKey, email);
      debugPrint('User email stored in database');

      debugPrint('OAuth2 authorization successful for email: $email');
    } catch (e, stack) {
      debugPrint('Error during Google OAuth2 Sign-In: $e');
      debugPrint('Stack: $stack');

      // Check if this is a user cancellation error
      final errorStr = e.toString();
      if (errorStr.contains('UserCancelledException') ||
          errorStr.contains('UserCancelled') ||
          errorStr.contains('Code=-3') ||
          errorStr.contains('Code=1')) {
        debugPrint('User cancelled Google Sign-In');
        throw Exception('Sign-in cancelled by user');
      }

      rethrow;
    }
  }

  /// Sign out from Google (clears stored tokens)
  Future<void> signOut() async {
    try {
      await _db.deleteCredential(_accessTokenKey);
      await _db.deleteCredential(_refreshTokenKey);
      await _db.deleteCredential(_userEmailKey);
      _userEmail = null;
      _cachedAccessToken = null; // Clear memory cache
      debugPrint('OAuth2 Sign-Out successful');
    } catch (e) {
      debugPrint('Error during OAuth2 Sign-Out: $e');
      rethrow;
    }
  }

  /// Get current stored access token
  Future<String?> getAccessToken() async {
    // First check memory cache (performance optimization)
    if (_cachedAccessToken != null && _cachedAccessToken!.isNotEmpty) {
      return _cachedAccessToken;
    }

    // Get from database (cross-platform)
    try {
      final stored = await _db.getCredential(_accessTokenKey);
      if (stored != null && stored.isNotEmpty) {
        // Update cache for future use
        _cachedAccessToken = stored;
        return stored;
      }
    } catch (e) {
      debugPrint('Error reading access token from database: $e');
    }

    return null;
  }

  /// Get user email
  Future<String> getUserEmail() async {
    if (_userEmail != null) {
      return _userEmail!;
    }

    // Get from database (cross-platform)
    try {
      final cached = await _db.getCredential(_userEmailKey);
      if (cached != null && cached.isNotEmpty) {
        _userEmail = cached;
        return cached;
      }
    } catch (e) {
      debugPrint('Error reading email from database: $e');
    }

    throw Exception('User email not available. Please sign in again.');
  }

  /// Check if user is authenticated and token is valid
  /// Validates the access token by making a test API call
  Future<bool> isAuthenticated() async {
    try {
      final accessToken = await getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        debugPrint('No access token found');
        return false;
      }

      debugPrint('Checking token validity...');

      // Try to refresh token if needed, or validate current token
      try {
        // Test token validity by fetching user info
        final response = await http
            .get(
              Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'),
              headers: {'Authorization': 'Bearer $accessToken'},
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          // Token is valid
          final userInfo = json.decode(response.body) as Map<String, dynamic>;
          final email = userInfo['email'] as String?;
          if (email != null) {
            _userEmail = email;
            // Update stored email in database
            await _db.saveCredential(_userEmailKey, email);
          }
          return true;
        } else if (response.statusCode == 401) {
          // Token expired, try to refresh
          debugPrint('Access token expired, attempting refresh...');
          return await _refreshAccessToken();
        } else {
          debugPrint(
            'Token validation failed with status: ${response.statusCode}',
          );
          return false;
        }
      } catch (e) {
        debugPrint('Error validating token: $e');
        // If validation fails, try refresh
        return await _refreshAccessToken();
      }
    } catch (e) {
      debugPrint('Error checking sign-in status: $e');
      return false;
    }
  }

  /// Refresh access token using refresh token
  Future<bool> _refreshAccessToken() async {
    try {
      // Get refresh token from database (cross-platform)
      final refreshToken = await _db.getCredential(_refreshTokenKey);

      if (refreshToken == null || refreshToken.isEmpty) {
        debugPrint('No refresh token available');
        return false;
      }

      debugPrint('Refreshing access token...');

      final result = await _appAuth.token(
        TokenRequest(
          OAuthConfig.clientId,
          OAuthConfig.redirectUri,
          refreshToken: refreshToken,
          discoveryUrl: OAuthConfig.discoveryUrl,
          clientSecret: OAuthConfig.clientSecret,
        ),
      );

      if (result.accessToken == null || result.accessToken!.isEmpty) {
        debugPrint('Failed to refresh access token');
        return false;
      }

      // Store new access token in database
      await _db.saveCredential(_accessTokenKey, result.accessToken!);
      _cachedAccessToken = result.accessToken!; // Update memory cache

      // Update refresh token if a new one was provided
      if (result.refreshToken != null && result.refreshToken!.isNotEmpty) {
        await _db.saveCredential(_refreshTokenKey, result.refreshToken!);
      }

      debugPrint('Access token refreshed successfully');
      return true;
    } catch (e) {
      debugPrint('Error refreshing access token: $e');
      return false;
    }
  }

  /// Get authenticated HTTP client (for use with googleapis package)
  /// This method returns an http.Client with Authorization header set
  /// Automatically refreshes token if expired
  Future<http.Client> getAuthClient() async {
    // Ensure we have a valid token (refresh if needed)
    final isAuth = await isAuthenticated();
    if (!isAuth) {
      throw Exception('Not authenticated. Call signIn() first.');
    }

    final accessToken = await getAccessToken();
    if (accessToken == null) {
      throw Exception('Not authenticated. Call signIn() first.');
    }

    return _AuthenticatedClient(accessToken);
  }
}

/// HTTP client that adds Authorization header to all requests
class _AuthenticatedClient extends http.BaseClient {
  final String _accessToken;
  final http.Client _inner = http.Client();

  _AuthenticatedClient(this._accessToken);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_accessToken';
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}
