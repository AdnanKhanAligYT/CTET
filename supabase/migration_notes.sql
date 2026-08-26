-- Notes — curated, chapter-wise study notes (admin-authored), distinct
-- from Notepad (the student's own quick notes). Run this once in Supabase
-- Dashboard -> SQL Editor -> New query.
--
-- The subject list itself is STATIC, hardcoded in the app
-- (lib/features/notes/domain/notes_subjects.dart) — not a table, since it
-- never changes. Only what's INSIDE a subject (its chapters) is
-- admin-managed data here.
--
-- A chapter's ENTIRE content lives as one jsonb array on its own row
-- (`content` below) — not spread across separate child rows — so it's
-- editable in Study App's admin panel as a single JSON blob per chapter,
-- one paste/edit replaces that whole chapter's content in one go.
--
-- `content` is an array of blocks, each shaped {"type": "...", "data": {...}}:
--   heading    data: {"text": "..."}
--   subheading data: {"text": "..."}
--   paragraph  data: {"text": "..."}
--   points     data: {"items": ["...", "..."]}                          (bullet list)
--   table      data: {"rows": [["h1","h2"], ["a","b"]]}                 (first row = header)
--   image      data: {"url": "...", "caption": "..."}                  (caption optional)
--   pdf_file   data: {"url": "...", "name": "..."}                     (uploaded to the notes-pdfs bucket below)
--   pdf_link   data: {"url": "https://drive.google.com/...", "name": "..."}  (external Drive link)
--   example    data: {"question": "...", "options": ["...","...","...","..."],
--                      "correct_index": 0, "explanation": "..."}       (options/correct_index/explanation optional)
-- Any free-text field inside a block's data may contain **word** for
-- inline bold, same convention everywhere.
create table public.notes_chapters (
  id uuid primary key default gen_random_uuid(),
  -- Must match one of the static subjects in notes_subjects.dart exactly
  -- (e.g. "Mathematics Paper-1", "Hindi 1st") — not enforced by a DB
  -- constraint since the list lives in the app, not a lookup table.
  subject text not null,
  -- Optional grouping shown above chapter_name in the chapter list (e.g.
  -- "Unit 1") — purely a label, doesn't affect sorting on its own.
  unit text,
  chapter_number int,
  chapter_name text not null,
  sort_order int not null default 0,
  content jsonb not null default '[]'::jsonb
);

create index notes_chapters_subject_idx on public.notes_chapters (subject, sort_order);

alter table public.notes_chapters enable row level security;
create policy "notes_chapters: read for signed-in students" on public.notes_chapters
  for select using (auth.role() = 'authenticated');

-- Uploaded PDF files (see the 'pdf_file' block type) — public so the app
-- can open them with a plain network request, no auth header needed.
-- Upload via Supabase Dashboard -> Storage -> notes-pdfs -> Upload file,
-- then copy its public URL into a 'pdf_file' block's data.url.
insert into storage.buckets (id, name, public)
values ('notes-pdfs', 'notes-pdfs', true)
on conflict (id) do nothing;
