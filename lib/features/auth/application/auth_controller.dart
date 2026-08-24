import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../domain/auth_state.dart';

// Firebase Console -> Authentication -> Sign-in method -> Google -> Web
// SDK configuration -> "Web client ID". This is the Web OAuth client
// Firebase itself created and links to this project's Android OAuth
// clients (the earlier constant here pointed at a manually-created Web
// client that was never actually wired to this project the same way,
// which is what caused sign_in_failed/DEVELOPER_ERROR on every build).
const _googleServerClientId =
    '992082039986-4krr8mj7igfo9g25v6hsq7ibs2lcl4dn.apps.googleusercontent.com';

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

  // Firebase Phone Auth session plumbing — not surfaced in AuthState since
  // no screen needs to read it directly, just pass it back into
  // confirmOtp/resend.
  String? _firebaseVerificationId;
  int? _firebaseResendToken;

  // google_sign_in v7 requires initialize() to run once before any other
  // call on the singleton — done lazily on first sign-in attempt rather
  // than at app startup so a student who never taps "Continue with
  // Google" never pays for it.
  final _googleSignIn = GoogleSignIn.instance;
  bool _googleSignInInitialized = false;

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return;
    await _googleSignIn.initialize(serverClientId: _googleServerClientId);
    _googleSignInInitialized = true;
  }

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
      await _ensureGoogleSignInInitialized();
      final GoogleSignInAccount googleUser;
      try {
        googleUser = await _googleSignIn.authenticate();
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled) {
          // Student dismissed the account picker — not an error.
          state = state.copyWith(status: AuthStatus.idle);
          return false;
        }
        rethrow;
      }
      // v7: the ID token comes back with the account itself — no separate
      // async `.authentication` call needed like in v6.
      final idToken = googleUser.authentication.idToken;
      if (idToken == null) {
        throw StateError('Could not get a Google ID token.');
      }
      await _auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      // Don't rely on Supabase's own decoding of the ID token for the
      // photo — whether user_metadata ends up with an avatar_url/picture
      // claim from that varies (this is exactly why the name showed up
      // but the photo didn't). GoogleSignInAccount.photoUrl comes
      // straight from the native account picker every time, so write it
      // (and the display name, same reasoning) into user_metadata
      // ourselves on every sign-in — EditProfileScreen's first-time-setup
      // prefill and HomeGate's photo backfill both already read
      // avatar_url/full_name from there unchanged.
      final photoUrl = googleUser.photoUrl;
      final displayName = googleUser.displayName;
      if (photoUrl != null || displayName != null) {
        await _auth.updateUser(
          UserAttributes(
            data: {
              if (photoUrl != null) 'avatar_url': photoUrl,
              if (displayName != null) 'full_name': displayName,
            },
          ),
        );
      }
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

  /// Sends a 6-digit SMS code via **Firebase** Phone Auth, not Supabase —
  /// Supabase's own phone provider needs a paid SMS provider (Twilio etc.)
  /// plus Indian DLT registration; Firebase's is free and Google handles
  /// DLT itself. Firebase only verifies the number here; `confirmOtp`
  /// below hands that verified number to the `firebase-phone-bridge` Edge
  /// Function to actually create/sign in the real Supabase account — see
  /// README "Set up Mobile OTP" for the full picture.
  Future<void> startPhoneVerification({required String phoneNumber}) async {
    state = state.copyWith(
      status: AuthStatus.loading,
      clearError: true,
      phoneNumber: phoneNumber,
      otpRequested: false,
    );
    try {
      await fb.FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        forceResendingToken: _firebaseResendToken,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          // Some Android devices auto-fill the code before the student
          // types anything — finish sign-in right away when that happens.
          try {
            await _completeFirebasePhoneSignIn(credential);
          } catch (e) {
            state = state.copyWith(status: AuthStatus.error, errorMessage: '$e');
          }
        },
        verificationFailed: (e) {
          state = state.copyWith(
            status: AuthStatus.error,
            errorMessage: e.message ?? 'Could not send OTP.',
          );
        },
        codeSent: (verificationId, resendToken) {
          _firebaseVerificationId = verificationId;
          _firebaseResendToken = resendToken;
          state = state.copyWith(status: AuthStatus.idle, otpRequested: true);
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _firebaseVerificationId = verificationId;
        },
      );
    } on fb.FirebaseAuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message ?? 'Could not send OTP.',
      );
    }
  }

  Future<bool> confirmOtp(String smsCode) => _run(() async {
    final verificationId = _firebaseVerificationId;
    if (verificationId == null) {
      throw StateError('No OTP request in progress.');
    }
    final credential = fb.PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    await _completeFirebasePhoneSignIn(credential);
  });

  /// Firebase confirms the code and hands back a verified Firebase user;
  /// its ID token is the proof-of-verification the bridge function checks
  /// before creating/signing in the matching Supabase account. The
  /// Firebase session itself is never needed again after this, so it's
  /// discarded immediately — Supabase's session is the one the rest of
  /// the app runs on.
  Future<void> _completeFirebasePhoneSignIn(
    fb.PhoneAuthCredential credential,
  ) async {
    final firebaseResult = await fb.FirebaseAuth.instance.signInWithCredential(
      credential,
    );
    final idToken = await firebaseResult.user?.getIdToken();
    if (idToken == null) {
      throw StateError('Could not verify the code with Firebase.');
    }
    final response = await _client.functions.invoke(
      'firebase-phone-bridge',
      body: {'idToken': idToken},
    );
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) {
      throw StateError(data['error'] as String);
    }
    await _auth.signInWithPassword(
      phone: data['phone'] as String,
      password: data['password'] as String,
    );
    unawaited(fb.FirebaseAuth.instance.signOut());
  }

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
