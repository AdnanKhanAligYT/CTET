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
