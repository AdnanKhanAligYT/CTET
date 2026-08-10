-- Migration: app_settings (exam countdown date + future global settings)
--
-- Run this once in Supabase Dashboard -> SQL Editor -> New query, on your
-- EXISTING project. Adds the app_settings table the admin tool's Exams
-- tab writes the exam countdown date into, and the app reads to compute
-- its daily "N din baaki hain" reminder.
--
-- Safe to run more than once — create table/policy use if-not-exists /
-- drop-then-create guards.

create table if not exists public.app_settings (
  key text primary key,
  value text
);

alter table public.app_settings enable row level security;

drop policy if exists "app_settings: read for signed-in students" on public.app_settings;
create policy "app_settings: read for signed-in students" on public.app_settings
  for select using (auth.role() = 'authenticated');
