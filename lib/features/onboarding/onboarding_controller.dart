/// Onboarding controller (Riverpod provider)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decision_agent/data/google/google_auth_service.dart';
import 'package:decision_agent/app/auth_provider.dart';

class OnboardingController extends StateNotifier<AsyncValue<void>> {
  final GoogleAuthService _authService;
  
  OnboardingController(this._authService) : super(const AsyncValue.data(null));

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      await _authService.signIn();
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<bool> isAuthenticated() async {
    return await _authService.isAuthenticated();
  }
}

final onboardingControllerProvider = StateNotifierProvider<OnboardingController, AsyncValue<void>>((ref) {
  // Use the shared provider instance instead of creating a new one
  final authService = ref.read(googleAuthServiceProvider);
  return OnboardingController(authService);
});
