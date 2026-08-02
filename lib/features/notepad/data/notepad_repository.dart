import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/note.dart';

class NotepadRepository {
  NotepadRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      _firestore.collection('users').doc(uid).collection('notes');

  Future<List<Note>> fetchNotes(String uid) async {
    final snapshot = await _collection(uid).get();
    final notes = snapshot.docs
        .map((doc) => Note.fromMap(doc.id, doc.data()))
        .toList();
    notes.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      final aTime = a.updatedAt ?? DateTime(0);
      final bTime = b.updatedAt ?? DateTime(0);
      return bTime.compareTo(aTime);
    });
    return notes;
  }

  Future<String> createNote(String uid, Note note) async {
    final doc = await _collection(uid).add(note.toMap(isCreate: true));
    return doc.id;
  }

  Future<void> updateNote(String uid, Note note) {
    return _collection(uid).doc(note.id).set(note.toMap());
  }

  Future<void> deleteNote(String uid, String noteId) {
    return _collection(uid).doc(noteId).delete();
  }
}
