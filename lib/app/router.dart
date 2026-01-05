import 'package:go_router/go_router.dart';
import 'package:decision_agent/features/onboarding/onboarding_page.dart';
import 'package:decision_agent/features/home/home_page.dart';
import 'package:decision_agent/features/settings/settings_page.dart';
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
      path: '/request/new',
      builder: (context, state) => const RequestBuilderPage(),
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
    final isRequestBuilder = state.matchedLocation == '/request/new';
    final isProtectedRoute = isHome || isSettings || isRequestBuilder;
    
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
