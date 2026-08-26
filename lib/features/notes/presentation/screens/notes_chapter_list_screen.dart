import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/notes_chapter.dart';
import '../../../../core/widgets/load_error.dart';
import '../../data/notes_repository.dart';

/// Second screen of the Notes flow — chapters admin-added under one fixed
/// subject (e.g. "CDP"), grouped by [NotesChapter.unit] into an accordion
/// (only one unit's chapters visible at a time — opening another closes
/// whichever was open, see [_expandedUnit]). Tapping a chapter opens
/// NotesContentScreen for it.
class NotesChapterListScreen extends StatefulWidget {
  const NotesChapterListScreen({super.key, required this.subject});

  final String subject;

  @override
  State<NotesChapterListScreen> createState() =>
      _NotesChapterListScreenState();
}

const _ungroupedUnitLabel = 'General';

class _NotesChapterListScreenState extends State<NotesChapterListScreen> {
  final _repository = NotesRepository();
  bool _loading = true;
  String? _error;
  List<NotesChapter> _chapters = const [];
  String? _expandedUnit;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final chapters = await _repository.fetchChapters(widget.subject);
      if (!mounted) return;
      setState(() {
        _chapters = chapters;
        // First unit open by default so the screen isn't all-collapsed
        // the moment the subject's chapters load.
        _expandedUnit = chapters.isEmpty
            ? null
            : (chapters.first.unit?.isNotEmpty ?? false)
            ? chapters.first.unit
            : _ungroupedUnitLabel;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _toggleUnit(String unit) {
    setState(() => _expandedUnit = _expandedUnit == unit ? null : unit);
  }

  @override
  Widget build(BuildContext context) {
    late final Widget content;
    if (_loading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      content = LoadError(message: _error!, onRetry: _load);
    } else if (_chapters.isEmpty) {
      content = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Is subject ke notes abhi add nahi hue.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else {
      final grouped = <String, List<NotesChapter>>{};
      for (final chapter in _chapters) {
        final unit = (chapter.unit?.isNotEmpty ?? false)
            ? chapter.unit!
            : _ungroupedUnitLabel;
        grouped.putIfAbsent(unit, () => []).add(chapter);
      }

      content = ListView(
        padding: const EdgeInsets.all(24),
        children: [
          for (final entry in grouped.entries)
            _UnitSection(
              unit: entry.key,
              chapters: entry.value,
              expanded: _expandedUnit == entry.key,
              onToggle: () => _toggleUnit(entry.key),
              onChapterTap: (chapter) =>
                  context.push('/notes/content', extra: chapter),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.subject)),
      body: SafeArea(child: content),
    );
  }
}

class _UnitSection extends StatelessWidget {
  const _UnitSection({
    required this.unit,
    required this.chapters,
    required this.expanded,
    required this.onToggle,
    required this.onChapterTap,
  });

  final String unit;
  final List<NotesChapter> chapters;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<NotesChapter> onChapterTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            child: ListTile(
              title: Text(
                unit,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('${chapters.length} chapter(s)'),
              trailing: Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(height: 1),
                for (final chapter in chapters)
                  ListTile(
                    title: Text(chapter.chapterName),
                    subtitle: chapter.chapterNumber != null
                        ? Text('Chapter ${chapter.chapterNumber}')
                        : null,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onChapterTap(chapter),
                  ),
              ],
            ),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
