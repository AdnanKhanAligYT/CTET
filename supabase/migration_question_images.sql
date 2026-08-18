-- Migration: questions.image_urls (figures/diagrams for a question, e.g.
-- Mathematics geometry figures)
--
-- Run this once in Supabase Dashboard -> SQL Editor -> New query, on your
-- EXISTING project. Adds the optional `image_urls` column the admin
-- tool's question form / Bulk Import now accepts, and the app renders
-- inline at each literal "{{img}}" marker in the question's text.
--
-- No per-image number to track: the Nth "{{img}}" marker in the text is
-- always filled by the Nth entry of this array, so re-ordering the array
-- (or the markers) is all that's ever needed — never a number.
--
-- Safe to run more than once — uses if-not-exists.

alter table public.questions
  add column if not exists image_urls jsonb;

-- Public so the app can load figures with a plain network image request,
-- no auth header needed. Only the admin tool ever writes here, using the
-- service_role key, which bypasses Storage RLS the same way it bypasses
-- every table's RLS elsewhere in this schema.
insert into storage.buckets (id, name, public)
values ('question-images', 'question-images', true)
on conflict (id) do nothing;
