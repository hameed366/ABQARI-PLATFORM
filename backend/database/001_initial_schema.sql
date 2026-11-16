-- ABQARI initial conceptual schema (PostgreSQL).
-- Review and test in a disposable database before production use.
-- No country/curriculum/textbook hierarchy is included.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key,
  display_name text not null,
  role text not null check (role in ('student', 'teacher', 'admin')),
  preferred_locale text not null default 'ar'
    check (preferred_locale in ('ar', 'en')),
  created_at timestamptz not null default now()
);

create table if not exists public.math_domains (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title_ar text not null,
  title_en text not null,
  sort_order integer not null default 0
);

create table if not exists public.math_topics (
  id uuid primary key default gen_random_uuid(),
  domain_id uuid not null references public.math_domains(id) on delete cascade,
  slug text not null,
  title_ar text not null,
  title_en text not null,
  difficulty smallint check (difficulty between 1 and 5),
  unique (domain_id, slug)
);

create table if not exists public.skills (
  id uuid primary key default gen_random_uuid(),
  topic_id uuid not null references public.math_topics(id) on delete cascade,
  slug text not null,
  title_ar text not null,
  title_en text not null,
  description_ar text,
  description_en text,
  unique (topic_id, slug)
);

create table if not exists public.learning_progress (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles(id) on delete cascade,
  skill_id uuid not null references public.skills(id) on delete cascade,
  mastery numeric(5,2) not null default 0 check (mastery between 0 and 100),
  updated_at timestamptz not null default now(),
  unique (student_id, skill_id)
);

-- RLS is enabled by default for user-owned data.
-- Add explicit policies only after the authentication model and role
-- boundaries have been designed and tested.
alter table public.profiles enable row level security;
alter table public.learning_progress enable row level security;
alter table public.math_domains enable row level security;
alter table public.math_topics enable row level security;
alter table public.skills enable row level security;
