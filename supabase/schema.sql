-- CTET & State TET Prep — Supabase schema
--
-- Run this once in Supabase Dashboard -> SQL Editor -> New query, on a
-- fresh project. Replaces the old firestore.rules + implicit Firestore
-- collections with real Postgres tables + Row Level Security policies.
--
-- Naming: the auth user table is `auth.users` (built into every Supabase
-- project). Our own per-student profile row lives in `public.profiles`,
-- keyed 1:1 by the same id, since `users` is reserved by the auth schema.

-- ============================================================
-- profiles (was /users/{uid})
-- ============================================================
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '',
  display_name_source text not null default 'manual',
  email text,
  phone text,
  photo_url text,
  about_you text not null default '',
  account_type text not null default 'free',
  designation text not null default '',
  institution text not null default '',
  city text not null default '',
  city_auto_filled boolean not null default false,
  exams text[] not null default '{}',
  password_set boolean not null default false,
  language text not null default 'hi',
  theme_preference text not null default 'system',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles: own row" on public.profiles
  for all using (auth.uid() = id) with check (auth.uid() = id);

-- Edit Profile watches this table live (StreamProvider), so it needs to be
-- on the realtime publication — new tables aren't added to it by default.
alter publication supabase_realtime add table public.profiles;

-- ============================================================
-- Shared, read-only content (was /questions, /syllabusTopics,
-- /dictionaryWords) — seed these yourself via the Table Editor, same as
-- you would have added Firestore documents.
-- ============================================================
create table public.questions (
  id uuid primary key default gen_random_uuid(),
  subject text not null,
  topic text not null,
  exam_tags text[] not null default '{}',
  text text not null,
  options text[] not null,
  correct_option_index int not null,
  explanations text[] not null
);

alter table public.questions enable row level security;
create policy "questions: read for signed-in students" on public.questions
  for select using (auth.role() = 'authenticated');

create table public.syllabus_topics (
  id uuid primary key default gen_random_uuid(),
  exam text not null,
  subject text not null,
  unit text not null,
  topic_name text not null,
  "order" int not null default 0,
  estimated_hours numeric
);

alter table public.syllabus_topics enable row level security;
create policy "syllabus_topics: read for signed-in students" on public.syllabus_topics
  for select using (auth.role() = 'authenticated');

create table public.dictionary_words (
  id uuid primary key default gen_random_uuid(),
  word text not null,
  meaning_hi text not null,
  meaning_en text not null,
  example_sentence text not null default ''
);

alter table public.dictionary_words enable row level security;
create policy "dictionary_words: read for signed-in students" on public.dictionary_words
  for select using (auth.role() = 'authenticated');

-- ============================================================
-- Per-student data (was /users/{uid}/{subcollection})
-- ============================================================
create table public.question_progress (
  user_id uuid not null references auth.users (id) on delete cascade,
  question_id uuid not null references public.questions (id) on delete cascade,
  completed_count int not null default 0,
  due_date timestamptz not null default now(),
  last_result text,
  last_reviewed_at timestamptz,
  primary key (user_id, question_id)
);

alter table public.question_progress enable row level security;
create policy "question_progress: own rows" on public.question_progress
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table public.dictionary_progress (
  user_id uuid not null references auth.users (id) on delete cascade,
  word_id uuid not null references public.dictionary_words (id) on delete cascade,
  completed_count int not null default 0,
  due_date timestamptz not null default now(),
  last_result text,
  last_reviewed_at timestamptz,
  primary key (user_id, word_id)
);

alter table public.dictionary_progress enable row level security;
create policy "dictionary_progress: own rows" on public.dictionary_progress
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table public.syllabus_progress (
  user_id uuid not null references auth.users (id) on delete cascade,
  topic_id uuid not null references public.syllabus_topics (id) on delete cascade,
  status text not null default 'not_started',
  completed_at timestamptz,
  primary key (user_id, topic_id)
);

alter table public.syllabus_progress enable row level security;
create policy "syllabus_progress: own rows" on public.syllabus_progress
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table public.timetable_blocks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  day_of_week int not null,
  start_minutes int not null,
  end_minutes int not null,
  subject text not null,
  done boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table public.timetable_blocks enable row level security;
create policy "timetable_blocks: own rows" on public.timetable_blocks
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table public.notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null default '',
  body text not null default '',
  pinned boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.notes enable row level security;
create policy "notes: own rows" on public.notes
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table public.attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  total_questions int not null default 0,
  correct_count int not null default 0,
  wrong_count int not null default 0,
  started_at timestamptz not null default now(),
  submitted_at timestamptz not null default now()
);

alter table public.attempts enable row level security;
create policy "attempts: own rows" on public.attempts
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ============================================================
-- Structured Mock Test / Previous Year Questions catalog
--
-- Replaces "tap Mock Test, get today's due questions mixed together" with
-- a browsable exam -> paper -> named test hierarchy. Admin-managed (read
-- only from the app), same pattern as questions/syllabus_topics/
-- dictionary_words above — add/edit/remove rows from the reference PHP
-- app's Termux admin tool, which holds the Supabase service_role key and
-- so bypasses RLS entirely.
-- ============================================================
create table public.exams (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  -- null = top-level exam (e.g. "CTET"); non-null = a paper under it
  -- (e.g. "CTET Paper 1"). Only two levels deep are supported by the app.
  parent_exam_id uuid references public.exams (id) on delete cascade,
  -- Optional uploaded PNG/JPG/WebP (exam-logos Storage bucket below)
  -- shown before the name in the exam/paper list — null falls back to a
  -- plain default icon in the app.
  logo_url text,
  sort_order int not null default 0,
  active boolean not null default true
);

