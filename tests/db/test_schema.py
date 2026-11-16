"""Schema tests: migrations apply, RLS is deny-by-default, integrity rules hold."""
from __future__ import annotations

import uuid

import pytest

from db_harness import SqlError, migration_files

TABLES = [
    "class_members", "classes", "learning_progress", "math_domains",
    "math_topics", "profiles", "skills", "user_roles",
]
# Tables a signed-in user with no relationships must see nothing of.
PRIVATE_TABLES = ["class_members", "classes", "learning_progress", "profiles", "user_roles"]
CONTENT_TABLES = ["math_domains", "math_topics", "skills"]
BAD_SLUGS = ["", "Bad Slug", "UPPER", "trailing-", "-leading", "a--b", "كسور", "a_b"]


def _id() -> str:
    return str(uuid.uuid4())


def auth_user(db, uid: str | None = None, name: str = "x", locale: str | None = None) -> str:
    """Create an auth user; migration 004's trigger gives it a profile and a role."""
    uid = uid or _id()
    meta = {"display_name": name}
    if locale is not None:
        meta["preferred_locale"] = locale
    import json
    db.sql(
        "insert into auth.users (id, email, raw_user_meta_data) values "
        f"('{uid}', '{uid[:8]}@example.test', '{json.dumps(meta, ensure_ascii=False)}')"
    )
    return uid


def _slug() -> str:
    return "fixture-" + uuid.uuid4().hex[:12]


@pytest.fixture()
def world(db):
    """One domain → topic → skill chain and one student profile (test fixtures)."""
    w = {k: _id() for k in ("domain", "topic", "skill", "student")}
    auth_user(db, w["student"], "fixture student")
    db.sql(
        f"""
        insert into public.math_domains (id, slug, title_ar, title_en)
          values ('{w["domain"]}', '{_slug()}', 'مجال تجريبي', 'Fixture domain');
        insert into public.math_topics (id, domain_id, slug, title_ar, title_en)
          values ('{w["topic"]}', '{w["domain"]}', '{_slug()}', 'موضوع تجريبي', 'Fixture topic');
        insert into public.skills (id, topic_id, slug, title_ar, title_en)
          values ('{w["skill"]}', '{w["topic"]}', '{_slug()}', 'مهارة تجريبية', 'Fixture skill');
        """
    )
    return w


def _progress(db, w, mastery="0", extra_cols="", extra_vals=""):
    db.sql(
        f"""insert into public.learning_progress (student_id, skill_id, mastery{extra_cols})
            values ('{w["student"]}', '{w["skill"]}', {mastery}{extra_vals})"""
    )


# ── migrations ──────────────────────────────────────────────────────────────

def test_migrations_exist_and_are_numbered_in_sequence():
    names = [p.name for p in migration_files()]
    assert names, "no migrations found"
    prefixes = [n.split("_")[0] for n in names]
    assert prefixes == [f"{i:03d}" for i in range(1, len(names) + 1)], names


def test_exactly_the_expected_tables_exist(db):
    found = db.rows("select tablename from pg_tables where schemaname = 'public' order by 1")
    assert found == TABLES


def test_no_country_or_curriculum_columns(db):
    """Product decision: no country / ministry / curriculum / textbook structure."""
    offending = db.rows(
        """select table_name || '.' || column_name from information_schema.columns
           where table_schema = 'public'
             and column_name ~* '(country|curricul|ministry|textbook|semester|grade)'"""
    )
    assert offending == []


# ── row level security: deny by default ─────────────────────────────────────

def test_rls_enabled_on_every_public_table(db):
    unprotected = db.rows(
        """select c.relname from pg_class c
           join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity"""
    )
    assert unprotected == []


@pytest.mark.parametrize("table", TABLES)
def test_anon_has_no_access_to_any_table(db, world, table):
    """Accounts are optional; the signed-out API role reaches nothing."""
    _progress(db, world)
    assert int(db.sql(f"select count(*) from public.{table}")) > 0 or table.startswith("class")
    with pytest.raises(SqlError, match="permission denied"):
        db.as_role("anon", f"select count(*) from public.{table}")


@pytest.mark.parametrize("table", PRIVATE_TABLES)
def test_authenticated_without_identity_reads_no_private_row(db, world, table):
    _progress(db, world)
    assert db.as_role("authenticated", f"select count(*) from public.{table}") == ["0"]


@pytest.mark.parametrize("role", ["anon", "authenticated"])
def test_api_roles_cannot_insert_content(db, role):
    with pytest.raises(SqlError, match="row-level security|permission denied"):
        db.as_role(
            role,
            f"""insert into public.math_domains (slug, title_ar, title_en)
                values ('{_slug()}', 'x', 'x')""",
        )


def test_profiles_no_longer_carry_a_role(db):
    """R1: nothing an owner may later edit holds the role."""
    cols = db.rows(
        """select column_name from information_schema.columns
           where table_schema = 'public' and table_name = 'profiles'"""
    )
    assert "role" not in cols


