/// Fixed subject list for the Notes flow (unlike Syllabus/Mock Test/PYQ,
/// not admin-managed — this list never changes, only what's inside each
/// subject does, see supabase/migration_notes.sql). Order here is display
/// order in NotesSubjectListScreen.
///
/// Language subjects (English/Hindi/Urdu/Sanskrit) are NOT split into
/// "1st"/"2nd" — the same chapter content applies whichever language a
/// student picked as Language I or Language II. Where a topic genuinely
/// only applies to Language I (e.g. Poetry — Language II's comprehension
/// syllabus is prose-only, see CTET's Information Bulletin Appendix I),
/// that gets called out inline in the chapter's own content (a paragraph
/// or heading noting "Language I only"), not by a separate subject.
const notesSubjects = [
  'CDP',
  'Mathematics Paper-1',
  'Mathematics Paper-2',
  'Science',
  'EVS',
  'English',
  'Hindi',
  'Urdu',
  'Sanskrit',
];
