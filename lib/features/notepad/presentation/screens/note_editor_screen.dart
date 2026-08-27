import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../../core/services/ad_service.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/notepad_repository.dart';
import '../../domain/note.dart';

/// Shared by "new note" (pass `note: null`) and "edit note" (pass the
/// existing note) — same fields either way.
class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, this.note});

  final Note? note;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final _repository = NotepadRepository();
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late bool _pinned;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _bodyController = TextEditingController(text: widget.note?.body ?? '');
    _pinned = widget.note?.pinned ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (uid == null || (title.isEmpty && body.isEmpty)) return;

    setState(() => _saving = true);
    if (widget.note == null) {
      await _repository.createNote(
        uid,
        Note(id: '', title: title, body: body, pinned: _pinned),
      );
    } else {
      await _repository.updateNote(
        uid,
        widget.note!.copyWith(title: title, body: body, pinned: _pinned),
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null || widget.note == null) return;
    await _repository.deleteNote(uid, widget.note!.id);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.note != null;
    return Scaffold(
      bottomNavigationBar: const AppBannerAd(),
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Note' : 'New Note'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            AppTextField(label: 'Title', controller: _titleController),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Note',
              controller: _bodyController,
              maxLines: 8,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Pin to top'),
              value: _pinned,
              onChanged: (value) => setState(() => _pinned = value),
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: 'Save', isLoading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
