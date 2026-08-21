-- Migration: created_at on questions (so bulk-import bundles can be told
-- apart by when they were uploaded, not just by name).
--
-- Run this once in Supabase Dashboard -> SQL Editor -> New query, on your
-- EXISTING project. Backs ctet_content_admin.php's "Bundles Manage Karo"
-- list, which previously had no way to tell two same-named bundles apart
-- (e.g. two "14 Dec 24 P-1 L-2 Sanskrit 30" imports done on different
-- days) since the questions table had no timestamp at all.
--
-- Existing rows get created_at = now() (their true upload date isn't
-- recoverable), so this only helps distinguish bundles uploaded from here
-- on — that's expected, not a bug.
--
-- Safe to run more than once.

alter table public.questions add column if not exists created_at timestamptz not null default now();