@pytest.mark.parametrize("role", ["anon", "authenticated"])
def test_api_roles_cannot_grant_or_change_roles(db, world, role):
    denied = "row-level security|permission denied"
    with pytest.raises(SqlError, match=denied):
        db.as_role(role, f"update public.user_roles set role = 'admin' where user_id = '{world['student']}'")
    with pytest.raises(SqlError, match=denied):
        db.as_role(
            role,
            f"""insert into public.user_roles (user_id, role)
                values ('{world["student"]}', 'admin')
                on conflict (user_id) do update set role = excluded.role""",
        )
    with pytest.raises(SqlError, match=denied):
        db.as_role(role, "delete from public.user_roles")
    assert db.sql(
        f"select role from public.user_roles where user_id = '{world['student']}'"
    ) == "student"


def test_accounts_migration_refuses_profiles_without_an_auth_user(db_at):
    """004 never deletes data: a profile with no auth user stops the migration."""
    old = db_at(3)
    old.sql(f"insert into public.profiles (id, display_name) values ('{_id()}', 'orphan')")
    with pytest.raises(SqlError, match="profiles_id_fkey"):
        old.migrate(migration_files()[3:4])
    assert old.sql("select count(*) from public.profiles") == "1"


# ── roles and locales ───────────────────────────────────────────────────────

def test_new_profile_starts_as_student(db):
    uid = auth_user(db)
    assert db.sql(f"select role from public.user_roles where user_id = '{uid}'") == "student"


@pytest.mark.parametrize("role", ["student", "teacher", "admin"])
def test_the_three_roles_are_accepted(db, world, role):
    db.sql(f"update public.user_roles set role = '{role}' where user_id = '{world['student']}'")
    assert db.sql(
        f"select role from public.user_roles where user_id = '{world['student']}'"
    ) == role


@pytest.mark.parametrize("role", ["superuser", "Admin", ""])
def test_unknown_roles_rejected(db, world, role):
    with pytest.raises(SqlError, match="user_roles_role_check"):
        db.sql(f"update public.user_roles set role = '{role}' where user_id = '{world['student']}'")


def test_one_role_per_user_and_role_dies_with_profile(db, world):
    with pytest.raises(SqlError, match="duplicate key"):
        db.sql(f"insert into public.user_roles (user_id, role) values ('{world['student']}', 'teacher')")
    db.sql(f"delete from public.profiles where id = '{world['student']}'")
    assert db.sql(
        f"select count(*) from public.user_roles where user_id = '{world['student']}'"
    ) == "0"


def test_existing_roles_survive_the_move_out_of_profiles(db_at):
    """Data migration: roles stored under 001/002 are carried into user_roles by 003."""
    old = db_at(2)
    ids = {role: _id() for role in ("student", "teacher", "admin")}
    for role, uid in ids.items():
        old.sql(
            f"insert into public.profiles (id, display_name, role) values ('{uid}', 'x', '{role}')"
        )
    old.migrate(migration_files()[2:3])
    for role, uid in ids.items():
        assert old.sql(f"select role from public.user_roles where user_id = '{uid}'") == role


def test_locale_defaults_to_arabic_and_accepts_english_only_otherwise(db):
    a = auth_user(db)
    assert db.sql(f"select preferred_locale from public.profiles where id = '{a}'") == "ar"
    b = auth_user(db, locale="en")
    assert db.sql(f"select preferred_locale from public.profiles where id = '{b}'") == "en"
    with pytest.raises(SqlError, match="preferred_locale"):
        db.sql(f"update public.profiles set preferred_locale = 'fr' where id = '{a}'")


# ── integrity rules (migration 002) ─────────────────────────────────────────

def test_blank_display_name_rejected(db):
    uid = auth_user(db)
    with pytest.raises(SqlError, match="profiles_display_name_not_blank"):
        db.sql(f"update public.profiles set display_name = '  ' where id = '{uid}'")


@pytest.mark.parametrize("slug", BAD_SLUGS)
def test_domain_slug_format(db, slug):
    with pytest.raises(SqlError, match="math_domains_slug_format"):
        db.sql(
            f"insert into public.math_domains (slug, title_ar, title_en) values ('{slug}', 'x', 'x')"
        )


@pytest.mark.parametrize("slug", ["Bad Slug", ""])
def test_topic_and_skill_slug_format(db, world, slug):
    with pytest.raises(SqlError, match="math_topics_slug_format"):
        db.sql(
            f"""insert into public.math_topics (domain_id, slug, title_ar, title_en)
                values ('{world["domain"]}', '{slug}', 'x', 'x')"""
        )
    with pytest.raises(SqlError, match="skills_slug_format"):
        db.sql(
            f"""insert into public.skills (topic_id, slug, title_ar, title_en)
                values ('{world["topic"]}', '{slug}', 'x', 'x')"""
        )


