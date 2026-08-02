enum AuthStatus { idle, loading, error }

/// UI-facing state for every screen in the auth flow. One shared state
/// keeps the Welcome → Signup/Login → OTP → Name screens simple to wire up
/// without each needing its own notifier.
class AuthState {
  const AuthState({
    this.status = AuthStatus.idle,
    this.errorMessage,
    this.verificationId,
    this.resendToken,
    this.phoneNumber,
  });

  final AuthStatus status;
  final String? errorMessage;

  /// Set once Firebase has sent an OTP; required to confirm the code.
  final String? verificationId;

  /// Android auto-retrieval resend token, passed back into
  /// `verifyPhoneNumber` on "Resend OTP".
  final int? resendToken;

  /// Kept so the OTP screen can display "Code sent to +91XXXXXXXXXX".
  final String? phoneNumber;

  bool get isLoading => status == AuthStatus.loading;
  bool get otpSent => verificationId != null;

  AuthState copyWith({
    AuthStatus? status,
    String? errorMessage,
    bool clearError = false,
    String? verificationId,
    int? resendToken,
    String? phoneNumber,
  }) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      verificationId: verificationId ?? this.verificationId,
      resendToken: resendToken ?? this.resendToken,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }
}
