import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../../core/models/syllabus_topic.dart';
import '../../../../core/services/ad_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/load_error.dart';
import '../../data/syllabus_repository.dart';
import '../../domain/topic_status.dart';
import '../syllabus_navigation.dart';

/// Only screen in the Syllabus flow — reached from the "Syllabus" button on
/// the Mock Test/PYQ test-set list, for that exact same leaf (e.g.
/// "Science(Hin Eng)"). [resolveSyllabusTopicTags] decomposes the leaf's
/// own name into the Child Development & Pedagogy + subject + Language
/// I/II tags that make up its syllabus; the marks-distribution table shown
/// above it comes from [SyllabusTopicsArgs.marksExam] (e.g. "CTET Paper 2")
/// instead, since that's a real folder in the admin catalog and the leaf
/// itself isn't.
class SyllabusTopicsScreen extends StatefulWidget {
  const SyllabusTopicsScreen({super.key, required this.args});

  final SyllabusTopicsArgs args;

  @override
  State<SyllabusTopicsScreen> createState() => _SyllabusTopicsScreenState();
}

class _SyllabusTopicsScreenState extends State<SyllabusTopicsScreen> {
  final _repository = SyllabusRepository();

  bool _loading = true;
  String? _errorMessage;
  List<SyllabusTopic> _topics = const [];
  Map<String, TopicStatus> _progress = {};
  List<List<String>>? _marksTable;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final topics = await _repository.fetchTopicsForExams(
        resolveSyllabusTopicTags(widget.args.node.name),
      );
      final progress = await _repository.fetchProgress(user.id);
      final marksTable = await _repository.fetchMarksTable(
        widget.args.marksExam,
      );
      if (!mounted) return;
      setState(() {
        _topics = topics;
        _progress = progress;
        _marksTable = marksTable;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _cycleStatus(SyllabusTopic topic) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final current = _progress[topic.id] ?? TopicStatus.notStarted;
    final next = current.next;
    setState(() => _progress = {..._progress, topic.id: next});
    await _repository.setStatus(user.id, topic.id, next);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.args.node.name;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: LoadError(message: _errorMessage!, onRetry: _load),
      );
    }

    if (_topics.isEmpty && _marksTable == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
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
      bottomNavigationBar: const AppBannerAd(),
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (_marksTable != null) ...[
              Text(
                'Marks Distribution',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _MarksTable(rows: _marksTable!),
              const SizedBox(height: 24),
            ],
            if (_topics.isNotEmpty) ...[
              _ProgressHeader(done: doneCount, total: _topics.length),
              const SizedBox(height: 24),
              for (final entry in grouped.entries) ...[
                Text(
                  entry.key,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
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
          ],
        ),
      ),
    );
  }
}

class _MarksTable extends StatelessWidget {
  const _MarksTable({required this.rows});

  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white24 : Colors.black26;
    final headerFill = (isDark ? Colors.white : Colors.black).withValues(
      alpha: 0.06,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        border: TableBorder.all(color: borderColor),
        defaultColumnWidth: const IntrinsicColumnWidth(),
        children: [
          for (var r = 0; r < rows.length; r++)
            TableRow(
              decoration: r == 0 ? BoxDecoration(color: headerFill) : null,
              children: [
                for (final cell in rows[r])
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      cell,
                      style: TextStyle(
                        fontWeight: r == 0 ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
        ],
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
