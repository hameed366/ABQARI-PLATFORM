-- 004 — Phase 8: accounts, classes and the first access policies.
--
-- Until now every table was deny-by-default (RLS on, no policies). This
-- migration opens exactly what the apps need, nothing more:
--
--   * A signed-up user gets a profile and the role 'student' automatically.
--     The role is never taken from sign-up data; only an admin changes it,
--     through set_user_role().
--   * Accounts are optional. Both apps keep working offline without one, so
--     the anonymous API role gets no access to any table.
--   * A teacher creates classes; each class has a join code. A student joins
--     with the code (join_class) and from then on that teacher can read the
--     student's display name and progress — and nothing else about them.
--   * Each user reads and writes only their own progress. Progress is
--     self-reported by the app (practice, not exams); see docs/PHASE8_REPORT.md.
--   * Content (domains/topics/skills) is readable by signed-in users while not
--     archived, and writable only by admins.
--
-- Written for Supabase (auth.users, auth.uid(), roles anon/authenticated).
-- Tested on plain PostgreSQL with tests/db/api_roles_shim.sql standing in.

-- ── profiles belong to auth users ──────────────────────────────────────────
-- If a profile exists with no matching auth user this fails and the whole
-- migration rolls back; it never deletes data to make room.
alter table public.profiles
  add constraint profiles_id_fkey
    foreign key (id) references auth.users(id) on delete cascade;

alter table public.profiles
  add constraint profiles_display_name_length check (char_length(display_name) <= 60);

-- A new auth user gets a profile (and, through 003's trigger, the role
-- 'student'). Only the display name and the language come from sign-up data.
create function public.handle_new_user() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  wanted_name text := btrim(coalesce(new.raw_user_meta_data ->> 'display_name', ''));
  wanted_locale text := coalesce(new.raw_user_meta_data ->> 'preferred_locale', 'ar');
begin
  if wanted_name = '' then
    wanted_name := split_part(coalesce(new.email, ''), '@', 1);
  end if;
  if wanted_name = '' then
    wanted_name := 'ABQARI';
  end if;
  if wanted_locale not in ('ar', 'en') then
    wanted_locale := 'ar';
  end if;
  insert into public.profiles (id, display_name, preferred_locale)
    values (new.id, left(wanted_name, 60), wanted_locale);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ── progress details ───────────────────────────────────────────────────────
alter table public.learning_progress
  add column attempts integer not null default 0 check (attempts >= 0),
  add column mastered boolean not null default false,
  alter column student_id set default auth.uid();

-- ── classes ────────────────────────────────────────────────────────────────
-- Join codes: 8 characters, no look-alikes (0/O, 1/I/L), ~8.5e11 values.
create function public.new_join_code() returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  -- gen_random_uuid() is built in (no extension schema to qualify) and
  -- carries 122 random bits; 8 of its bytes are plenty for one code.
  bytes bytea := decode(replace(gen_random_uuid()::text, '-', ''), 'hex');
  code text := '';
begin
  for i in 0..7 loop
    code := code || substr(alphabet, 1 + (get_byte(bytes, i) % length(alphabet)), 1);
  end loop;
  return code;
end;
$$;

create table public.classes (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null default auth.uid()
    references public.profiles(id) on delete cascade,
  name text not null
    check (btrim(name) <> '' and char_length(name) <= 80),
  join_code text not null unique default public.new_join_code()
    check (join_code ~ '^[A-HJKMNP-Z2-9]{8}$'),
  created_at timestamptz not null default now(),
  archived_at timestamptz
);

create table public.class_members (
  class_id uuid not null references public.classes(id) on delete cascade,
  student_id uuid not null default auth.uid()
    references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (class_id, student_id)
);

create index class_members_student_idx on public.class_members (student_id);
create index classes_teacher_idx on public.classes (teacher_id);

alter table public.classes enable row level security;
alter table public.class_members enable row level security;

-- ── helper functions ───────────────────────────────────────────────────────
-- SECURITY DEFINER so policies can ask these questions without recursing
-- into each other's RLS. Each answers only about the calling user.
create function public.my_role() returns text
language sql stable security definer set search_path = ''
as $$ select role from public.user_roles where user_id = auth.uid() $$;

create function public.is_admin() returns boolean
language sql stable security definer set search_path = ''
as $$ select coalesce(public.my_role() = 'admin', false) $$;

create function public.teaches(student uuid) returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.class_members m
    join public.classes c on c.id = m.class_id
    where m.student_id = student
      and c.teacher_id = auth.uid()
      and c.archived_at is null
  )
$$;

create function public.is_my_teacher(teacher uuid) returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.class_members m
    join public.classes c on c.id = m.class_id
    where m.student_id = auth.uid()
      and c.teacher_id = teacher
      and c.archived_at is null
  )
