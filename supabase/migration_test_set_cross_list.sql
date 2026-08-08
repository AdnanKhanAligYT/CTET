-- Migration: cross-listing a test set into both Mock Test and PYQ
--
-- Run this once in Supabase Dashboard -> SQL Editor -> New query, on your
-- EXISTING project (one that already has the test_sets table). Adds a
-- `types` array column so a single test_set row can appear in both the
-- Mock Test and PYQ lists at once (same row, same tagged questions — not
-- a duplicate), toggled from ctet_content_admin.php's "+ ... mein bhi
-- dikhao" button on each test set.
--
-- `type` (singular) is unchanged and still the "primary" list a set was
-- created under; `types` (plural) is every list it currently shows up in,
-- and always at least contains `type`.
--
-- Safe to run more than once — the alter only adds the column if it's
-- missing, and the backfill only touches rows that haven't been
-- backfilled yet (types = '{}').

alter table public.test_sets
  add column if not exists types text[] not null default '{}';

update public.test_sets
  set types = array[type]
  where types = '{}';
