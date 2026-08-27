import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../../core/services/ad_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../mock_test/presentation/screens/take_test_screen.dart';
import '../../data/bullet_revision_repository.dart';

/// Behind the dashboard's "Bullet Revision" tile, and also reachable via
/// an admin push notification's "Bullet Revision" tap action (see
/// [autostartMinutes]): pick a duration (1 minute = 1 CDP question, so
/// "10 min" = 10 questions) and the test opens immediately in
/// TakeTestScreen's format — no intermediate picker, since the content
/// is CDP-only either way (see BulletRevisionRepository), there's nothing
/// left to choose once a duration is picked.
class BulletRevisionScreen extends StatefulWidget {
  const BulletRevisionScreen({super.key, this.autostartMinutes});

  /// Set when opened from a notification's deep link — starts that
  /// duration's test immediately on open, same as tapping its button
  /// would, so the notification lands the student straight in the test.
  final int? autostartMinutes;

  @override
  State<BulletRevisionScreen> createState() => _BulletRevisionScreenState();
}

class _BulletRevisionScreenState extends State<BulletRevisionScreen> {
  static const _durations = [1, 5, 10, 20, 30, 60];

  final _repository = BulletRevisionRepository();
  Map<int, int> _openCounts = const {};
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _loadCounts();
    final autostart = widget.autostartMinutes;
    if (autostart != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _startTest(autostart),
      );
    }
  }

  Future<void> _loadCounts() async {
    final counts = await _repository.fetchDurationOpenCounts();
    if (!mounted) return;
    setState(() => _openCounts = counts);
  }

  Future<void> _startTest(int minutes) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    _repository.recordDurationOpened(minutes);
    setState(() => _starting = true);
    try {
      final ids = await _repository.pickNextQuestionIds(uid, minutes);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              TakeTestScreen(questionIds: ids, title: 'Bullet Revision'),
        ),
      );
      if (!mounted) return;
      _loadCounts();
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const AppBannerAd(),
      appBar: AppBar(title: const Text('Bullet Revision')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CDP ke sawaal, apni speed chuno',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Har button = utne hi minute mein utne hi CDP questions.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 1.05,
                      ),
                  itemCount: _durations.length,
                  itemBuilder: (context, index) {
                    final minutes = _durations[index];
                    return _DurationButton(
                      minutes: minutes,
                      color: AppColors.bulletRevisionDurations[index],
                      openCount: _openCounts[minutes] ?? 0,
                      enabled: !_starting,
                      onTap: () => _startTest(minutes),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DurationButton extends StatelessWidget {
  const _DurationButton({
    required this.minutes,
    required this.color,
    required this.openCount,
    required this.enabled,
    required this.onTap,
  });

  final int minutes;
  final Color color;
  final int openCount;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bolt, color: Colors.white, size: 28),
              const SizedBox(height: 4),
              Text(
                '$minutes',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              Text(
                minutes == 1 ? 'minute' : 'minutes',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Opened ${openCount}x',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