$$;

create function public.in_class(class uuid) returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.class_members
    where class_id = class and student_id = auth.uid()
  )
$$;

-- ── table privileges ───────────────────────────────────────────────────────
-- Hosted Postgres APIs grant everything on public tables to the API roles by
-- default; narrow that to what the policies below are written for.
revoke all on all tables in schema public from anon, authenticated;

grant select on public.profiles to authenticated;
grant update (display_name, preferred_locale) on public.profiles to authenticated;

grant select on public.user_roles to authenticated;

grant select on public.math_domains, public.math_topics, public.skills to authenticated;
grant insert, update, delete on public.math_domains, public.math_topics, public.skills
  to authenticated;  -- policies restrict these to admins

grant select on public.learning_progress to authenticated;
grant insert (skill_id, mastery, attempts, mastered) on public.learning_progress to authenticated;
grant update (mastery, attempts, mastered) on public.learning_progress to authenticated;

grant select on public.classes to authenticated;
grant insert (name) on public.classes to authenticated;
grant update (name, archived_at) on public.classes to authenticated;

grant select, delete on public.class_members to authenticated;

-- ── policies ───────────────────────────────────────────────────────────────
-- profiles
create policy profiles_read on public.profiles for select to authenticated
  using (id = auth.uid() or public.teaches(id) or public.is_my_teacher(id) or public.is_admin());
create policy profiles_update_own on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- user_roles: read own (admins read all); writes only via set_user_role()
create policy user_roles_read on public.user_roles for select to authenticated
  using (user_id = auth.uid() or public.is_admin());

-- content
create policy domains_read on public.math_domains for select to authenticated
  using (archived_at is null or public.is_admin());
create policy topics_read on public.math_topics for select to authenticated
  using (archived_at is null or public.is_admin());
create policy skills_read on public.skills for select to authenticated
  using (archived_at is null or public.is_admin());

create policy domains_admin_insert on public.math_domains for insert to authenticated
  with check (public.is_admin());
create policy domains_admin_update on public.math_domains for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
create policy domains_admin_delete on public.math_domains for delete to authenticated
  using (public.is_admin());
create policy topics_admin_insert on public.math_topics for insert to authenticated
  with check (public.is_admin());
create policy topics_admin_update on public.math_topics for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
create policy topics_admin_delete on public.math_topics for delete to authenticated
  using (public.is_admin());
create policy skills_admin_insert on public.skills for insert to authenticated
  with check (public.is_admin());
create policy skills_admin_update on public.skills for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
create policy skills_admin_delete on public.skills for delete to authenticated
  using (public.is_admin());

-- learning_progress
create policy progress_read on public.learning_progress for select to authenticated
  using (student_id = auth.uid() or public.teaches(student_id) or public.is_admin());
create policy progress_insert_own on public.learning_progress for insert to authenticated
  with check (student_id = auth.uid());
create policy progress_update_own on public.learning_progress for update to authenticated
  using (student_id = auth.uid()) with check (student_id = auth.uid());

-- classes
create policy classes_read on public.classes for select to authenticated
  using (teacher_id = auth.uid() or public.in_class(id) or public.is_admin());
create policy classes_teacher_insert on public.classes for insert to authenticated
  with check (teacher_id = auth.uid() and public.my_role() = 'teacher');
create policy classes_teacher_update on public.classes for update to authenticated
  using (teacher_id = auth.uid()) with check (teacher_id = auth.uid());

-- class_members: joining goes through join_class(); leaving / removing is a delete
create policy members_read on public.class_members for select to authenticated
  using (
    student_id = auth.uid()
    or exists (select 1 from public.classes c where c.id = class_id and c.teacher_id = auth.uid())
    or public.is_admin()
  );
create policy members_leave_or_remove on public.class_members for delete to authenticated
  using (
    student_id = auth.uid()
    or exists (select 1 from public.classes c where c.id = class_id and c.teacher_id = auth.uid())
  );

-- ── RPCs ───────────────────────────────────────────────────────────────────
-- Join a class by code. Returns the class id and name.
create function public.join_class(code text)
returns table (class_id uuid, class_name text)
language plpgsql security definer set search_path = ''
as $$
declare
  found public.classes%rowtype;
begin
  if auth.uid() is null then
    raise exception 'not signed in' using errcode = '28000';
  end if;
  select * into found from public.classes c
    where c.join_code = upper(btrim(code)) and c.archived_at is null;
  if found.id is null then
    raise exception 'unknown class code' using errcode = 'P0002';
  end if;
  if found.teacher_id = auth.uid() then
    raise exception 'a teacher cannot join their own class' using errcode = '22023';
  end if;
  insert into public.class_members (class_id, student_id)
    values (found.id, auth.uid())
    on conflict do nothing;
  return query select found.id, found.name;
