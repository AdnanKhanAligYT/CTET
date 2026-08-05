enum AuthStatus { idle, loading, error }

/// UI-facing state for every screen in the auth flow. One shared state
/// keeps the Welcome → Signup/Login → OTP → Name screens simple to wire up
/// without each needing its own notifier.
class AuthState {
  const AuthState({
    this.status = AuthStatus.idle,
    this.errorMessage,
    this.otpRequested = false,
    this.phoneNumber,
  });

  final AuthStatus status;
  final String? errorMessage;

  /// Set once Supabase has sent an OTP to `phoneNumber`; required before
  /// `confirmOtp` can be called.
  final bool otpRequested;

  /// Kept so the OTP screen can display "Code sent to +91XXXXXXXXXX", and
  /// so "Resend OTP" knows which number to resend to.
  final String? phoneNumber;

  bool get isLoading => status == AuthStatus.loading;
  bool get otpSent => otpRequested;

  AuthState copyWith({
    AuthStatus? status,
    String? errorMessage,
    bool clearError = false,
    bool? otpRequested,
    String? phoneNumber,
  }) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      otpRequested: otpRequested ?? this.otpRequested,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }
}
