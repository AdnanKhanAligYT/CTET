-- Migration: questions.table (table-format questions, "study the table
-- below" style)
--
-- Run this once in Supabase Dashboard -> SQL Editor -> New query, on your
-- EXISTING project. Adds the optional `table` column the admin tool's
-- Bulk Import now accepts, and the app renders inline in the question.
--
-- Safe to run more than once — uses if-not-exists.

alter table public.questions
  add column if not exists "table" jsonb;
