-- Migration: percentile on compute_test_set_rank() + attempts.percentile
--
-- Run this once in Supabase Dashboard -> SQL Editor -> New query, on your
-- EXISTING project. Adds a `percentile` output to the existing
-- compute_test_set_rank() RPC (percentage of *other* completed attempts on
-- the same test set that this student scored higher than) and a column to
-- store it on the `attempts` row, same pattern as rank/participants_count
-- already do — computed once at submit time, never recomputed later.
--
-- Backward compatible: existing callers (PYQ's finishAttempt) that only
-- read `rank`/`participants` from the RPC result are unaffected by the
-- extra `percentile` column in its return row.
--
-- Safe to run more than once.

alter table public.attempts
  add column if not exists percentile numeric;

-- Return type is changing (new column), so the function must be dropped
-- before it can be recreated — CREATE OR REPLACE alone can't do this.
drop function if exists public.compute_test_set_rank(uuid, int, int);

create function public.compute_test_set_rank(
  p_test_set_id uuid,
  p_correct_count int,
  p_elapsed_seconds int
) returns table(rank int, participants int, percentile numeric)
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
       where a.test_set_id = p_test_set_id and a.status = 'completed')::int as participants,
    case
      when (select count(*) from public.attempts a
              where a.test_set_id = p_test_set_id and a.status = 'completed') = 0
        then 100
      else round(
        100 - (select count(*) from public.attempts a
                 where a.test_set_id = p_test_set_id and a.status = 'completed'
                   and a.correct_count >= p_correct_count)::numeric
              / (select count(*) from public.attempts a
                   where a.test_set_id = p_test_set_id and a.status = 'completed')::numeric
              * 100,
        2)
    end as percentile;
$$;

revoke all on function public.compute_test_set_rank(uuid, int, int) from public;
grant execute on function public.compute_test_set_rank(uuid, int, int) to authenticated;
