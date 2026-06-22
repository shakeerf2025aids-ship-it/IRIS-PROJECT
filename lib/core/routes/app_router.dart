import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/splash_screen.dart';
import '../../features/auth/welcome_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/scan/new_scan_screen.dart';
import '../../features/analysis/analysis_screen.dart';
import '../../features/results/results_screen.dart';
import '../../features/report/report_screen.dart';
import '../../features/history/history_screen.dart';
import '../../providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Watch the auth state to rebuild router when auth changes
  final authStateAsync = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      // Wait for auth state to load
      if (authStateAsync.isLoading) {
        return '/splash';
      }

      final isLoggedIn = authStateAsync.whenData((user) => user != null).value ?? false;
      final isAuthRoute = state.uri.path == '/login' ||
          state.uri.path == '/signup' ||
          state.uri.path == '/forgot-password' ||
          state.uri.path == '/welcome' ||
          state.uri.path == '/splash';

      // If logged in and trying to access auth routes, redirect to dashboard
      if (isLoggedIn && isAuthRoute) {
        return '/dashboard';
      }

      // If not logged in and trying to access protected routes, redirect to login
      if (!isLoggedIn &&
          !isAuthRoute &&
          state.uri.path != '/' &&
          state.uri.path != '/splash') {
        return '/login';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/scan',
        builder: (context, state) => const NewScanScreen(),
      ),
      GoRoute(
        path: '/analysis',
        builder: (context, state) {
          final imagePath = state.extra as String?;
          return AnalysisScreen(imagePath: imagePath ?? '');
        },
      ),
      GoRoute(
        path: '/results',
        builder: (context, state) {
          final extraData = state.extra as Map<String, dynamic>?;
          return ResultsScreen(
            imagePath: extraData?['imagePath'] as String? ?? '',
            result: extraData?['result'],
          );
        },
      ),
      GoRoute(
        path: '/report',
        builder: (context, state) {
          final extraData = state.extra as Map<String, dynamic>?;
          return ReportScreen(
            imagePath: extraData?['imagePath'] as String?,
            result: extraData?['result'],
          );
        },
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
      ),
    ],
  );
});
