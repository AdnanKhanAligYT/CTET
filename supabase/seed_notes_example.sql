-- Worked example of a single Notes chapter, whole content as one JSON —
-- run this AFTER supabase/migration_notes.sql to see the exact shape, or
-- edit and use it as a copy-paste template for real chapters. Safe to run
-- more than once (it re-deletes its own chapter by chapter_name first).

begin;

delete from public.notes_chapters
where subject = 'CDP' and chapter_name = 'Example Chapter — Delete Me';

insert into public.notes_chapters (subject, unit, chapter_number, chapter_name, sort_order, content)
values (
  'CDP', 'Unit 1', 1, 'Example Chapter — Delete Me', 1,
  '[
    {"type": "heading", "data": {"text": "Concept of Development"}},
    {"type": "paragraph", "data": {"text": "Development is a **lifelong process** of change in a person''s physical, cognitive, and social abilities."}},
    {"type": "subheading", "data": {"text": "Key Principles"}},
    {"type": "points", "data": {"items": [
        "Development is **continuous** — it never fully stops",
        "Development follows a fixed sequence (head to toe, near to far)",
        "Rate of development differs from person to person"
    ]}},
    {"type": "table", "data": {"rows": [
        ["Stage", "Age Range"],
        ["Infancy", "0-2 years"],
        ["Early Childhood", "2-6 years"],
        ["Middle Childhood", "6-11 years"]
    ]}},
    {"type": "image", "data": {"url": "https://picsum.photos/seed/ctet-example/800/450", "caption": "Example reference image — replace url with your own upload"}},
    {"type": "pdf_file", "data": {"url": "https://REPLACE-WITH-YOUR-notes-pdfs-STORAGE-URL/chapter1.pdf", "name": "Chapter 1 Full Notes (PDF)"}},
    {"type": "pdf_link", "data": {"url": "https://drive.google.com/file/d/REPLACE_WITH_YOUR_FILE_ID/view", "name": "Extra Practice Sheet"}},
    {"type": "example", "data": {
        "question": "Who among the following is associated with the theory of Cognitive Development?",
        "options": ["Sigmund Freud", "Jean Piaget", "B.F. Skinner", "Ivan Pavlov"],
        "correct_index": 1,
        "explanation": "**Jean Piaget** proposed the theory of Cognitive Development, describing four stages children pass through."
    }}
  ]'::jsonb
);

commit;