create index exams_parent_idx on public.exams (parent_exam_id);

alter table public.exams enable row level security;
create policy "exams: read for signed-in students" on public.exams
  for select using (auth.role() = 'authenticated');

-- Uploaded exam/paper logos (see exams.logo_url) — public so the app can
-- load them with a plain network image request, no auth header needed.
-- Only the admin tool ever writes here, using the service_role key, which
-- bypasses Storage RLS the same way it bypasses every table's RLS above.
insert into storage.buckets (id, name, public)
values ('exam-logos', 'exam-logos', true)
on conflict (id) do nothing;

create table public.test_sets (
  id uuid primary key default gen_random_uuid(),
  -- Always a paper-level exam row (parent_exam_id is not null on it).
  exam_id uuid not null references public.exams (id) on delete cascade,
  type text not null check (type in ('mock_test', 'pyq')),
  name text not null,
  -- Optional uploaded PNG/JPG/WebP (Storage bucket below) shown before
  -- the test's name in the Mock Test/PYQ list — null falls back to a
  -- plain default icon in the app.
  logo_url text,
  -- Ordered subject tabs the test screen walks through — by default the
  -- next subject only becomes reachable once every question in the
  -- current one is answered; manually tapping a tab always works.
  subjects text[] not null default '{}',
  time_limit_minutes int,
  -- Previous Year Questions only; null for mock_test sets.
  year int,
  sort_order int not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create index test_sets_exam_type_idx on public.test_sets (exam_id, type);

alter table public.test_sets enable row level security;
create policy "test_sets: read for signed-in students" on public.test_sets
  for select using (auth.role() = 'authenticated');

create table public.test_set_questions (
  set_id uuid not null references public.test_sets (id) on delete cascade,
  question_id uuid not null references public.questions (id) on delete cascade,
  -- Explicit, stable ordering (not shuffled) — a resumed attempt's
  -- "current question in this subject" is derived by walking this order
  -- and skipping already-answered questions, so the order can't drift
  -- between sessions the way a re-shuffle-on-load would.
  position int not null default 0,
  primary key (set_id, question_id)
);

alter table public.test_set_questions enable row level security;
create policy "test_set_questions: read for signed-in students" on public.test_set_questions
  for select using (auth.role() = 'authenticated');

-- Uploaded test-set logos (see test_sets.logo_url) — public so the app can
-- load them with a plain network image request, no auth header needed.
-- Only the admin tool ever writes here, using the service_role key, which
-- bypasses Storage RLS the same way it bypasses every table's RLS above.
insert into storage.buckets (id, name, public)
values ('test-set-logos', 'test-set-logos', true)
on conflict (id) do nothing;

-- ── Resumable, unlimited-retake attempts on a named test set ──
-- (daily due-today practice via take_test.php-equivalent keeps using the
-- original columns above with test_set_id left null.)
alter table public.attempts
  add column test_set_id uuid references public.test_sets (id) on delete set null,
  add column status text not null default 'completed'
    check (status in ('in_progress', 'completed', 'abandoned')),
  add column current_subject_index int not null default 0,
  add column answers jsonb not null default '{}'::jsonb,
  add column elapsed_seconds int not null default 0,
  add column rank int,
  add column participants_count int;

create index attempts_test_set_id_idx on public.attempts (test_set_id);

-- At most one in-progress attempt per student per test set — "Naya Start
-- karo" must abandon the existing in_progress row first (app-enforced),
-- this index just guarantees it can never be two.
create unique index attempts_in_progress_unique
  on public.attempts (user_id, test_set_id)
  where status = 'in_progress';

-- Ranks a just-finished attempt against every other *completed* attempt
-- on the same test_set — score first, faster time as the tie-break.
-- SECURITY DEFINER so it can see every student's attempts for this one
-- aggregate computation despite attempts' RLS being "own rows only" for
-- everything else; it returns nothing but the rank + participant count,
-- never another student's individual score.
create or replace function public.compute_test_set_rank(
  p_test_set_id uuid,
  p_correct_count int,
  p_elapsed_seconds int
) returns table(rank int, participants int)
language sql
security definer
set search_path = public
as $$
  select
    (select count(*) + 1 from public.attempts a
       where a.test_set_id = p_test_set_id
         and a.status = 'completed'
         and (a.correct_count > p_correct_count
              or (a.correct_count = p_correct_count
                  and a.elapsed_seconds < p_elapsed_seconds)))::int as rank,
    (select count(*) from public.attempts a
       where a.test_set_id = p_test_set_id and a.status = 'completed')::int as participants;
$$;

revoke all on function public.compute_test_set_rank(uuid, int, int) from public;
grant execute on function public.compute_test_set_rank(uuid, int, int) to authenticated;