end;
$$;

-- Give a class a fresh join code (e.g. after it leaked). Teacher only.
create function public.regenerate_join_code(class uuid) returns text
language plpgsql security definer set search_path = ''
as $$
declare
  fresh text;
begin
  update public.classes set join_code = public.new_join_code()
    where id = class and teacher_id = auth.uid()
    returning join_code into fresh;
  if fresh is null then
    raise exception 'not your class' using errcode = '42501';
  end if;
  return fresh;
end;
$$;

-- Change a user's role. Admin only; the last admin cannot be demoted.
create function public.set_user_role(target uuid, new_role text) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'admins only' using errcode = '42501';
  end if;
  if new_role <> 'admin'
     and exists (select 1 from public.user_roles where user_id = target and role = 'admin')
     and (select count(*) from public.user_roles where role = 'admin') = 1 then
    raise exception 'cannot demote the last admin' using errcode = '22023';
  end if;
  update public.user_roles set role = new_role, granted_at = now() where user_id = target;
  if not found then
    raise exception 'unknown user' using errcode = 'P0002';
  end if;
end;
$$;

-- Upload the app's local progress in one call. Items look like
--   {"path": "linear-equations", "skill": "two-step",
--    "mastery": 80, "attempts": 12, "mastered": true}
-- "path" is the topic slug, "skill" the skill slug. Unknown or ambiguous
-- skills are skipped. Runs as the caller (SECURITY INVOKER), so RLS applies:
-- it can only ever write the caller's own rows. Returns rows written.
create function public.sync_progress(items jsonb) returns integer
language plpgsql security invoker set search_path = ''
as $$
declare
  item jsonb;
  target uuid;
  matches integer;
  written integer := 0;
begin
  if auth.uid() is null then
    raise exception 'not signed in' using errcode = '28000';
  end if;
  if jsonb_typeof(items) <> 'array' or jsonb_array_length(items) > 500 then
    raise exception 'items must be an array of at most 500 entries' using errcode = '22023';
  end if;
  for item in select * from jsonb_array_elements(items) loop
    continue when jsonb_typeof(item) <> 'object';
    select count(*), min(s.id::text)::uuid into matches, target
      from public.skills s join public.math_topics t on t.id = s.topic_id
      where t.slug = item ->> 'path' and s.slug = item ->> 'skill'
        and s.archived_at is null and t.archived_at is null;
    continue when matches <> 1;
    -- student_id is left to its default, auth.uid(): callers have no
    -- privilege on that column at all.
    insert into public.learning_progress (skill_id, mastery, attempts, mastered)
      values (
        target,
        least(greatest(coalesce((item ->> 'mastery')::numeric, 0), 0), 100),
        greatest(coalesce((item ->> 'attempts')::integer, 0), 0),
        coalesce((item ->> 'mastered')::boolean, false)
      )
      on conflict (student_id, skill_id) do update
        set mastery = excluded.mastery,
            attempts = greatest(public.learning_progress.attempts, excluded.attempts),
            mastered = excluded.mastered;
    written := written + 1;
  end loop;
  return written;
end;
$$;

-- A teacher's view of one class: every member and every progress row.
-- SECURITY INVOKER: RLS decides what comes back.
create function public.class_progress(class uuid)
returns table (
  student_id uuid, display_name text, path text, skill text,
  mastery numeric, attempts integer, mastered boolean, updated_at timestamptz
)
language sql stable security invoker set search_path = ''
as $$
  select m.student_id, p.display_name, t.slug, s.slug,
         lp.mastery, lp.attempts, lp.mastered, lp.updated_at
  from public.class_members m
  join public.classes c on c.id = m.class_id and c.teacher_id = auth.uid()
  join public.profiles p on p.id = m.student_id
  left join public.learning_progress lp on lp.student_id = m.student_id
  left join public.skills s on s.id = lp.skill_id
  left join public.math_topics t on t.id = s.topic_id
  where m.class_id = class
  order by p.display_name, t.slug, s.slug
$$;

-- ── function privileges ────────────────────────────────────────────────────
revoke all on function
  public.handle_new_user(), public.new_join_code(),
  public.my_role(), public.is_admin(), public.teaches(uuid),
  public.is_my_teacher(uuid), public.in_class(uuid),
  public.join_class(text), public.regenerate_join_code(uuid),
  public.set_user_role(uuid, text), public.sync_progress(jsonb),
  public.class_progress(uuid)
  from public, anon;

grant execute on function
  public.new_join_code(),
  public.my_role(), public.is_admin(), public.teaches(uuid),
  public.is_my_teacher(uuid), public.in_class(uuid),
  public.join_class(text), public.regenerate_join_code(uuid),
  public.set_user_role(uuid, text), public.sync_progress(jsonb),
  public.class_progress(uuid)
  to authenticated;
