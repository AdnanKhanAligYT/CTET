-- Migration: questions.bundle_id / bundle_label
--
-- Run this once in Supabase Dashboard -> SQL Editor -> New query, on your
-- EXISTING project. Backs the admin tool's (Study/ctet_content_admin.php)
-- "bundle" system — every Bulk Import batch shares one bundle_id/label, so
-- the whole batch can be re-attached to another test set in one click
-- later ("Bundle Se Tag Karo") instead of re-pasting the same questions
-- and creating duplicate rows.
--
-- Safe to run more than once — uses if-not-exists.

alter table public.questions
  add column if not exists bundle_id uuid,
  add column if not exists bundle_label text;

create index if not exists questions_bundle_id_idx on public.questions (bundle_id);
