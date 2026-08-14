import 'dart:async';

import 'package:flutter/material.dart';

/// Thin single-line strip pinned under the dashboard AppBar (via
/// `AppBar.bottom`) — reads the same admin-set date/time
/// AppSettingsRepository.fetchExamCountdownDate() already feeds the daily
/// 7:30 AM reminder notification, just ticking live down to the second
/// instead of a once-a-day "X din baaki" string.
///
/// DashboardScreen only ever constructs this once it has a non-null,
/// still-future exam date — this widget itself hides (renders nothing)
/// the moment the countdown hits zero, so a stale past date never lingers
/// on screen until the next app restart re-fetches it.
class ExamCountdownBar extends StatefulWidget implements PreferredSizeWidget {
  const ExamCountdownBar({super.key, required this.examDate});

  final DateTime examDate;

  @override
  Size get preferredSize => const Size.fromHeight(26);

  @override
  State<ExamCountdownBar> createState() => _ExamCountdownBarState();
}

class _ExamCountdownBarState extends State<ExamCountdownBar> {
  Timer? _ticker;
  Duration _remaining = Duration.zero;

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    final remaining = widget.examDate.difference(DateTime.now());
    if (!mounted) return;
    setState(() => _remaining = remaining.isNegative ? Duration.zero : remaining);
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    if (_remaining == Duration.zero) return const SizedBox.shrink();

    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;
    final dateLabel =
        '${widget.examDate.day} ${_monthNames[widget.examDate.month - 1]} '
        '${widget.examDate.year}';
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 26,
      width: double.infinity,
      color: colorScheme.primary.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(
        '📅 Exam: $dateLabel  ·  ${days}d ${_two(hours)}:${_two(minutes)}:${_two(seconds)} left',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
        ),
      ),
    );
  }
}
