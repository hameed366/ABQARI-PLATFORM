"""Access tests for migration 004: accounts, roles, classes and progress.

Each test acts as real API users would: role `authenticated` with auth.uid()
set to the user's id (db.as_user). The owner connection (db.sql) is used only
to arrange fixtures and to check what actually happened.
"""
from __future__ import annotations

import json
import re
import uuid

import pytest

from db_harness import SqlError

CODE = re.compile(r"^[A-HJKMNP-Z2-9]{8}$")
DENIED = "row-level security|permission denied|admins only|not your class"


def _id() -> str:
    return str(uuid.uuid4())


def make_user(db, name="user", role="student", meta=None) -> str:
    uid = _id()
    data = {"display_name": name, **(meta or {})}
    db.sql(
        "insert into auth.users (id, email, raw_user_meta_data) values "
        f"('{uid}', 'u{uid[:8]}@example.test', '{json.dumps(data, ensure_ascii=False)}')"
    )
    if role != "student":
        db.sql(f"update public.user_roles set role = '{role}' where user_id = '{uid}'")
    return uid


def make_class(db, teacher: str, name="Class A") -> tuple[str, str]:
    out = db.commit_as_user(
        teacher, f"insert into public.classes (name) values ('{name}') returning id, join_code"
    )
    class_id, code = out[0].split("|")
    return class_id, code


def join(db, student: str, code: str) -> list[str]:
    return db.commit_as_user(student, f"select * from public.join_class('{code}')")


def sync(db, user: str, items) -> int:
    payload = json.dumps(items).replace("'", "''")
    return int(db.commit_as_user(user, f"select public.sync_progress('{payload}'::jsonb)")[0])


@pytest.fixture()
def school(seeded_db):
    """A teacher with one class of two students, plus an unrelated teacher and student."""
    db = seeded_db
    s = {
        "teacher": make_user(db, "Teacher T", "teacher"),
        "other_teacher": make_user(db, "Teacher O", "teacher"),
        "alice": make_user(db, "Alice"),
        "bob": make_user(db, "Bob"),
        "stranger": make_user(db, "Stranger"),
    }
    s["class"], s["code"] = make_class(db, s["teacher"])
    join(db, s["alice"], s["code"])
    join(db, s["bob"], s["code"])
    return s


# ── sign-up ─────────────────────────────────────────────────────────────────

def test_sign_up_creates_profile_and_student_role(seeded_db):
    uid = make_user(seeded_db, "حميد", meta={"preferred_locale": "en"})
    assert seeded_db.sql(
        f"select display_name || '|' || preferred_locale from public.profiles where id = '{uid}'"
    ) == "حميد|en"
    assert seeded_db.sql(f"select role from public.user_roles where user_id = '{uid}'") == "student"


@pytest.mark.parametrize("meta", [{"role": "admin"}, {"role": "teacher"}, {"is_admin": True}])
def test_sign_up_data_can_never_choose_a_role(seeded_db, meta):
    uid = make_user(seeded_db, meta=meta)
    assert seeded_db.sql(f"select role from public.user_roles where user_id = '{uid}'") == "student"


def test_sign_up_fallbacks_for_name_and_locale(seeded_db):
    uid = make_user(seeded_db, "   ", meta={"preferred_locale": "fr"})
    row = seeded_db.sql(
        f"select display_name || '|' || preferred_locale from public.profiles where id = '{uid}'"
    )
    assert row == f"u{uid[:8]}|ar"
    long = make_user(seeded_db, "x" * 200)
    assert seeded_db.sql(
        f"select char_length(display_name) from public.profiles where id = '{long}'"
    ) == "60"


# ── profiles ────────────────────────────────────────────────────────────────

def test_user_reads_and_edits_only_own_profile(school, seeded_db):
    db, a, b = seeded_db, school["alice"], school["bob"]
    assert db.as_user(a, f"select display_name from public.profiles where id = '{a}'") == ["Alice"]
    assert db.as_user(
        a, "update public.profiles set display_name = 'Alicia' returning display_name"
    ) == ["Alicia"]
    assert db.as_user(
        a, f"update public.profiles set display_name = 'x' where id = '{school['teacher']}' returning 1"
    ) == []
    assert db.as_user(
        a, f"update public.profiles set display_name = 'hacked' where id = '{b}' returning id"
    ) == []


def test_profile_id_and_creation_time_are_not_editable(school, seeded_db):
    with pytest.raises(SqlError, match="permission denied"):
        seeded_db.as_user(school["alice"], f"update public.profiles set id = '{_id()}'")


