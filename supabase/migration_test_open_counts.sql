-- Migration: visible "opened N times" counters — test sets, Subject Wise
-- Revision blocks, Bullet Revision durations
--
-- Run this once in Supabase Dashboard -> SQL Editor -> New query, on your
-- EXISTING project. Same "global counter + security-definer RPC" shape as
-- migration_exam_open_count.sql (exams.open_count) — that one only ever
-- drove folder sort order; these three make the count visible on screen
-- next to each test/block/duration.
--
-- Safe to run more than once.

-- Mock Test / PYQ: one counter per test_sets row.
alter table public.test_sets
  add column if not exists open_count int not null default 0;

create or replace function public.increment_test_set_open_count(p_test_set_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.test_sets set open_count = open_count + 1 where id = p_test_set_id;
$$;

revoke all on function public.increment_test_set_open_count(uuid) from public;
grant execute on function public.increment_test_set_open_count(uuid) to authenticated;

-- Subject Wise Revision blocks aren't rows in any table — they're
-- computed chunk-of-N slices of a subject's question pool (see
-- SubjectBlockListScreen) — so their counters live in their own small
-- table keyed by (subject, block_index) instead of a foreign key.
create table if not exists public.subject_block_open_counts (
  subject text not null,
  block_index int not null,
  open_count int not null default 0,
  primary key (subject, block_index)
);

alter table public.subject_block_open_counts enable row level security;
drop policy if exists "subject_block_open_counts: read for signed-in students" on public.subject_block_open_counts;
create policy "subject_block_open_counts: read for signed-in students" on public.subject_block_open_counts
  for select using (auth.role() = 'authenticated');

create or replace function public.increment_subject_block_open_count(p_subject text, p_block_index int)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.subject_block_open_counts (subject, block_index, open_count)
  values (p_subject, p_block_index, 1)
  on conflict (subject, block_index)
  do update set open_count = subject_block_open_counts.open_count + 1;
$$;

revoke all on function public.increment_subject_block_open_count(text, int) from public;
grant execute on function public.increment_subject_block_open_count(text, int) to authenticated;

-- Bullet Revision's duration buttons aren't rows either — counters keyed
-- by the duration in minutes (1/5/10/20/30/60).
create table if not exists public.bullet_revision_duration_open_counts (
  duration_minutes int primary key,
  open_count int not null default 0
);

alter table public.bullet_revision_duration_open_counts enable row level security;
drop policy if exists "bullet_revision_duration_open_counts: read for signed-in students" on public.bullet_revision_duration_open_counts;
create policy "bullet_revision_duration_open_counts: read for signed-in students" on public.bullet_revision_duration_open_counts
  for select using (auth.role() = 'authenticated');

create or replace function public.increment_bullet_revision_duration_open_count(p_duration_minutes int)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.bullet_revision_duration_open_counts (duration_minutes, open_count)
  values (p_duration_minutes, 1)
  on conflict (duration_minutes)
  do update set open_count = bullet_revision_duration_open_counts.open_count + 1;
$$;

revoke all on function public.increment_bullet_revision_duration_open_count(int) from public;
grant execute on function public.increment_bullet_revision_duration_open_count(int) to authenticated;
