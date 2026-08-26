-- Worked example of a single Notes chapter using every block type — run
-- this AFTER supabase/migration_notes.sql to see how content is meant to
-- be structured, or delete/edit it and use it as a copy-paste template
-- for real chapters. Safe to run more than once (it re-deletes its own
-- chapter by chapter_name before re-inserting).

begin;

delete from public.notes_chapters
where subject = 'CDP' and chapter_name = 'Example Chapter — Delete Me';

with new_chapter as (
  insert into public.notes_chapters (subject, unit, chapter_number, chapter_name, sort_order)
  values ('CDP', 'Unit 1', 1, 'Example Chapter — Delete Me', 1)
  returning id
)
insert into public.notes_blocks (chapter_id, block_type, content, sort_order)
select id, block_type, content::jsonb, sort_order
from new_chapter, (values
  ('heading',    '{"text": "Concept of Development"}', 1),
  ('paragraph',  '{"text": "Development is a **lifelong process** of change in a person''s physical, cognitive, and social abilities."}', 2),
  ('subheading', '{"text": "Key Principles"}', 3),
  ('points', '{"items": [
      "Development is **continuous** — it never fully stops",
      "Development follows a fixed sequence (head to toe, near to far)",
      "Rate of development differs from person to person"
  ]}', 4),
  ('table', '{"rows": [
      ["Stage", "Age Range"],
      ["Infancy", "0-2 years"],
      ["Early Childhood", "2-6 years"],
      ["Middle Childhood", "6-11 years"]
  ]}', 5),
  ('image', '{"url": "https://picsum.photos/seed/ctet-example/800/450", "caption": "Example reference image — replace url with your own upload"}', 6),
  ('pdf_file', '{"url": "https://REPLACE-WITH-YOUR-notes-pdfs-STORAGE-URL/chapter1.pdf", "name": "Chapter 1 Full Notes (PDF)"}', 7),
  ('pdf_link', '{"url": "https://drive.google.com/file/d/REPLACE_WITH_YOUR_FILE_ID/view", "name": "Extra Practice Sheet"}', 8),
  ('example', '{
      "question": "Who among the following is associated with the theory of Cognitive Development?",
      "options": ["Sigmund Freud", "Jean Piaget", "B.F. Skinner", "Ivan Pavlov"],
      "correct_index": 1,
      "explanation": "**Jean Piaget** proposed the theory of Cognitive Development, describing four stages children pass through."
  }', 9)
) as blocks(block_type, content, sort_order);

commit;
