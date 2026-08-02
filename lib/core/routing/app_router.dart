import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/email_auth_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/manual_name_screen.dart';
import '../../features/auth/presentation/screens/otp_verify_screen.dart';
import '../../features/auth/presentation/screens/phone_auth_screen.dart';
import '../../features/auth/presentation/screens/suggested_name_screen.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/dashboard/presentation/screens/home_gate.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import 'go_router_refresh_stream.dart';

// Only '/welcome' is bounced away from once logged in — this exists purely
// to skip straight past the welcome screen on a cold start when a session
// is already active. The signup/login/OTP screens deliberately are NOT in
// this list: each of them decides its own next screen on success (e.g.
// email signup -> Suggested Name, phone signup -> Manual Name, login ->
// home), and bouncing them here would race that explicit navigation and
// skip the name-entry step for brand-new users.
const _bounceWhenLoggedIn = ['/welcome'];

// Routes that require a signed-in user; anyone signed out gets sent back
// to Welcome instead.
const _requiresAuth = ['/', '/profile/edit'];

final appRouter = GoRouter(
  initialLocation: '/welcome',
  refreshListenable: GoRouterRefreshStream(
    FirebaseAuth.instance.authStateChanges(),
  ),
  redirect: (context, state) {
    final loggedIn = FirebaseAuth.instance.currentUser != null;
    final loc = state.matchedLocation;

    if (loggedIn && _bounceWhenLoggedIn.contains(loc)) return '/';
    if (!loggedIn && _requiresAuth.contains(loc)) return '/welcome';
    return null;
  },
  routes: [
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/auth/email',
      builder: (context, state) => EmailAuthScreen(
        isSignUp: state.uri.queryParameters['mode'] != 'login',
      ),
    ),
    GoRoute(
      path: '/auth/phone',
      builder: (context, state) => const PhoneAuthScreen(),
    ),
    GoRoute(
      path: '/auth/otp',
      builder: (context, state) => const OtpVerifyScreen(),
    ),
    GoRoute(
      path: '/auth/suggested-name',
      builder: (context, state) =>
          SuggestedNameScreen(email: state.uri.queryParameters['email'] ?? ''),
    ),
    GoRoute(
      path: '/auth/manual-name',
      builder: (context, state) => const ManualNameScreen(),
    ),
    GoRoute(
      path: '/auth/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(path: '/', builder: (context, state) => const HomeGate()),
    GoRoute(
      path: '/profile/edit',
      builder: (context, state) => EditProfileScreen(
        isFirstTimeSetup: state.uri.queryParameters['firstTime'] == 'true',
      ),
    ),
  ],
);
