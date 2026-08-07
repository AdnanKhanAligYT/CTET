-- Migration: test-set logo/icon
--
-- Run this once in Supabase Dashboard -> SQL Editor -> New query, on your
-- EXISTING project (the one that already has exams/test_sets — i.e. you
-- already ran migration_mock_test_catalog.sql). Adds the logo_url column
-- on test_sets and the public Storage bucket the admin tool uploads
-- logos into. Without this, the admin tool's logo upload will fail and
-- the app has nothing to show even if it did work.
--
-- Safe to run more than once — every statement below only creates/adds
-- something if it isn't already there.

alter table public.test_sets
  add column if not exists logo_url text;

insert into storage.buckets (id, name, public)
values ('test-set-logos', 'test-set-logos', true)
on conflict (id) do nothing;