def test_classmates_cannot_see_each_other(school, seeded_db):
    a, b = school["alice"], school["bob"]
    assert seeded_db.as_user(a, f"select count(*) from public.profiles where id = '{b}'") == ["0"]
    assert seeded_db.as_user(a, "select count(*) from public.class_members") == ["1"]


def test_student_sees_class_name_and_teacher_name(school, seeded_db):
    a = school["alice"]
    assert seeded_db.as_user(a, "select name from public.classes") == ["Class A"]
    assert seeded_db.as_user(
        a, f"select display_name from public.profiles where id = '{school['teacher']}'"
    ) == ["Teacher T"]


def test_teacher_sees_own_students_only(school, seeded_db):
    names = seeded_db.as_user(
        school["teacher"], "select display_name from public.profiles order by 1"
    )
    assert names == ["Alice", "Bob", "Teacher T"]
    assert seeded_db.as_user(
        school["other_teacher"], "select display_name from public.profiles order by 1"
    ) == ["Teacher O"]


# ── roles ───────────────────────────────────────────────────────────────────

def test_user_reads_only_own_role(school, seeded_db):
    assert seeded_db.as_user(school["alice"], "select role from public.user_roles") == ["student"]
    assert seeded_db.as_user(school["teacher"], "select role from public.user_roles") == ["teacher"]


@pytest.mark.parametrize("who", ["alice", "teacher"])
def test_non_admins_cannot_change_roles(school, seeded_db, who):
    with pytest.raises(SqlError, match="admins only"):
        seeded_db.as_user(school[who], f"select public.set_user_role('{school[who]}', 'admin')")


def test_admin_promotes_and_cannot_remove_last_admin(seeded_db):
    db = seeded_db
    # Isolated: make sure exactly one admin exists for this check.
    db.sql("update public.user_roles set role = 'student' where role = 'admin'")
    admin = make_user(db, "Admin", "admin")
    user = make_user(db, "New teacher")
    db.commit_as_user(admin, f"select public.set_user_role('{user}', 'teacher')")
    assert db.sql(f"select role from public.user_roles where user_id = '{user}'") == "teacher"
    with pytest.raises(SqlError, match="last admin"):
        db.as_user(admin, f"select public.set_user_role('{admin}', 'student')")
    db.commit_as_user(admin, f"select public.set_user_role('{user}', 'admin')")
    db.commit_as_user(user, f"select public.set_user_role('{admin}', 'student')")
    assert db.sql(f"select role from public.user_roles where user_id = '{admin}'") == "student"
    assert db.as_user(user, "select count(*) from public.user_roles") != ["1"]


def test_admin_rejects_unknown_user_and_role(seeded_db):
    admin = make_user(seeded_db, "Admin 2", "admin")
    with pytest.raises(SqlError, match="unknown user"):
        seeded_db.as_user(admin, f"select public.set_user_role('{_id()}', 'teacher')")
    with pytest.raises(SqlError, match="user_roles_role_check"):
        seeded_db.as_user(admin, f"select public.set_user_role('{admin}', 'owner')")


# ── classes ─────────────────────────────────────────────────────────────────

def test_teacher_creates_class_with_a_safe_join_code(school, seeded_db):
    assert CODE.match(school["code"])
    owner = seeded_db.sql(f"select teacher_id from public.classes where id = '{school['class']}'")
    assert owner == school["teacher"]


def test_students_cannot_create_classes(school, seeded_db):
    with pytest.raises(SqlError, match="row-level security"):
        seeded_db.as_user(school["alice"], "insert into public.classes (name) values ('mine')")


def test_teacher_cannot_create_class_for_someone_else_or_pick_its_code(school, seeded_db):
    t = school["teacher"]
    with pytest.raises(SqlError, match="permission denied"):
        seeded_db.as_user(
            t, f"insert into public.classes (name, teacher_id) values ('x', '{school['other_teacher']}')"
        )
    with pytest.raises(SqlError, match="permission denied"):
        seeded_db.as_user(t, "insert into public.classes (name, join_code) values ('x', 'AAAAAAAA')")


def test_other_teacher_cannot_see_or_edit_the_class(school, seeded_db):
    o = school["other_teacher"]
    assert seeded_db.as_user(o, "select count(*) from public.classes") == ["0"]
    assert seeded_db.as_user(
        o, f"update public.classes set name = 'mine' where id = '{school['class']}' returning id"
    ) == []


def test_join_code_is_forgiving_and_joining_twice_is_harmless(school, seeded_db):
    s = make_user(seeded_db, "Carol")
    messy = "  " + school["code"].lower() + " "
    assert join(seeded_db, s, messy) == [f"{school['class']}|Class A"]
    join(seeded_db, s, school["code"])
    assert seeded_db.sql(
        f"select count(*) from public.class_members where student_id = '{s}'"
    ) == "1"


