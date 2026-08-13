-- Migration: exam folder open-count tracking + increment_exam_open_count() RPC
--
-- Run this once in Supabase Dashboard -> SQL Editor -> New query, on your
-- EXISTING project. Adds an `open_count` column to `exams` (how many times
-- each folder/paper has been opened, all students combined) and a
-- security-definer RPC to bump it atomically from the app — authenticated
-- clients can only SELECT on `exams` (RLS policy), not UPDATE, so a direct
-- client-side update isn't possible.
--
-- Safe to run more than once.

alter table public.exams
  add column if not exists open_count int not null default 0;

create or replace function public.increment_exam_open_count(p_exam_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.exams set open_count = open_count + 1 where id = p_exam_id;
$$;

revoke all on function public.increment_exam_open_count(uuid) from public;
grant execute on function public.increment_exam_open_count(uuid) to authenticated;
