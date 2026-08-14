-- Migration: notification_log (sent-push history for the admin tool)
--
-- Run this once in Supabase Dashboard -> SQL Editor -> New query, on your
-- EXISTING project. Backs ctet_content_admin.php's Notification tab
-- "Pehle Ki Notifications" history list and the exam-targeted send
-- feature — every notification sent from there gets one row here.
--
-- Admin-tool-only (service_role key), same as questions/exams/etc. — no
-- student ever reads this, so it's left with RLS enabled and zero
-- policies rather than an "authenticated" read policy.
--
-- Safe to run more than once.

create table if not exists public.notification_log (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  tap_action text,
  target_exams text[] not null default '{}',
  sent_count int not null default 0,
  total_count int not null default 0,
  sent_at timestamptz not null default now()
);

alter table public.notification_log enable row level security;
