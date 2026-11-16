"""Schema tests: migrations apply, RLS is deny-by-default, integrity rules hold."""
from __future__ import annotations

import uuid

import pytest

from conftest import SqlError, migration_files

TABLES = ["learning_progress", "math_domains", "math_topics", "profiles", "skills"]
CONTENT_TABLES = ["math_domains", "math_topics", "skills"]
BAD_SLUGS = ["", "Bad Slug", "UPPER", "trailing-", "-leading", "a--b", "كسور", "a_b"]


def _id() -> str:
    return str(uuid.uuid4())


def _slug() -> str:
    return "fixture-" + uuid.uuid4().hex[:12]


@pytest.fixture()
def world(db):
    """One domain → topic → skill chain and one student profile (test fixtures)."""
    w = {k: _id() for k in ("domain", "topic", "skill", "student")}
    db.sql(
        f"""
        insert into public.profiles (id, display_name, role)
          values ('{w["student"]}', 'fixture student', 'student');
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


@pytest.mark.parametrize("role", ["anon", "authenticated"])
@pytest.mark.parametrize("table", TABLES)
def test_api_roles_cannot_read_any_row(db, world, role, table):
    _progress(db, world)
    assert int(db.sql(f"select count(*) from public.{table}")) > 0  # control
    assert db.as_role(role, f"select count(*) from public.{table}") == ["0"]


@pytest.mark.parametrize("role", ["anon", "authenticated"])
def test_api_roles_cannot_insert(db, role):
    with pytest.raises(SqlError, match="row-level security"):
        db.as_role(
            role,
            f"""insert into public.math_domains (slug, title_ar, title_en)
                values ('{_slug()}', 'x', 'x')""",
        )


def test_api_role_cannot_change_a_profile_role(db, world):
    """Holds today only because no UPDATE policy exists yet (audit risk R1)."""
    statement = f"""update public.profiles set role = 'admin'
                    where id = '{world["student"]}' returning id"""
    assert db.as_role("authenticated", statement) == []
    assert db.sql(f"select role from public.profiles where id = '{world['student']}'") == "student"
    # control: the same shape of statement does match the row when RLS is bypassed
    assert db.rows(
        f"update public.profiles set role = role where id = '{world['student']}' returning id"
    ) == [world["student"]]


# ── roles and locales ───────────────────────────────────────────────────────

@pytest.mark.parametrize("role", ["student", "teacher", "admin"])
def test_the_three_roles_are_accepted(db, role):
    db.sql(f"insert into public.profiles (id, display_name, role) values ('{_id()}', 'x', '{role}')")


@pytest.mark.parametrize("role", ["superuser", "Admin", ""])
def test_unknown_roles_rejected(db, role):
    with pytest.raises(SqlError, match="profiles_role_check"):
        db.sql(
            f"insert into public.profiles (id, display_name, role) values ('{_id()}', 'x', '{role}')"
        )


def test_role_is_mandatory(db):
    with pytest.raises(SqlError, match="null value"):
        db.sql(f"insert into public.profiles (id, display_name) values ('{_id()}', 'x')")


def test_locale_defaults_to_arabic_and_accepts_english_only_otherwise(db):
    a, b = _id(), _id()
    db.sql(f"insert into public.profiles (id, display_name, role) values ('{a}', 'x', 'student')")
    assert db.sql(f"select preferred_locale from public.profiles where id = '{a}'") == "ar"
    db.sql(
        f"""insert into public.profiles (id, display_name, role, preferred_locale)
            values ('{b}', 'x', 'student', 'en')"""
    )
    with pytest.raises(SqlError, match="preferred_locale"):
        db.sql(
            f"""insert into public.profiles (id, display_name, role, preferred_locale)
                values ('{_id()}', 'x', 'student', 'fr')"""
        )


# ── integrity rules (migration 002) ─────────────────────────────────────────

def test_blank_display_name_rejected(db):
    with pytest.raises(SqlError, match="profiles_display_name_not_blank"):
        db.sql(
            f"insert into public.profiles (id, display_name, role) values ('{_id()}', '  ', 'student')"
        )


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
