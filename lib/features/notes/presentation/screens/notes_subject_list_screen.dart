import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/notes_subjects.dart';

/// First screen of the Notes flow — the fixed subject list itself needs no
/// network fetch (see notes_subjects.dart), unlike every other list in
/// this app; only what's inside a subject (NotesChapterListScreen) is
/// admin-managed data.
class NotesSubjectListScreen extends StatelessWidget {
  const NotesSubjectListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: notesSubjects.length,
          itemBuilder: (context, index) {
            final subject = notesSubjects[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.tileNotes,
                  child: const Icon(
                    Icons.description_outlined,
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  subject,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/notes/chapters', extra: subject),
              ),
            );
          },
        ),
      ),
    );
  }
}
