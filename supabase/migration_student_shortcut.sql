-- Migration: per-student "shortcut" folder
--
-- Run this once in Supabase Dashboard -> SQL Editor -> New query, on your
-- EXISTING project (one that already has the exams table). Adds the
-- student_shortcuts table — unlike the exams/test_sets catalog, this one
-- IS written to by the app itself (a student sets/clears their own
-- shortcut from a leaf node's TestSetListScreen), so it has its own
-- RLS policy scoping each row to auth.uid() rather than being read-only.
--
-- Safe to run more than once — create table/policy use if-not-exists /
-- drop-then-create guards.

create table if not exists public.student_shortcuts (
  user_id uuid primary key references auth.users (id) on delete cascade,
  exam_id uuid not null references public.exams (id) on delete cascade,
  -- Which flow (Mock Test vs PYQ) the student was browsing when they set
  -- this — the same leaf node can hold test sets of both types.
  type text not null check (type in ('mock_test', 'pyq')),
  updated_at timestamptz not null default now()
);

alter table public.student_shortcuts enable row level security;

drop policy if exists "student_shortcuts: own row" on public.student_shortcuts;
create policy "student_shortcuts: own row" on public.student_shortcuts
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
