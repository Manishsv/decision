/// Auth provider for checking authentication status on app startup

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decision_agent/data/google/google_auth_service.dart';

/// Global singleton instance for auth service
/// This ensures all parts of the app use the same instance,
/// which is important for maintaining the in-memory token cache
final _globalAuthService = GoogleAuthService();

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

/// Export the global auth service for use in auth_guard
GoogleAuthService get globalAuthService => _globalAuthService;
