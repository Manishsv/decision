/// Google OAuth authentication service using flutter_appauth

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:decision_agent/core/config/oauth_config.dart';

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

const _storage = FlutterSecureStorage();
const String _refreshTokenKey = 'google_refresh_token';
const String _accessTokenKey = 'google_access_token';
const String _userEmailKey = 'user_email';

class GoogleAuthService {
  static const _appAuth = FlutterAppAuth();
  String? _userEmail;
  String? _cachedAccessToken; // Temporary cache if Keychain fails

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

      // Store tokens securely (try Keychain, but don't fail if it doesn't work)
      // Tokens will be stored in database by the calling code if Keychain fails
      bool tokensStored = false;
      try {
        if (result.accessToken != null) {
          await _storage.write(
            key: _accessTokenKey,
            value: result.accessToken!,
          );
          debugPrint('Access token stored');
        }
        if (result.refreshToken != null) {
          await _storage.write(
            key: _refreshTokenKey,
            value: result.refreshToken!,
          );
          debugPrint('Refresh token stored');
        }
        await _storage.write(key: _userEmailKey, value: email);
        debugPrint('User email stored');

        // Verify tokens were actually stored
        final verifyToken = await _storage.read(key: _accessTokenKey);
        if (verifyToken != null && verifyToken == result.accessToken) {
          tokensStored = true;
          debugPrint('OAuth2 tokens verified in Keychain');
        } else {
          debugPrint('Warning: Token storage verification failed');
        }
      } catch (e) {
        debugPrint('Warning: Could not store tokens in Keychain: $e');
        debugPrint('Tokens will be stored in database instead');
        // Continue - tokens will be saved to database by the calling code
      }

      if (!tokensStored && result.accessToken != null) {
        // If Keychain storage failed, at least keep token in memory temporarily
        // This allows immediate verification after sign-in
        _cachedAccessToken = result.accessToken;
        debugPrint('Keeping access token in memory for immediate use');
      }

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
      await _storage.delete(key: _accessTokenKey);
      await _storage.delete(key: _refreshTokenKey);
      await _storage.delete(key: _userEmailKey);
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
    // First check memory cache (works even if Keychain fails)
    if (_cachedAccessToken != null && _cachedAccessToken!.isNotEmpty) {
      debugPrint('Using cached access token from memory');
      return _cachedAccessToken;
    }

    // Then try to get from storage (may fail due to Keychain entitlements)
    try {
      final stored = await _storage.read(key: _accessTokenKey);
      if (stored != null && stored.isNotEmpty) {
        // Update cache for future use
        _cachedAccessToken = stored;
        return stored;
      }
    } catch (e) {
      debugPrint('Warning: Could not read from Keychain: $e');
      // Continue - we'll use memory cache if available
    }

    return null;
  }

  /// Get user email
  Future<String> getUserEmail() async {
    if (_userEmail != null) {
      return _userEmail!;
    }

    // Try to get from storage (may fail due to Keychain)
    try {
      final cached = await _storage.read(key: _userEmailKey);
      if (cached != null && cached.isNotEmpty) {
        _userEmail = cached;
        return cached;
      }
    } catch (e) {
      debugPrint('Warning: Could not read email from Keychain: $e');
      // Continue - will throw if email not in memory
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
            // Try to update stored email (may fail due to Keychain, but that's okay)
            try {
              await _storage.write(key: _userEmailKey, value: email);
            } catch (e) {
              debugPrint('Warning: Could not update email in Keychain: $e');
              // Continue - email is in memory
            }
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
        // Check if this is a network error vs Keychain error
        final errorStr = e.toString();
        if (errorStr.contains('PlatformException') &&
            errorStr.contains('-34018')) {
          // Keychain error - but we have token in memory, so try to use it
          debugPrint(
            'Keychain error during validation, but token exists in memory - considering authenticated',
          );
          return true; // If we have a token in memory, consider it valid
        }
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
      // Try to get refresh token from storage (may fail due to Keychain)
      String? refreshToken;
      try {
        refreshToken = await _storage.read(key: _refreshTokenKey);
      } catch (e) {
        debugPrint('Warning: Could not read refresh token from Keychain: $e');
        // If Keychain fails, we can't refresh - return false
        return false;
      }

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
        ),
      );

      if (result.accessToken == null || result.accessToken!.isEmpty) {
        debugPrint('Failed to refresh access token');
        return false;
      }

      // Store new access token (try Keychain, but cache in memory as fallback)
      _cachedAccessToken = result.accessToken!;
      try {
        await _storage.write(key: _accessTokenKey, value: result.accessToken!);
      } catch (e) {
        debugPrint('Warning: Could not store refreshed token in Keychain: $e');
        // Continue - token is in memory cache
      }

      // Update refresh token if a new one was provided
      if (result.refreshToken != null && result.refreshToken!.isNotEmpty) {
        try {
          await _storage.write(
            key: _refreshTokenKey,
            value: result.refreshToken!,
          );
        } catch (e) {
          debugPrint('Warning: Could not store refresh token in Keychain: $e');
          // Continue - we have the access token in memory
        }
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
