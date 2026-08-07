-- Migration: exam/paper logo/icon
--
-- Run this once in Supabase Dashboard -> SQL Editor -> New query, on your
-- EXISTING project (one that already has the exams table). Adds the
-- logo_url column on exams and the public Storage bucket the admin tool
-- uploads exam/paper logos into.
--
-- Safe to run more than once — every statement below only creates/adds
-- something if it isn't already there.

alter table public.exams
  add column if not exists logo_url text;

insert into storage.buckets (id, name, public)
values ('exam-logos', 'exam-logos', true)
on conflict (id) do nothing;
