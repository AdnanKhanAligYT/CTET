-- Migration: device_tokens (push notifications)
--
-- Run this once in Supabase Dashboard -> SQL Editor -> New query, on your
-- EXISTING project. Adds the device_tokens table the app writes its FCM
-- token into, and the reference PHP app's admin tool (Notification tab)
-- reads from to broadcast a manually-composed push notification to every
-- registered device.
--
-- Safe to run more than once — create table/policy use if-not-exists /
-- drop-then-create guards.

create table if not exists public.device_tokens (
  token text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  platform text not null default 'android',
  updated_at timestamptz not null default now()
);

create index if not exists device_tokens_user_id_idx on public.device_tokens (user_id);

alter table public.device_tokens enable row level security;

drop policy if exists "device_tokens: own rows" on public.device_tokens;
create policy "device_tokens: own rows" on public.device_tokens
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
