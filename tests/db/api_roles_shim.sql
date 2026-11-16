-- Local stand-in for a hosted Postgres API layer (e.g. Supabase / PostgREST).
-- TEST USE ONLY. It proves nothing about any live project; it only lets Row
-- Level Security be exercised on plain PostgreSQL.
--
-- Mirrors the API roles (anon, authenticated) and the usual default grants on
-- the public schema: tables are reachable by those roles, so RLS is the only
-- barrier — which is exactly the situation the tests need to check.

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
end $$;

grant usage on schema public to anon, authenticated;
alter default privileges in schema public
  grant all on tables to anon, authenticated;
alter default privileges in schema public
  grant all on sequences to anon, authenticated;

-- Stand-in for the hosted auth schema: auth.users and auth.uid().
-- Tests "sign in" with:  set local request.jwt.claim.sub = '<uuid>';
create schema if not exists auth;
create table if not exists auth.users (
  id uuid primary key,
  email text,
  raw_user_meta_data jsonb not null default '{}'::jsonb
);
create or replace function auth.uid() returns uuid
language sql stable
as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
grant usage on schema auth to anon, authenticated;
