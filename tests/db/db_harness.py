"""Database test harness.

Applies every migration in backend/database/ (in filename order) to a throwaway
PostgreSQL database, on top of a small API-roles stand-in (api_roles_shim.sql).

Connection settings come from the standard libpq environment variables
(PGHOST, PGPORT, PGUSER, PGPASSWORD). The connecting role must be a superuser.
If no server is reachable the tests are SKIPPED, never silently passed.
"""
from __future__ import annotations

import contextlib
import os
import shutil
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
MIGRATIONS_DIR = REPO_ROOT / "backend" / "database"
SHIM = Path(__file__).with_name("api_roles_shim.sql")


class SqlError(AssertionError):
    """Raised when PostgreSQL rejects a statement."""


def _psql(dbname: str, sql: str, *, single_transaction: bool = False) -> str:
    cmd = ["psql", "-X", "-q", "-A", "-t", "-v", "ON_ERROR_STOP=1", "-d", dbname]
    if single_transaction:
        cmd.append("--single-transaction")
    cmd += ["-f", "-"]
    proc = subprocess.run(cmd, input=sql, capture_output=True, text=True)
    if proc.returncode != 0:
        raise SqlError(proc.stderr.strip())
    return proc.stdout.strip()


def migration_files() -> list[Path]:
    return sorted(MIGRATIONS_DIR.glob("*.sql"))


class Database:
    def __init__(self, name: str):
        self.name = name

    def sql(self, statement: str) -> str:
        """Run as the superuser/owner (bypasses RLS). Returns raw psql output."""
        return _psql(self.name, statement)

    def rows(self, statement: str) -> list[str]:
        out = self.sql(statement)
        return out.splitlines() if out else []

    def migrate(self, paths) -> None:
        for path in paths:
            try:
                _psql(self.name, path.read_text(encoding="utf-8"), single_transaction=True)
            except SqlError as exc:
                raise SqlError(f"migration {path.name} failed to apply:\n{exc}") from None

    def as_role(self, role: str, statement: str) -> list[str]:
        """Run inside a rolled-back transaction as an API role (anon/authenticated)."""
        script = (
            "begin;\n"
            f"set local role {role};\n"
            f"{statement.rstrip().rstrip(';')};\n"
            "rollback;\n"
        )
        out = _psql(self.name, script)
        return out.splitlines() if out else []


@contextlib.contextmanager
def temp_database(suffix: str, *, upto: int | None = None):
    """A throwaway database with the shim and the first `upto` migrations applied."""
    name = f"abqari_test_{os.getpid()}_{suffix}"
    _psql("postgres", f'drop database if exists "{name}"')
    _psql("postgres", f'create database "{name}"')
    try:
        _psql(name, SHIM.read_text(encoding="utf-8"), single_transaction=True)
        database = Database(name)
        database.migrate(migration_files()[:upto])
        yield database
    finally:
        _psql("postgres", f'drop database if exists "{name}" with (force)')


def _require_server():
    if shutil.which("psql") is None:
        pytest.skip("psql is not installed")
    try:
        _psql("postgres", "select 1")
    except SqlError as exc:
        pytest.skip(f"no reachable PostgreSQL server: {exc}")


@pytest.fixture(scope="session")
def db():
    """All migrations applied."""
    _require_server()
    with temp_database("main") as database:
        yield database


@pytest.fixture()
def db_at():
    """Factory: db_at(n) gives a fresh database with only the first n migrations."""
    _require_server()
    with contextlib.ExitStack() as stack:
        counter = iter(range(1000))
        yield lambda upto: stack.enter_context(temp_database(f"at{next(counter)}", upto=upto))
