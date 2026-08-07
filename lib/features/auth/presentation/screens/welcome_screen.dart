import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/auth_controller.dart';
import '../../domain/auth_state.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  Future<void> _continueWithGoogle() async {
    final success = await ref
        .read(authControllerProvider.notifier)
        .signInWithGoogle();
    if (!success || !mounted) return;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 3),
              Center(
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.navyLight : AppColors.navy,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    size: 68,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(flex: 2),
              Text(
                'Crack Your CTET & State TET Exam',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                'Mock tests, syllabus tracking, and daily revision — built for CTET and State TET aspirants.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(flex: 3),
              _GoogleButton(
                isLoading: authState.isLoading,
                onPressed: _continueWithGoogle,
              ),
              if (authState.status == AuthStatus.error &&
                  authState.errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  authState.errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 18),
              Center(
                child: TextButton(
                  onPressed: () => context.push('/auth/email?mode=signup'),
                  child: const Text(
                    'Continue with email',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.push('/auth/email?mode=login'),
                child: const Text('Already have an account? Log in'),
              ),
              const SizedBox(height: 12),
              Text(
                'By continuing, you agree to our Terms & Privacy Policy.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _GoogleMark(),
                  const SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Google's official four-colour "G" mark, loaded from a bundled SVG
/// asset (`assets/icons/google_logo.svg`) rather than hand-drawn, so it
/// matches the real brand mark exactly.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  static const _size = 20.0;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/google_logo.svg',
      width: _size,
      height: _size,
    );
  }
}
