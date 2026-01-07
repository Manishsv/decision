import 'package:go_router/go_router.dart';
import 'package:decision_agent/features/onboarding/onboarding_page.dart';
import 'package:decision_agent/features/home/home_page.dart';
import 'package:decision_agent/features/settings/settings_page.dart';
import 'package:decision_agent/features/profile/profile_page.dart';
import 'package:decision_agent/features/request_builder/request_builder_page.dart';
import 'package:decision_agent/app/auth_guard.dart';
import 'package:decision_agent/app/splash_page.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingPage(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfilePage(),
    ),
    GoRoute(
      path: '/request/new',
      builder: (context, state) {
        final conversationId = state.uri.queryParameters['conversationId'];
        final type = state.uri.queryParameters['type'] ?? 'conversation';
        return RequestBuilderPage(
          conversationId: conversationId,
          isNewConversation: type == 'conversation',
        );
      },
    ),
  ],
  redirect: (context, state) async {
    // Skip redirect for splash page
    if (state.matchedLocation == '/') {
      return null;
    }
    
    final isOnboarding = state.matchedLocation == '/onboarding';
    final isHome = state.matchedLocation == '/home';
    final isSettings = state.matchedLocation == '/settings';
    final isProfile = state.matchedLocation == '/profile';
    final isRequestBuilder = state.matchedLocation == '/request/new';
    final isProtectedRoute = isHome || isSettings || isProfile || isRequestBuilder;
    
    // Check authentication status
    final isAuthenticated = await checkAuthStatus();
    
    // If authenticated and on onboarding, redirect to home
    if (isAuthenticated && isOnboarding) {
      return '/home';
    }
    
    // If not authenticated and trying to access protected routes, redirect to onboarding
    if (!isAuthenticated && isProtectedRoute) {
      return '/onboarding';
    }
    
    // Allow the route
    return null;
  },
);
