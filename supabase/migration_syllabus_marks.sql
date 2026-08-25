-- Migration: syllabus_marks_distribution (the per-paper marks-distribution
-- table shown at the top of the Syllabus screen — same jsonb table shape
-- as questions."table": a list of rows, each row a list of cell strings,
-- first row is the header)
--
-- Run this once in Supabase Dashboard -> SQL Editor -> New query, on your
-- EXISTING project.
--
-- Safe to run more than once — uses if-not-exists / upsert.

create table if not exists public.syllabus_marks_distribution (
  exam text primary key,
  table_data jsonb not null
);

alter table public.syllabus_marks_distribution enable row level security;

drop policy if exists "syllabus_marks_distribution: read for signed-in students" on public.syllabus_marks_distribution;
create policy "syllabus_marks_distribution: read for signed-in students" on public.syllabus_marks_distribution
  for select using (auth.role() = 'authenticated');

-- Seeded from the CTET-February 2026 Information Bulletin (Appendix I).
insert into public.syllabus_marks_distribution (exam, table_data) values
('CTET Paper 1', '[
  ["Subject", "MCQs", "Marks"],
  ["Child Development and Pedagogy", "30", "30"],
  ["Mathematics", "30", "30"],
  ["Environmental Studies", "30", "30"],
  ["Language I", "30", "30"],
  ["Language II", "30", "30"],
  ["Total", "150", "150"]
]'::jsonb),
('CTET Paper 2', '[
  ["Subject", "MCQs", "Marks"],
  ["Child Development and Pedagogy", "30", "30"],
  ["Mathematics and Science (for Maths/Science teacher) OR Social Studies/Social Science (for SSt teacher)", "60", "60"],
  ["Language I", "30", "30"],
  ["Language II", "30", "30"],
  ["Total", "150", "150"]
]'::jsonb)
on conflict (exam) do update set table_data = excluded.table_data;
