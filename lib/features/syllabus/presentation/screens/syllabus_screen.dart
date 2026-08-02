import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/syllabus_topic.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../profile/application/profile_controller.dart';
import '../../data/syllabus_repository.dart';
import '../../domain/topic_status.dart';

class SyllabusScreen extends ConsumerStatefulWidget {
  const SyllabusScreen({super.key});

  @override
  ConsumerState<SyllabusScreen> createState() => _SyllabusScreenState();
}

class _SyllabusScreenState extends ConsumerState<SyllabusScreen> {
  final _repository = SyllabusRepository();

  bool _loading = true;
  String? _errorMessage;
  List<SyllabusTopic> _topics = const [];
  Map<String, TopicStatus> _progress = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await ref.read(userProfileProvider.future);
    final exams = profile?.exams ?? const [];
    if (exams.isEmpty) {
      setState(() {
        _loading = false;
        _errorMessage =
            'No exam selected yet — pick one in Edit Profile first.';
      });
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final topics = await _repository.fetchTopicsForExams(exams);
    final progress = await _repository.fetchProgress(user.uid);
    if (!mounted) return;
    setState(() {
      _topics = topics;
      _progress = progress;
      _loading = false;
    });
  }

  Future<void> _cycleStatus(SyllabusTopic topic) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final current = _progress[topic.id] ?? TopicStatus.notStarted;
    final next = current.next;
    setState(() => _progress = {..._progress, topic.id: next});
    await _repository.setStatus(user.uid, topic.id, next);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Syllabus')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Go to Profile',
                  onPressed: () => context.push('/profile/edit'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_topics.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Syllabus')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Syllabus for your exam hasn\'t been added yet.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final doneCount = _topics
        .where(
          (t) =>
              (_progress[t.id] ?? TopicStatus.notStarted) == TopicStatus.done,
        )
        .length;
    final grouped = <String, List<SyllabusTopic>>{};
    for (final topic in _topics) {
      grouped.putIfAbsent(topic.subject, () => []).add(topic);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Syllabus')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _ProgressHeader(done: doneCount, total: _topics.length),
            const SizedBox(height: 24),
            for (final entry in grouped.entries) ...[
              Text(entry.key, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final topic in entry.value)
                _TopicRow(
                  topic: topic,
                  status: _progress[topic.id] ?? TopicStatus.notStarted,
                  onTap: () => _cycleStatus(topic),
                ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : done / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Overall progress',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            Text(
              '$done / $total topics',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: Theme.of(context).dividerColor,
          ),
        ),
      ],
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({
    required this.topic,
    required this.status,
    required this.onTap,
  });

  final SyllabusTopic topic;
  final TopicStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    late final IconData icon;
    late final Color color;
    switch (status) {
      case TopicStatus.notStarted:
        icon = Icons.radio_button_unchecked;
        color =
            Theme.of(context).textTheme.bodySmall?.color ??
            AppColors.lightTextSecondary;
        break;
      case TopicStatus.inProgress:
        icon = Icons.incomplete_circle;
        color = AppColors.optionLanguage;
        break;
      case TopicStatus.done:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(topic.topicName),
                  if (topic.unit.isNotEmpty)
                    Text(
                      topic.unit,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
