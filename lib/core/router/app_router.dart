import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../providers/auth_provider.dart';

import '../../main.dart' show navigatorKey;
import '../../screens/home_screen.dart' show HomePage;
import '../../pages/login_page.dart';
import '../../pages/register_page.dart';
import '../../pages/forgot_password_page.dart';
import '../../pages/reset_password_page.dart';
import '../../pages/otp_verification_page.dart';
import '../../pages/premium_page.dart';
import '../../screens/trip_history_screen.dart';

part 'app_router.g.dart';

@TypedGoRoute<HomeRoute>(path: '/')
class HomeRoute extends GoRouteData with $HomeRoute {
  const HomeRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const HomePage();
}

@TypedGoRoute<LoginRoute>(path: '/login')
class LoginRoute extends GoRouteData with $LoginRoute {
  const LoginRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const LoginPage();
}

@TypedGoRoute<RegisterRoute>(path: '/register')
class RegisterRoute extends GoRouteData with $RegisterRoute {
  const RegisterRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const RegisterPage();
}

@TypedGoRoute<ForgotPasswordRoute>(path: '/forgot-password')
class ForgotPasswordRoute extends GoRouteData with $ForgotPasswordRoute {
  const ForgotPasswordRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const ForgotPasswordPage();
}

@TypedGoRoute<ResetPasswordRoute>(path: '/reset-password')
class ResetPasswordRoute extends GoRouteData with $ResetPasswordRoute {
  final String email;
  const ResetPasswordRoute({required this.email});
  
  @override
  Widget build(BuildContext context, GoRouterState state) => ResetPasswordPage(email: email);
}

@TypedGoRoute<VerifyRoute>(path: '/verify')
class VerifyRoute extends GoRouteData with $VerifyRoute {
  final String email;
  final bool isLoginFlow;
  
  const VerifyRoute({required this.email, this.isLoginFlow = false});
  
  @override
  Widget build(BuildContext context, GoRouterState state) => OtpVerificationPage(
        email: email,
        isLoginFlow: isLoginFlow,
      );
}

@TypedGoRoute<TripHistoryRoute>(path: '/trip-history')
class TripHistoryRoute extends GoRouteData with $TripHistoryRoute {
  const TripHistoryRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const TripHistoryScreen();
}

@TypedGoRoute<PremiumRoute>(path: '/premium')
class PremiumRoute extends GoRouteData with $PremiumRoute {
  const PremiumRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const PremiumPage();
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/',
    observers: [
      SentryNavigatorObserver(),
    ],
    redirect: (context, state) {
      final path = state.uri.path;
      final isLoggingIn = path == '/login' ||
          path == '/register' ||
          path == '/forgot-password' ||
          path == '/reset-password' ||
          path == '/verify';

      if (!authState.isLoggedIn && !isLoggingIn) {
        return '/login';
      }

      if (authState.isLoggedIn && isLoggingIn) {
        return '/';
      }

      return null;
    },
    routes: $appRoutes,
  );
});
