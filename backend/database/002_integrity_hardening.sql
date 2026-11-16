-- 002 — Data-integrity hardening for the 001 schema.
--
-- Additive only: no table, column, or existing constraint is dropped or changed.
-- Each rule closes a gap reproduced against 001 during the Phase 1 audit
-- (docs/PHASE1_AUDIT.md) and is covered by tests/db/.
--
-- Not applied to any live database. No RLS policies are added: every table
-- stays deny-by-default for API roles until the auth model is chosen and
-- policies are designed and tested (audit risk R1).

-- Slugs are stable URL-safe identifiers: lowercase latin letters, digits, hyphens.
alter table public.math_domains
  add constraint math_domains_slug_format check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  add constraint math_domains_titles_not_blank
    check (btrim(title_ar) <> '' and btrim(title_en) <> '');

alter table public.math_topics
  add constraint math_topics_slug_format check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  add constraint math_topics_titles_not_blank
    check (btrim(title_ar) <> '' and btrim(title_en) <> '');

alter table public.skills
  add constraint skills_slug_format check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  add constraint skills_titles_not_blank
    check (btrim(title_ar) <> '' and btrim(title_en) <> '');

alter table public.profiles
  add constraint profiles_display_name_not_blank check (btrim(display_name) <> '');

-- unique (student_id, skill_id) already serves lookups by student; this serves
-- lookups by skill and the cascade from skills.
create index learning_progress_skill_id_idx on public.learning_progress (skill_id);

create function public.set_updated_at() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger learning_progress_set_updated_at
  before update on public.learning_progress
  for each row execute function public.set_updated_at();
