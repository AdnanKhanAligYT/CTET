import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
              Center(
                child: TextButton(
                  onPressed: () => context.push('/auth/phone'),
                  child: const Text('Continue with mobile number'),
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

/// Google's four-colour "G" mark, hand-drawn with arcs — there's no asset
/// file involved (this sandbox can't fetch Google's official brand SVG),
/// but the shape and brand colours match closely enough to read correctly
/// on the button at a glance.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  static const _size = 20.0;

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: _size,
      height: _size,
      child: CustomPaint(painter: _GoogleMarkPainter()),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = size.width * 0.34;
    final radius = size.width / 2 - strokeWidth / 2;
    final ringRect = Rect.fromCircle(center: center, radius: radius);

    Paint ringPaint(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    double deg(double d) => d * math.pi / 180;
    const gap = 6.0;

    // Four ~90° quadrants (clockwise from the right), matching the real
    // logo's layout: blue right, green bottom, yellow left, red top — with
    // a small gap on each side of red so the ring reads as a "G", not an "O".
    canvas.drawArc(ringRect, deg(-45), deg(135), false, ringPaint(_blue));
    canvas.drawArc(ringRect, deg(90), deg(90), false, ringPaint(_green));
    canvas.drawArc(ringRect, deg(180), deg(90 - gap), false, ringPaint(_yellow));
    canvas.drawArc(
      ringRect,
      deg(270 + gap),
      deg(90 - gap * 2),
      false,
      ringPaint(_red),
    );

    // The G's crossbar: a blue block from the ring's centre out to its
    // right edge, at vertical-middle — this is what turns the ring into a
    // "G" instead of a plain circle.
    final barPaint = Paint()..color = _blue;
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx - strokeWidth * 0.1,
        center.dy - strokeWidth / 2,
        size.width / 2 - center.dx + strokeWidth * 0.6,
        strokeWidth,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GoogleMarkPainter oldDelegate) => false;
}
