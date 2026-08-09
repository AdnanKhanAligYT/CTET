-- Migration: which flow(s) (Mock Test / PYQ) an exam/paper/section shows under
--
-- Run this once in Supabase Dashboard -> SQL Editor -> New query, on your
-- EXISTING project (one that already has the exams table). Adds the types
-- column — every existing row backfills to both mock_test and pyq, which
-- matches how the app already behaved before this column existed (a node
-- always showed up under both, no way to scope it to just one). The admin
-- tool's Exams tab now has checkboxes to narrow this per node.
--
-- Safe to run more than once — the alter only adds the column if it's
-- missing, and the backfill only touches rows that haven't been
-- backfilled yet (types = '{}').

alter table public.exams
  add column if not exists types text[] not null default array['mock_test', 'pyq'];

update public.exams
  set types = array['mock_test', 'pyq']
  where types = '{}';
