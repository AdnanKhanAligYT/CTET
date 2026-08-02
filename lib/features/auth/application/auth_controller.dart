import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_state.dart';

/// Live stream of the current Firebase user — the single source of truth
/// the router uses to decide whether a visitor is logged in at all.
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Wraps every FirebaseAuth call the auth screens need. Kept deliberately
/// thin — it does not touch Firestore (see ProfileController for that) so
/// auth failures and profile-write failures stay easy to tell apart.
class AuthController extends Notifier<AuthState> {
  FirebaseAuth get _auth => FirebaseAuth.instance;

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
    await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    // Non-blocking by design (see plan §3): students aren't forced to
    // verify before entering the app, just nudged.
    await _auth.currentUser?.sendEmailVerification();
  });

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) => _run(() async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  });

  Future<bool> sendPasswordResetEmail(String email) => _run(() async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  });

  Future<void> resendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  /// Kicks off Firebase Phone Auth. On some Android devices Firebase can
  /// auto-verify the code without the user typing anything
  /// (`verificationCompleted`); the OTP screen only needs to handle the
  /// `codeSent` case since `verificationCompleted` signs the user in
  /// directly here.
  Future<void> startPhoneVerification({
    required String phoneNumber,
    int? forceResendingToken,
  }) async {
    state = state.copyWith(
      status: AuthStatus.loading,
      clearError: true,
      phoneNumber: phoneNumber,
    );
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: forceResendingToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          await _auth.signInWithCredential(credential);
          state = state.copyWith(status: AuthStatus.idle);
        } on FirebaseAuthException catch (e) {
          state = state.copyWith(
            status: AuthStatus.error,
            errorMessage: e.message ?? 'Verification failed.',
          );
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: e.message ?? 'Could not send OTP.',
        );
      },
      codeSent: (String verificationId, int? resendToken) {
        state = state.copyWith(
          status: AuthStatus.idle,
          verificationId: verificationId,
          resendToken: resendToken,
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        state = state.copyWith(verificationId: verificationId);
      },
    );
  }

  Future<bool> confirmOtp(String smsCode) => _run(() async {
    final verificationId = state.verificationId;
    if (verificationId == null) {
      throw StateError('No OTP request in progress.');
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    await _auth.signInWithCredential(credential);
  });

  /// Lets a phone-only account add an email+password sign-in method (the
  /// "Set Password" option in Edit Profile), so both login paths work on
  /// one account going forward.
  Future<bool> linkEmailPassword({
    required String email,
    required String password,
  }) => _run(() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Not signed in.');
    final credential = EmailAuthProvider.credential(
      email: email.trim(),
      password: password,
    );
    await user.linkWithCredential(credential);
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
    } on FirebaseAuthException catch (e) {
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

  String _friendlyMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'email-already-in-use':
        return 'An account already exists for this email — try logging in instead.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'invalid-verification-code':
        return 'That code looks wrong — please check and try again.';
      case 'session-expired':
        return 'This code has expired — please request a new one.';
      case 'credential-already-in-use':
        return 'This is already linked to another account.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}
