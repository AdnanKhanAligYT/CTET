-- Notes — curated, chapter-wise study notes (admin-authored), distinct
-- from Notepad (the student's own quick notes). Run this once in Supabase
-- Dashboard -> SQL Editor -> New query.
--
-- The subject list itself is STATIC, hardcoded in the app
-- (lib/features/notes/domain/notes_subjects.dart) — not a table, since it
-- never changes. Only what's INSIDE a subject (its chapters, and each
-- chapter's content) is admin-managed data here.
--
-- A chapter's content is an ordered list of typed blocks (notes_blocks,
-- one row per block, `sort_order` decides render order top to bottom).
-- `block_type` decides how `content` (jsonb) is shaped — see
-- supabase/seed_notes_example.sql for a worked example of every type.
-- Any free-text field inside `content` (a heading's/paragraph's/point's
-- text, an example's question/options/explanation) may contain **word**
-- to render that word bold — same convention everywhere, parsed by the
-- app, not stored as separate markup.

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
  sort_order int not null default 0
);

create index notes_chapters_subject_idx on public.notes_chapters (subject, sort_order);

alter table public.notes_chapters enable row level security;
create policy "notes_chapters: read for signed-in students" on public.notes_chapters
  for select using (auth.role() = 'authenticated');

-- block_type is one of:
--   'heading'    content: {"text": "..."}
--   'subheading' content: {"text": "..."}
--   'paragraph'  content: {"text": "..."}
--   'points'     content: {"items": ["...", "..."]}                  (bullet list)
--   'table'      content: {"rows": [["h1","h2"], ["a","b"]]}          (first row = header)
--   'image'      content: {"url": "...", "caption": "..."}           (caption optional)
--   'pdf_file'   content: {"url": "...", "name": "..."}              (uploaded to the notes-pdfs bucket below)
--   'pdf_link'   content: {"url": "https://drive.google.com/...", "name": "..."}  (external Drive link)
--   'example'    content: {"question": "...", "options": ["...","...","...","..."],
--                          "correct_index": 0, "explanation": "..."}  (options/correct_index/explanation optional)
create table public.notes_blocks (
  id uuid primary key default gen_random_uuid(),
  chapter_id uuid not null references public.notes_chapters (id) on delete cascade,
  block_type text not null,
  content jsonb not null,
  sort_order int not null default 0
);

create index notes_blocks_chapter_idx on public.notes_blocks (chapter_id, sort_order);

alter table public.notes_blocks enable row level security;
create policy "notes_blocks: read for signed-in students" on public.notes_blocks
  for select using (auth.role() = 'authenticated');

-- Uploaded PDF files (see the 'pdf_file' block type) — public so the app
-- can open them with a plain network request, no auth header needed.
-- Upload via Supabase Dashboard -> Storage -> notes-pdfs -> Upload file,
-- then copy its public URL into a 'pdf_file' block's content.url.
insert into storage.buckets (id, name, public)
values ('notes-pdfs', 'notes-pdfs', true)
on conflict (id) do nothing;
