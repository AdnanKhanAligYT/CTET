import 'package:flutter/material.dart';

import '../../../../core/models/notes_chapter.dart';
import '../widgets/notes_block_view.dart';

/// Third and last screen of the Notes flow — the chapter's content,
/// rendered block by block. No fetch of its own: [chapter] already
/// carries its full content array from NotesChapterListScreen's fetch.
class NotesContentScreen extends StatelessWidget {
  const NotesContentScreen({super.key, required this.chapter});

  final NotesChapter chapter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(chapter.chapterName)),
      body: SafeArea(
        child: chapter.content.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Is chapter ka content abhi add nahi hua.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: chapter.content.length,
                itemBuilder: (context, index) =>
                    NotesBlockView(block: chapter.content[index]),
              ),
      ),
    );
  }
}
