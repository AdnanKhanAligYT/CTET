-- Migration: exam/folder shortcut on the dashboard
--
-- Run this once in Supabase Dashboard -> SQL Editor -> New query, on your
-- EXISTING project (one that already has the exams table). Adds the
-- is_shortcut column, plus a partial unique index that guarantees at most
-- one exams row app-wide has it set to true (same pattern as
-- attempts_in_progress_unique) — ctet_content_admin.php's "Shortcut bana
-- do" button relies on this to make setting a new shortcut automatically
-- clear the old one.
--
-- Safe to run more than once — the alter only adds the column if it's
-- missing, and the index create is idempotent (if-not-exists).

alter table public.exams
  add column if not exists is_shortcut boolean not null default false;

create unique index if not exists exams_shortcut_unique on public.exams (is_shortcut)
  where is_shortcut;
