-- Migration: Bullet Revision rotation state
--
-- Run this once in Supabase Dashboard -> SQL Editor -> New query, on your
-- EXISTING project (one that already has the questions table). Adds the
-- bullet_revision_state table, written to by the app itself (each time a
-- student runs a Bullet Revision test) — same "own row" RLS shape as
-- student_shortcuts/question_progress.
--
-- Safe to run more than once — create table/policy use if-not-exists /
-- drop-then-create guards.

-- One row per student: the CDP question ids still left to show in the
-- current cycle. BulletRevisionRepository.pickNextQuestionIds() pops ids
-- off the front of this list for each test and tops it back up with a
-- freshly shuffled full pool whenever it runs out — so a student never
-- sees the same CDP question twice until every one of them has appeared
-- once, then the cycle restarts from scratch. No row (or an empty array)
-- just means "start a fresh cycle" — the client lazily creates it on
-- first use, same stance as question_progress.
create table if not exists public.bullet_revision_state (
  user_id uuid primary key references auth.users (id) on delete cascade,
  remaining_question_ids uuid[] not null default '{}',
  updated_at timestamptz not null default now()
);

alter table public.bullet_revision_state enable row level security;

drop policy if exists "bullet_revision_state: own row" on public.bullet_revision_state;
create policy "bullet_revision_state: own row" on public.bullet_revision_state
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
