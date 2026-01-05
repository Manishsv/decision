import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// OAuth2 configuration for Google authentication
/// 
/// Values are loaded from .env file (see .env.example for template)
/// The .env file is not committed to version control for security.
class OAuthConfig {
  // Google OAuth2 Client ID
  // Loaded from .env file: GOOGLE_OAUTH_CLIENT_ID
  static String get clientId {
    final envClientId = dotenv.env['GOOGLE_OAUTH_CLIENT_ID'];
    if (envClientId != null && envClientId.isNotEmpty) {
      return envClientId;
    }
    throw Exception('GOOGLE_OAUTH_CLIENT_ID not found in .env file. Please create .env file with your OAuth credentials.');
  }

  // Google OAuth2 Client Secret
  // Loaded from .env file: GOOGLE_OAUTH_CLIENT_SECRET
  // Note: For Desktop Apps, Google requires client secret during token exchange
  // even when using PKCE. PKCE adds security but doesn't eliminate the secret requirement.
  static String get clientSecret {
    final envClientSecret = dotenv.env['GOOGLE_OAUTH_CLIENT_SECRET'];
    if (envClientSecret != null && envClientSecret.isNotEmpty) {
      return envClientSecret;
    }
    throw Exception('GOOGLE_OAUTH_CLIENT_SECRET not found in .env file. Please create .env file with your OAuth credentials.');
  }

  // Redirect URI for macOS (matches CFBundleURLSchemes in Info.plist)
  // Loaded from .env file: GOOGLE_OAUTH_REDIRECT_URI
  static String get redirectUri {
    final envRedirectUri = dotenv.env['GOOGLE_OAUTH_REDIRECT_URI'];
    if (envRedirectUri != null && envRedirectUri.isNotEmpty) {
      return envRedirectUri;
    }
    throw Exception('GOOGLE_OAUTH_REDIRECT_URI not found in .env file. Please create .env file with your OAuth credentials.');
  }

  // Google OAuth2 discovery document URL
  static const String discoveryUrl =
      'https://accounts.google.com/.well-known/openid-configuration';

  // OAuth2 scopes matching what's configured in Google Cloud Console
  // These scopes must match exactly what's enabled in your OAuth 2.0 Client ID
  static const List<String> scopes = [
    'https://www.googleapis.com/auth/userinfo.email', // See your primary Google Account email address
    'https://www.googleapis.com/auth/userinfo.profile', // See your personal info
    'https://mail.google.com/', // Read, compose, send, and permanently delete all your email from Gmail
  ];

  /// Validates that required OAuth configuration is present
  /// Throws an exception if configuration is invalid
  static void validate() {
    if (clientId.isEmpty) {
      throw Exception('OAuth Client ID is not configured');
    }
    if (clientSecret.isEmpty) {
      throw Exception('OAuth Client Secret is not configured');
    }
    if (redirectUri.isEmpty) {
      throw Exception('OAuth Redirect URI is not configured');
    }
    
    if (kDebugMode) {
      debugPrint('OAuth Config validated successfully');
      debugPrint('  Client ID: ${clientId.substring(0, clientId.length > 20 ? 20 : clientId.length)}...');
      debugPrint('  Redirect URI: $redirectUri');
    }
  }
}
