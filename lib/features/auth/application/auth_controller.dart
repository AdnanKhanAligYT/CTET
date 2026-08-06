import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../domain/auth_state.dart';

// Google Cloud Console -> APIs & Services -> Credentials -> "Web client"
// OAuth Client ID (NOT the Android client — google_sign_in needs the web
// one as `serverClientId` so the id token it returns is one Supabase's
// Google provider will accept). See README "Google Sign-In setup".
const _googleServerClientId = 'REPLACE_ME.apps.googleusercontent.com';

final _client = Supabase.instance.client;

/// Live stream of the current Supabase user — the single source of truth
/// the router uses to decide whether a visitor is logged in at all.
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return _client.auth.onAuthStateChange.map((data) => data.session?.user);
});

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Wraps every Supabase Auth call the auth screens need. Kept deliberately
/// thin — it does not touch the `profiles` table (see ProfileController
/// for that) so auth failures and profile-write failures stay easy to
/// tell apart.
class AuthController extends Notifier<AuthState> {
  GoTrueClient get _auth => _client.auth;

  @override
  AuthState build() => const AuthState();

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }

  Future<bool> signUpWithEmail({
    required String email,
    required String password,
  }) => _run(() async {
    await _auth.signUp(email: email.trim(), password: password);
    // Non-blocking by design: the student is already signed in (Confirm
    // email is off in Supabase so signup never waits on this) — this just
    // gets a verification link into their inbox so the "Unverified" badge
    // in Edit Profile can eventually clear.
    await _auth.resend(type: OtpType.signup, email: email.trim());
  });

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) => _run(() async {
    await _auth.signInWithPassword(email: email.trim(), password: password);
  });

  Future<bool> sendPasswordResetEmail(String email) => _run(() async {
    await _auth.resetPasswordForEmail(email.trim());
  });

  Future<bool> resendEmailVerification() => _run(() async {
    final email = _auth.currentUser?.email;
    if (email == null) throw StateError('No email on this account.');
    await _auth.resend(type: OtpType.signup, email: email);
  });

  /// Native "choose a Google account on this device" sign-in — shows the
  /// system account picker (via google_sign_in), then hands the resulting
  /// ID token to Supabase rather than opening a browser-based OAuth flow.
  Future<bool> signInWithGoogle() async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final googleUser = await GoogleSignIn(
        serverClientId: _googleServerClientId,
      ).signIn();
      if (googleUser == null) {
        // Student dismissed the account picker — not an error.
        state = state.copyWith(status: AuthStatus.idle);
        return false;
      }
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        throw StateError('Could not get a Google ID token.');
      }
      await _auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );
      state = state.copyWith(status: AuthStatus.idle);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _friendlyMessage(e),
      );
      return false;
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: '$e');
      return false;
    }
  }

  /// Sends a 6-digit SMS code via Supabase Phone Auth. Works for both a
  /// brand-new number and a returning student's number — Supabase creates
  /// the account transparently on first verify, same as the old Firebase
  /// Phone Auth behaviour.
  Future<void> startPhoneVerification({required String phoneNumber}) async {
    state = state.copyWith(
      status: AuthStatus.loading,
      clearError: true,
      phoneNumber: phoneNumber,
      otpRequested: false,
    );
    try {
      await _auth.signInWithOtp(phone: phoneNumber);
      state = state.copyWith(status: AuthStatus.idle, otpRequested: true);
    } on AuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message,
      );
    }
  }

  Future<bool> confirmOtp(String smsCode) => _run(() async {
    final phone = state.phoneNumber;
    if (phone == null) {
      throw StateError('No OTP request in progress.');
    }
    await _auth.verifyOTP(phone: phone, token: smsCode, type: OtpType.sms);
  });

  /// Lets a phone-only account add an email+password sign-in method (the
  /// "Set Password" option in Edit Profile), so both login paths work on
  /// one account going forward.
  Future<bool> linkEmailPassword({
    required String email,
    required String password,
  }) => _run(() async {
    await _auth.updateUser(
      UserAttributes(email: email.trim(), password: password),
    );
  });

  Future<void> signOut() async {
    await _auth.signOut();
    state = const AuthState();
  }

  Future<bool> _run(Future<void> Function() action) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      await action();
      state = state.copyWith(status: AuthStatus.idle);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _friendlyMessage(e),
      );
      return false;
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: '$e');
      return false;
    }
  }

  String _friendlyMessage(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('already registered') || msg.contains('already exists')) {
      return 'An account already exists for this email — try logging in instead.';
    }
    if (msg.contains('invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (msg.contains('password') && msg.contains('least')) {
      return 'Password should be at least 6 characters.';
    }
    if (msg.contains('expired')) {
      return 'This code has expired — please request a new one.';
    }
    if (msg.contains('otp') || msg.contains('token')) {
      return 'That code looks wrong — please check and try again.';
    }
    return e.message;
  }
}
