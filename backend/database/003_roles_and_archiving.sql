-- 003 — Two approved product/security decisions (docs/DECISIONS.md, 2026-11-16).
--
-- R1  Roles leave public.profiles. A profile row is something its owner will
--     eventually be allowed to edit; the role must not sit in the same row, or
--     the first "update own profile" policy becomes a privilege escalation.
--     Roles now live in public.user_roles, which no API role can write.
--
-- R2  Content with student progress can no longer be deleted. Deleting a
--     domain/topic/skill used to cascade into learning_progress and silently
--     erase every student's mastery. Content is archived instead.
--
-- Unlike 002 this migration CHANGES 001 objects (drops profiles.role, replaces
-- one foreign key). Existing role values are carried over first.
-- Not applied to any live database.

-- ── R1: roles ───────────────────────────────────────────────────────────────
create table public.user_roles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  role text not null default 'student'
    check (role in ('student', 'teacher', 'admin')),
  granted_at timestamptz not null default now()
);

alter table public.user_roles enable row level security;

insert into public.user_roles (user_id, role)
select id, role from public.profiles;

alter table public.profiles drop column role;

-- Every new profile starts as a student. Promotion to teacher/admin is a
-- separate, server-side write to user_roles.
create function public.assign_default_role() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.user_roles (user_id) values (new.id);
  return new;
end;
$$;

revoke all on function public.assign_default_role() from public;

create trigger profiles_assign_default_role
  after insert on public.profiles
  for each row execute function public.assign_default_role();

-- ── R2: archive instead of delete ───────────────────────────────────────────
alter table public.math_domains add column archived_at timestamptz;
alter table public.math_topics add column archived_at timestamptz;
alter table public.skills add column archived_at timestamptz;

alter table public.learning_progress
  drop constraint learning_progress_skill_id_fkey,
  add constraint learning_progress_skill_id_fkey
    foreign key (skill_id) references public.skills(id) on delete restrict;
