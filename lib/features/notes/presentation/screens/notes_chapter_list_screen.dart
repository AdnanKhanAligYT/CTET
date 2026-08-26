import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/notes_chapter.dart';
import '../../../../core/widgets/load_error.dart';
import '../../data/notes_repository.dart';

/// Second screen of the Notes flow — chapters admin-added under one fixed
/// subject (e.g. "CDP"). Tapping one opens NotesContentScreen for it.
class NotesChapterListScreen extends StatefulWidget {
  const NotesChapterListScreen({super.key, required this.subject});

  final String subject;

  @override
  State<NotesChapterListScreen> createState() =>
      _NotesChapterListScreenState();
}

class _NotesChapterListScreenState extends State<NotesChapterListScreen> {
  final _repository = NotesRepository();
  bool _loading = true;
  String? _error;
  List<NotesChapter> _chapters = const [];

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
      content = ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _chapters.length,
        itemBuilder: (context, index) {
          final chapter = _chapters[index];
          final label = [
            if (chapter.unit != null && chapter.unit!.isNotEmpty)
              chapter.unit!,
            if (chapter.chapterNumber != null)
              'Chapter ${chapter.chapterNumber}',
          ].join(' · ');
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(
                chapter.chapterName,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              subtitle: label.isEmpty ? null : Text(label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/notes/content', extra: chapter),
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.subject)),
      body: SafeArea(child: content),
    );
  }
}