def test_unknown_code_and_archived_class_are_rejected(school, seeded_db):
    s = make_user(seeded_db, "Dan")
    with pytest.raises(SqlError, match="unknown class code"):
        join(seeded_db, s, "ZZZZZZZZ")
    seeded_db.commit_as_user(
        school["teacher"], f"update public.classes set archived_at = now() where id = '{school['class']}'"
    )
    with pytest.raises(SqlError, match="unknown class code"):
        join(seeded_db, s, school["code"])


def test_teacher_cannot_join_own_class(school, seeded_db):
    with pytest.raises(SqlError, match="cannot join their own class"):
        join(seeded_db, school["teacher"], school["code"])


def test_members_cannot_be_added_directly(school, seeded_db):
    with pytest.raises(SqlError, match="permission denied"):
        seeded_db.as_user(
            school["stranger"],
            f"insert into public.class_members (class_id) values ('{school['class']}')",
        )


def test_regenerated_code_replaces_the_old_one(school, seeded_db):
    fresh = seeded_db.commit_as_user(
        school["teacher"], f"select public.regenerate_join_code('{school['class']}')"
    )[0]
    assert CODE.match(fresh) and fresh != school["code"]
    with pytest.raises(SqlError, match="unknown class code"):
        join(seeded_db, school["stranger"], school["code"])
    with pytest.raises(SqlError, match="not your class"):
        seeded_db.as_user(
            school["other_teacher"], f"select public.regenerate_join_code('{school['class']}')"
        )


# ── progress ────────────────────────────────────────────────────────────────

ITEMS = [
    {"path": "linear-equations", "skill": "two-step", "mastery": 80, "attempts": 7, "mastered": True},
    {"path": "fractions", "skill": "add-fractions", "mastery": 40, "attempts": 3, "mastered": False},
]


def test_sync_writes_own_progress_and_is_repeatable(school, seeded_db):
    a = school["alice"]
    assert sync(seeded_db, a, ITEMS) == 2
    assert sync(seeded_db, a, ITEMS) == 2
    rows = seeded_db.as_user(a, "select mastery, attempts, mastered from public.learning_progress order by mastery")
    assert rows == ["40.00|3|f", "80.00|7|t"]


def test_sync_clamps_values_and_skips_unknown_skills(school, seeded_db):
    b = school["bob"]
    items = [
        {"path": "linear-equations", "skill": "two-step", "mastery": 250, "attempts": -4},
        {"path": "linear-equations", "skill": "no-such-skill", "mastery": 50},
        {"path": "made-up", "skill": "two-step"},
        "not an object",
    ]
    assert sync(seeded_db, b, items) == 1
    assert seeded_db.as_user(b, "select mastery, attempts from public.learning_progress") == ["100.00|0"]


def test_sync_never_lowers_attempts(school, seeded_db):
    a = school["alice"]
    sync(seeded_db, a, [{**ITEMS[0], "attempts": 9}])
    sync(seeded_db, a, [{**ITEMS[0], "attempts": 2}])
    assert seeded_db.as_user(a, "select attempts from public.learning_progress") == ["9"]


def test_sync_rejects_oversized_or_malformed_payloads(school, seeded_db):
    a = school["alice"]
    with pytest.raises(SqlError, match="at most 500"):
        sync(seeded_db, a, [ITEMS[0]] * 501)
    with pytest.raises(SqlError, match="at most 500"):
        seeded_db.as_user(a, """select public.sync_progress('{"a": 1}'::jsonb)""")


def test_nobody_writes_someone_elses_progress(school, seeded_db):
    a, b = school["alice"], school["bob"]
    sync(seeded_db, b, ITEMS)
    skill = seeded_db.sql("select id from public.skills where slug = 'two-step'")
    with pytest.raises(SqlError, match="permission denied"):
        seeded_db.as_user(
            a, f"insert into public.learning_progress (student_id, skill_id) values ('{b}', '{skill}')"
        )
    assert seeded_db.as_user(
        a, f"update public.learning_progress set mastery = 0 where student_id = '{b}' returning 1"
    ) == []
    assert seeded_db.as_user(
        school["teacher"], f"update public.learning_progress set mastery = 0 where student_id = '{b}' returning 1"
    ) == []


