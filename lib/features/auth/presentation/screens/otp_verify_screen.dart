import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../../core/widgets/primary_button.dart';
import '../../application/auth_controller.dart';
import '../../domain/auth_state.dart';

const _resendCooldownSeconds = 30;

class OtpVerifyScreen extends ConsumerStatefulWidget {
  const OtpVerifyScreen({super.key});

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  final _pinController = TextEditingController();
  Timer? _cooldownTimer;
  int _secondsLeft = _resendCooldownSeconds;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    _secondsLeft = _resendCooldownSeconds;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _resend() async {
    final authState = ref.read(authControllerProvider);
    if (authState.phoneNumber == null) return;
    await ref
        .read(authControllerProvider.notifier)
        .startPhoneVerification(phoneNumber: authState.phoneNumber!);
    _startCooldown();
  }

  Future<void> _confirm() async {
    final success = await ref
        .read(authControllerProvider.notifier)
        .confirmOtp(_pinController.text);
    if (!success || !mounted) return;
    _navigateAfterSignIn();
  }

  /// Phone Auth never sets a display name on its own, so a brand new phone
  /// account has none stored in `user_metadata`; a returning student who
  /// already completed setup will have one from last time.
  void _navigateAfterSignIn() {
    final displayName =
        Supabase.instance.client.auth.currentUser?.userMetadata?['display_name']
            as String?;
    if (displayName == null || displayName.isEmpty) {
      context.go('/auth/manual-name');
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter the 6-digit code sent to ${authState.phoneNumber ?? 'your phone'}',
              ),
              const SizedBox(height: 24),
              Pinput(
                length: 6,
                controller: _pinController,
                onCompleted: (_) => _confirm(),
              ),
              if (authState.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  authState.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Verify',
                isLoading: authState.status == AuthStatus.loading,
                onPressed: _confirm,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _secondsLeft <= 0 ? _resend : null,
                child: Text(
                  _secondsLeft <= 0
                      ? 'Resend OTP'
                      : 'Resend OTP in $_secondsLeft s',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
