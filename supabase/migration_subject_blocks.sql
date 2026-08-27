-- Migration: pre-computed Subject Wise Revision blocks
--
-- Until now, "CDP 1st"/"CDP 2nd"/... blocks were computed live on every
-- screen open — fetch every question for the subject, dedupe by text,
-- sort by id, slice into chunks — both to show the block list AND again
-- to actually start a test. That's the same "fetch way more than needed"
-- problem migration_test_open_counts.sql's sibling fix (Subject Wise
-- Revision's subject-count screen) already solved once; this does the
-- same for the block list and the test-start path.
--
-- Blocks now live in their own table, maintained automatically by a
-- trigger on `questions`, so:
--   - The block list is one cheap SELECT instead of fetching every
--     question in the subject.
--   - Starting a test is one SELECT for that block's exact question ids,
--     then fetching only those — not the whole subject's pool.
--   - A block, once created, is FROZEN — its question_ids never change
--     again, even if new questions are uploaded in between. That's a
--     stronger stability guarantee than the old "sort by id" approach
--     (a new question's random uuid could land anywhere in id-sort
--     order, silently shifting which questions were in "CDP 1st").
--   - Only COMPLETE blocks are ever created — 30 questions per block
--     (60 for SST) — so a trailing partial block (e.g. 2 leftover
--     questions) simply doesn't exist/show until enough new questions
--     arrive to fill it.
--
-- Safe to run more than once.

create table if not exists public.subject_blocks (
  id uuid primary key default gen_random_uuid(),
  subject text not null,
  block_index int not null,
  question_ids uuid[] not null,
  created_at timestamptz not null default now(),
  unique (subject, block_index)
);

alter table public.subject_blocks enable row level security;
drop policy if exists "subject_blocks: read for signed-in students" on public.subject_blocks;
create policy "subject_blocks: read for signed-in students" on public.subject_blocks
  for select using (auth.role() = 'authenticated');

-- Carves out as many new complete blocks for [p_subject] as the current
-- unassigned pool allows. "Unassigned" = questions with this subject,
-- deduped by trimmed text (oldest `created_at` wins a duplicate — same
-- rule dedupeByText already applied client-side, now server-side and
-- permanent), minus every id already sitting inside an existing block
-- for this subject. Oldest-first by `created_at` (a real, meaningful
-- order — unlike `id`, which is a random uuid) decides which questions
-- fill the next block.
create or replace function public.recompute_subject_blocks_for(p_subject text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_chunk_size int;
  v_next_index int;
  v_unassigned uuid[];
begin
  v_chunk_size := case
    when lower(p_subject) like '%sst%'
      or lower(p_subject) like '%social studies%'
      or lower(p_subject) like '%social science%'
    then 60 else 30
  end;

  select coalesce(max(block_index), -1) + 1 into v_next_index
  from public.subject_blocks
  where subject = p_subject;

  loop
    select array_agg(id order by created_at, id) into v_unassigned
    from (
      select distinct on (trim(q.text)) q.id, q.created_at
      from public.questions q
      where q.subject = p_subject
        and not (q.id = any (
          coalesce(
            (select array_agg(elem)
             from public.subject_blocks sb
             cross join lateral unnest(sb.question_ids) as elem
             where sb.subject = p_subject),
            array[]::uuid[]
          )
        ))
      order by trim(q.text), q.created_at
    ) deduped;

    exit when v_unassigned is null or array_length(v_unassigned, 1) < v_chunk_size;

    insert into public.subject_blocks (subject, block_index, question_ids)
    values (p_subject, v_next_index, v_unassigned[1:v_chunk_size]);

    v_next_index := v_next_index + 1;
  end loop;
end;
$$;

-- Fires on every question insert (new upload) and on a subject re-tag —
-- the two ways the unassigned pool for some subject can grow. Deleting a
-- question that already sits inside a frozen block is left alone
-- deliberately (blocks are frozen by design); that block just ends up
-- one question short, same as any other data-entry correction would.
create or replace function public.trg_recompute_subject_blocks()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.recompute_subject_blocks_for(NEW.subject);
  if TG_OP = 'UPDATE' and OLD.subject is distinct from NEW.subject then
    perform public.recompute_subject_blocks_for(OLD.subject);
  end if;
  return NEW;
end;
$$;

drop trigger if exists questions_recompute_subject_blocks on public.questions;
create trigger questions_recompute_subject_blocks
after insert or update of subject on public.questions
for each row execute function public.trg_recompute_subject_blocks();

-- One-time backfill for every subject that already has questions.
do $$
declare
  s text;
begin
  for s in select distinct subject from public.questions loop
    perform public.recompute_subject_blocks_for(s);
  end loop;
end;
$$;
