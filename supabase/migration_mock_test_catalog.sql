-- Migration: Structured Mock Test / Previous Year Questions catalog
--
-- Run this once in Supabase Dashboard -> SQL Editor -> New query, on your
-- EXISTING project (the one you already ran schema.sql on before). This adds
-- only the pieces that were added to the app later — the `exams`, `test_sets`,
-- `test_set_questions` tables, the extra columns on `attempts`, and the
-- `compute_test_set_rank` function. Without this, tapping Mock Test,
-- Previous Year Questions, or History shows a loading circle that never
-- stops, because the app is querying tables that don't exist yet in your
-- database.
--
-- Safe to run more than once — every statement below only creates/adds
-- something if it isn't already there.

create table if not exists public.exams (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  parent_exam_id uuid references public.exams (id) on delete cascade,
  sort_order int not null default 0,
  active boolean not null default true
);

create index if not exists exams_parent_idx on public.exams (parent_exam_id);

alter table public.exams enable row level security;

drop policy if exists "exams: read for signed-in students" on public.exams;
create policy "exams: read for signed-in students" on public.exams
  for select using (auth.role() = 'authenticated');

create table if not exists public.test_sets (
  id uuid primary key default gen_random_uuid(),
  exam_id uuid not null references public.exams (id) on delete cascade,
  type text not null check (type in ('mock_test', 'pyq')),
  name text not null,
  subjects text[] not null default '{}',
  time_limit_minutes int,
  year int,
  sort_order int not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists test_sets_exam_type_idx on public.test_sets (exam_id, type);

alter table public.test_sets enable row level security;

drop policy if exists "test_sets: read for signed-in students" on public.test_sets;
create policy "test_sets: read for signed-in students" on public.test_sets
  for select using (auth.role() = 'authenticated');

create table if not exists public.test_set_questions (
  set_id uuid not null references public.test_sets (id) on delete cascade,
  question_id uuid not null references public.questions (id) on delete cascade,
  position int not null default 0,
  primary key (set_id, question_id)
);

alter table public.test_set_questions enable row level security;

drop policy if exists "test_set_questions: read for signed-in students" on public.test_set_questions;
create policy "test_set_questions: read for signed-in students" on public.test_set_questions
  for select using (auth.role() = 'authenticated');

alter table public.attempts
  add column if not exists test_set_id uuid references public.test_sets (id) on delete set null,
  add column if not exists status text not null default 'completed'
    check (status in ('in_progress', 'completed', 'abandoned')),
  add column if not exists current_subject_index int not null default 0,
  add column if not exists answers jsonb not null default '{}'::jsonb,
  add column if not exists elapsed_seconds int not null default 0,
  add column if not exists rank int,
  add column if not exists participants_count int;

create index if not exists attempts_test_set_id_idx on public.attempts (test_set_id);

create unique index if not exists attempts_in_progress_unique
  on public.attempts (user_id, test_set_id)
  where status = 'in_progress';

create or replace function public.compute_test_set_rank(
  p_test_set_id uuid,
  p_correct_count int,
  p_elapsed_seconds int
) returns table(rank int, participants int)
language sql
security definer
set search_path = public
as $$
  select
    (select count(*) + 1 from public.attempts a
       where a.test_set_id = p_test_set_id
         and a.status = 'completed'
         and (a.correct_count > p_correct_count
              or (a.correct_count = p_correct_count
                  and a.elapsed_seconds < p_elapsed_seconds)))::int as rank,
    (select count(*) from public.attempts a
       where a.test_set_id = p_test_set_id and a.status = 'completed')::int as participants;
$$;

revoke all on function public.compute_test_set_rank(uuid, int, int) from public;
grant execute on function public.compute_test_set_rank(uuid, int, int) to authenticated;
