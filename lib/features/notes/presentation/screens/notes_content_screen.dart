import 'package:flutter/material.dart';

import '../../../../core/models/notes_block.dart';
import '../../../../core/models/notes_chapter.dart';
import '../../../../core/widgets/load_error.dart';
import '../../data/notes_repository.dart';
import '../widgets/notes_block_view.dart';

/// Third and last screen of the Notes flow — the chapter's actual content,
/// rendered block by block via NotesBlockView in sort_order.
class NotesContentScreen extends StatefulWidget {
  const NotesContentScreen({super.key, required this.chapter});

  final NotesChapter chapter;

  @override
  State<NotesContentScreen> createState() => _NotesContentScreenState();
}

class _NotesContentScreenState extends State<NotesContentScreen> {
  final _repository = NotesRepository();
  bool _loading = true;
  String? _error;
  List<NotesBlock> _blocks = const [];

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
      final blocks = await _repository.fetchBlocks(widget.chapter.id);
      if (!mounted) return;
      setState(() {
        _blocks = blocks;
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
    } else if (_blocks.isEmpty) {
      content = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Is chapter ka content abhi add nahi hua.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else {
      content = ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _blocks.length,
        itemBuilder: (context, index) => NotesBlockView(block: _blocks[index]),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.chapter.chapterName)),
      body: SafeArea(child: content),
    );
  }
}
