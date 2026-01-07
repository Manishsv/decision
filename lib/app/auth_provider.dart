/// Auth provider for checking authentication status on app startup

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decision_agent/data/google/google_auth_service.dart';
import 'package:decision_agent/app/db_provider.dart' show globalDb;

/// Global singleton instance for auth service
/// This ensures all parts of the app use the same instance,
/// which is important for maintaining the in-memory token cache
/// Uses a shared database instance for credential storage
final _globalAuthService = GoogleAuthService(globalDb);

/// Singleton provider for GoogleAuthService
/// This ensures all parts of the app use the same instance,
/// which is important for maintaining the in-memory token cache
final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  // Use the same global singleton instance
  return _globalAuthService;
});

final authStatusProvider = FutureProvider<bool>((ref) async {
  final authService = ref.read(googleAuthServiceProvider);
  return await authService.isAuthenticated();
});

/// User profile information
class UserProfile {
  final String email;
  final String? name;
  final String? pictureUrl;

  UserProfile({
    required this.email,
    this.name,
    this.pictureUrl,
  });
}

/// Provider for user profile information
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final authService = ref.read(googleAuthServiceProvider);
  
  try {
    final email = await authService.getUserEmail();
    final name = await authService.getUserName();
    final pictureUrl = await authService.getUserPicture();
    
    return UserProfile(
      email: email,
      name: name,
      pictureUrl: pictureUrl,
    );
  } catch (e) {
    return null;
  }
});

/// Export the global auth service for use in auth_guard
GoogleAuthService get globalAuthService => _globalAuthService;