def test_teacher_reads_class_progress_and_others_do_not(school, seeded_db):
    sync(seeded_db, school["alice"], ITEMS)
    rows = seeded_db.as_user(
        school["teacher"],
        f"select display_name, path, skill, mastery from public.class_progress('{school['class']}')",
    )
    assert rows == [
        "Alice|fractions|add-fractions|40.00",
        "Alice|linear-equations|two-step|80.00",
        "Bob|||",
    ]
    assert seeded_db.as_user(
        school["other_teacher"], f"select count(*) from public.class_progress('{school['class']}')"
    ) == ["0"]
    assert seeded_db.as_user(
        school["bob"], f"select count(*) from public.class_progress('{school['class']}')"
    ) == ["0"]
    assert seeded_db.as_user(school["stranger"], "select count(*) from public.learning_progress") == ["0"]


def test_leaving_or_removal_ends_the_teachers_access(school, seeded_db):
    a, b, t = school["alice"], school["bob"], school["teacher"]
    sync(seeded_db, a, ITEMS)
    sync(seeded_db, b, ITEMS)
    seeded_db.commit_as_user(a, "delete from public.class_members")
    assert seeded_db.as_user(t, f"select count(*) from public.learning_progress where student_id = '{a}'") == ["0"]
    seeded_db.commit_as_user(t, f"delete from public.class_members where student_id = '{b}'")
    assert seeded_db.as_user(t, f"select count(*) from public.profiles where id = '{b}'") == ["0"]


def test_archiving_a_class_ends_the_teachers_access(school, seeded_db):
    a, t = school["alice"], school["teacher"]
    sync(seeded_db, a, ITEMS)
    seeded_db.commit_as_user(t, f"update public.classes set archived_at = now() where id = '{school['class']}'")
    assert seeded_db.as_user(t, f"select count(*) from public.learning_progress where student_id = '{a}'") == ["0"]


def test_student_cannot_remove_classmates(school, seeded_db):
    assert seeded_db.as_user(
        school["alice"], f"delete from public.class_members where student_id = '{school['bob']}' returning 1"
    ) == []


# ── content ─────────────────────────────────────────────────────────────────

def test_signed_in_users_read_live_content_only(seeded_db):
    db = seeded_db
    s = make_user(db, "Reader")
    admin = make_user(db, "Admin 3", "admin")
    assert db.as_user(s, "select count(*) from public.skills") == ["11"]
    db.sql("update public.skills set archived_at = now() where slug = 'brackets'")
    try:
        assert db.as_user(s, "select count(*) from public.skills") == ["10"]
        assert db.as_user(admin, "select count(*) from public.skills") == ["11"]
        assert sync(db, s, [{"path": "linear-equations", "skill": "brackets", "mastery": 1}]) == 0
    finally:
        db.sql("update public.skills set archived_at = null where slug = 'brackets'")


@pytest.mark.parametrize("role", ["student", "teacher"])
def test_only_admins_write_content(seeded_db, role):
    user = make_user(seeded_db, role=role)
    with pytest.raises(SqlError, match="row-level security"):
        seeded_db.as_user(
            user, "insert into public.math_domains (slug, title_ar, title_en) values ('geo', 'هندسة', 'Geometry')"
        )
    assert seeded_db.as_user(user, "update public.skills set title_en = 'x' returning 1") == []


def test_admin_writes_content(seeded_db):
    admin = make_user(seeded_db, "Admin 4", "admin")
    out = seeded_db.as_user(
        admin,
        "insert into public.math_domains (slug, title_ar, title_en) values ('geometry', 'الهندسة', 'Geometry') returning slug",
    )
    assert out == ["geometry"]


# ── signed out ──────────────────────────────────────────────────────────────

@pytest.mark.parametrize(
    "call",
    [
        "public.join_class('ABCDEFGH')",
        "public.sync_progress('[]'::jsonb)",
        f"public.set_user_role('{uuid.uuid4()}', 'admin')",
        f"public.class_progress('{uuid.uuid4()}')",
        f"public.regenerate_join_code('{uuid.uuid4()}')",
    ],
)
def test_signed_out_callers_cannot_use_any_function(seeded_db, call):
    with pytest.raises(SqlError, match="permission denied"):
        seeded_db.as_role("anon", f"select * from {call}")


def test_signed_in_role_without_identity_cannot_join_or_sync(seeded_db):
    with pytest.raises(SqlError, match="not signed in"):
        seeded_db.as_role("authenticated", "select * from public.join_class('ABCDEFGH')")
    with pytest.raises(SqlError, match="not signed in"):
        seeded_db.as_role("authenticated", "select public.sync_progress('[]'::jsonb)")


def test_seed_can_be_applied_again(seeded_db):
    from db_harness import SEED

    before = seeded_db.sql("select count(*) from public.skills")
    seeded_db.sql(SEED.read_text(encoding="utf-8"))
    assert seeded_db.sql("select count(*) from public.skills") == before