@pytest.mark.parametrize("title_ar,title_en", [("", "x"), ("x", "  ")])
def test_both_language_titles_are_required(db, world, title_ar, title_en):
    with pytest.raises(SqlError, match="math_domains_titles_not_blank"):
        db.sql(
            f"""insert into public.math_domains (slug, title_ar, title_en)
                values ('{_slug()}', '{title_ar}', '{title_en}')"""
        )
    with pytest.raises(SqlError, match="math_topics_titles_not_blank"):
        db.sql(
            f"""insert into public.math_topics (domain_id, slug, title_ar, title_en)
                values ('{world["domain"]}', '{_slug()}', '{title_ar}', '{title_en}')"""
        )
    with pytest.raises(SqlError, match="skills_titles_not_blank"):
        db.sql(
            f"""insert into public.skills (topic_id, slug, title_ar, title_en)
                values ('{world["topic"]}', '{_slug()}', '{title_ar}', '{title_en}')"""
        )


def test_slug_unique_within_parent_but_reusable_across_parents(db, world):
    slug = _slug()
    other_domain = _id()
    db.sql(
        f"""insert into public.math_domains (id, slug, title_ar, title_en)
              values ('{other_domain}', '{_slug()}', 'x', 'x');
            insert into public.math_topics (domain_id, slug, title_ar, title_en) values
              ('{world["domain"]}', '{slug}', 'x', 'x'),
              ('{other_domain}', '{slug}', 'x', 'x');"""
    )
    with pytest.raises(SqlError, match="duplicate key"):
        db.sql(
            f"""insert into public.math_topics (domain_id, slug, title_ar, title_en)
                values ('{world["domain"]}', '{slug}', 'x', 'x')"""
        )


@pytest.mark.parametrize("difficulty", ["0", "6"])
def test_topic_difficulty_bounds(db, world, difficulty):
    with pytest.raises(SqlError, match="difficulty"):
        db.sql(
            f"""insert into public.math_topics (domain_id, slug, title_ar, title_en, difficulty)
                values ('{world["domain"]}', '{_slug()}', 'x', 'x', {difficulty})"""
        )


# ── learning progress ───────────────────────────────────────────────────────

@pytest.mark.parametrize("mastery", ["-0.01", "100.01"])
def test_mastery_bounds(db, world, mastery):
    with pytest.raises(SqlError, match="mastery"):
        _progress(db, world, mastery=mastery)


def test_one_progress_row_per_student_and_skill(db, world):
    _progress(db, world)
    with pytest.raises(SqlError, match="duplicate key"):
        _progress(db, world)


def test_progress_requires_existing_student_and_skill(db, world):
    with pytest.raises(SqlError, match="foreign key"):
        db.sql(
            f"""insert into public.learning_progress (student_id, skill_id)
                values ('{_id()}', '{world["skill"]}')"""
        )
    with pytest.raises(SqlError, match="foreign key"):
        db.sql(
            f"""insert into public.learning_progress (student_id, skill_id)
                values ('{world["student"]}', '{_id()}')"""
        )


def test_progress_updated_at_is_maintained(db, world):
    _progress(db, world, extra_cols=", updated_at", extra_vals=", '2000-01-01'")
    db.sql(
        f"""update public.learning_progress set mastery = 50
            where student_id = '{world["student"]}'"""
    )
    year = db.sql(
        f"""select extract(year from updated_at)::int from public.learning_progress
            where student_id = '{world["student"]}'"""
    )
    assert int(year) > 2000


def test_deleting_profile_removes_its_progress(db, world):
    _progress(db, world)
    db.sql(f"delete from public.profiles where id = '{world['student']}'")
    assert db.sql(
        f"select count(*) from public.learning_progress where student_id = '{world['student']}'"
    ) == "0"


# ── archive instead of delete (migration 003, decision R2) ──────────────────

@pytest.mark.parametrize("level,table", [("domain", "math_domains"), ("topic", "math_topics"), ("skill", "skills")])
def test_content_with_student_progress_cannot_be_deleted(db, world, level, table):
    _progress(db, world, mastery="80")
    with pytest.raises(SqlError, match="learning_progress_skill_id_fkey"):
        db.sql(f"delete from public.{table} where id = '{world[level]}'")
    assert db.sql(
        f"select mastery from public.learning_progress where student_id = '{world['student']}'"
    ) == "80.00"


def test_content_without_progress_can_still_be_deleted(db, world):
    db.sql(f"delete from public.math_domains where id = '{world['domain']}'")
    assert db.sql(f"select count(*) from public.skills where id = '{world['skill']}'") == "0"


@pytest.mark.parametrize("table,key", [("math_domains", "domain"), ("math_topics", "topic"), ("skills", "skill")])
def test_content_can_be_archived_and_keeps_progress(db, world, table, key):
    _progress(db, world, mastery="80")
    assert db.sql(f"select archived_at is null from public.{table} where id = '{world[key]}'") == "t"
    db.sql(f"update public.{table} set archived_at = now() where id = '{world[key]}'")
    assert db.sql(
        f"select count(*) from public.learning_progress where student_id = '{world['student']}'"
    ) == "1"
