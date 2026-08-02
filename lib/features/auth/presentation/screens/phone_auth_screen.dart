import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../application/auth_controller.dart';
import '../../domain/auth_state.dart';

/// Used for both new registrations and returning logins — Firebase Phone
/// Auth signs an existing user in or creates a new one transparently based
/// on whether the number has been seen before, so one screen covers both.
class PhoneAuthScreen extends ConsumerStatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  ConsumerState<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends ConsumerState<PhoneAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final e164 = '+91${_phoneController.text.trim()}';
    await ref
        .read(authControllerProvider.notifier)
        .startPhoneVerification(phoneNumber: e164);
    if (!mounted) return;
    if (ref.read(authControllerProvider).otpSent) {
      context.push('/auth/otp');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      final justSent = (previous?.verificationId == null) && next.otpSent;
      if (justSent) context.push('/auth/otp');
    });
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mobile Number')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'We\'ll send a one-time code to verify your number.',
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Mobile Number',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  validator: (value) {
                    final digits = value?.trim() ?? '';
                    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
                      return 'Enter a valid 10-digit mobile number';
                    }
                    return null;
                  },
                ),
                if (authState.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    authState.errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Send OTP',
                  isLoading: authState.status == AuthStatus.loading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
