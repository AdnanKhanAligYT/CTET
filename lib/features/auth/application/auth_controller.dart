import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../domain/auth_state.dart';

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
