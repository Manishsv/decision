/// Auth guard for router - checks authentication status

import 'package:decision_agent/app/auth_provider.dart';

/// Check if user is authenticated
/// Returns true if authenticated, false otherwise
/// Uses the global singleton from auth_provider.dart
Future<bool> checkAuthStatus() async {
  try {
    return await globalAuthService.isAuthenticated();
  } catch (e) {
    return false;
  }
}
