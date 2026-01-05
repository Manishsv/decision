/// Onboarding page

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:decision_agent/features/onboarding/onboarding_controller.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  Future<void> _handleSignIn() async {
    final controller = ref.read(onboardingControllerProvider.notifier);
    await controller.signInWithGoogle();
    
    // Navigation will be handled by the listener in build()
    // This ensures navigation happens after state updates
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    
    // Listen for successful sign-in and navigate automatically
    ref.listen<AsyncValue<void>>(onboardingControllerProvider, (previous, next) {
      // When sign-in completes successfully (was loading, now has value, no error)
      if (previous?.isLoading == true && next.hasValue && !next.hasError) {
        // Wait a moment for tokens to be stored, then verify and navigate
        // Increased delay to ensure Keychain writes complete
        Future.delayed(const Duration(milliseconds: 1000), () async {
          if (!mounted || !context.mounted) return;
          
          final controller = ref.read(onboardingControllerProvider.notifier);
          
          // Try multiple times with increasing delays if first check fails
          bool isAuth = false;
          for (int attempt = 0; attempt < 3; attempt++) {
            isAuth = await controller.isAuthenticated();
            if (isAuth) break;
            
            if (attempt < 2) {
              // Wait a bit longer before retry
              await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
            }
          }
          
          if (isAuth && mounted && context.mounted) {
            context.go('/home');
          } else if (mounted && context.mounted) {
            // If auth check fails, show error with more details
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sign-in completed but authentication verification failed. This may be due to Keychain access issues. Please try restarting the app.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
              ),
            );
          }
        });
      }
    });

    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 500,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.mail_outline,
                size: 64,
                color: Colors.blue,
              ),
              const SizedBox(height: 32),
              const Text(
                'DIGIT Decision',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Welcome! Let\'s get you set up.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 48),
              
              // Google Sign In button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: state.isLoading ? null : _handleSignIn,
                  icon: const Icon(Icons.account_circle),
                  label: const Text('Sign in with Google'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Status/Error
              if (state.isLoading)
                const CircularProgressIndicator()
              else if (state.hasError)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Text(
                    'Error: ${state.error}',
                    style: TextStyle(color: Colors.red[800]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
