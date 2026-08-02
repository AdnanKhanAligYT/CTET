import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../application/auth_controller.dart';
import '../../domain/auth_state.dart';

/// Handles both email sign-up and email login — the two only differ in
/// which FirebaseAuth call gets made and whether a "confirm password"
/// field is shown, so one screen with an `isSignUp` flag avoids
/// duplicating the whole form.
class EmailAuthScreen extends ConsumerStatefulWidget {
  const EmailAuthScreen({super.key, required this.isSignUp});

  final bool isSignUp;

  @override
  ConsumerState<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends ConsumerState<EmailAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = ref.read(authControllerProvider.notifier);
    final email = _emailController.text.trim();

    final success = widget.isSignUp
        ? await controller.signUpWithEmail(
            email: email,
            password: _passwordController.text,
          )
        : await controller.signInWithEmail(
            email: email,
            password: _passwordController.text,
          );

    if (!success || !mounted) return;

    if (widget.isSignUp) {
      context.go('/auth/suggested-name?email=${Uri.encodeComponent(email)}');
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isSignUp ? 'Create Account' : 'Log In'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: 'Email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: (value) {
                    if (value == null || !value.contains('@')) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Password',
                  controller: _passwordController,
                  obscureText: true,
                  autofillHints: [
                    if (widget.isSignUp)
                      AutofillHints.newPassword
                    else
                      AutofillHints.password,
                  ],
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                if (widget.isSignUp) ...[
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Confirm Password',
                    controller: _confirmController,
                    obscureText: true,
                    validator: (value) {
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                ],
                if (!widget.isSignUp)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push('/auth/forgot-password'),
                      child: const Text('Forgot password?'),
                    ),
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
                  label: widget.isSignUp ? 'Sign Up' : 'Log In',
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
