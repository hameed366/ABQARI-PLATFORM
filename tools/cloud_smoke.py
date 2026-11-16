#!/usr/bin/env python3
"""Live check of the real backend, using only its public address and key.

It creates nothing and changes nothing. It proves three things:
  1. the auth service answers and email sign-up is on;
  2. the database migrations were applied (the tables and functions exist);
  3. signed-out callers are refused (row level security / grants work).

Usage: python3 tools/cloud_smoke.py [config/cloud.public.json]
Exit code 0 only when every check passes.
"""
from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def call(url: str, key: str, path: str, method: str = "GET", body: object = None):
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(
        url.rstrip("/") + path, data=data, method=method,
        headers={"apikey": key, "Accept": "application/json",
                 **({"Content-Type": "application/json"} if data else {})},
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            text = resp.read().decode()
            return resp.status, json.loads(text) if text else None
    except urllib.error.HTTPError as err:
        text = err.read().decode()
        try:
            return err.code, json.loads(text)
        except json.JSONDecodeError:
            return err.code, text


def main() -> int:
    cfg = json.loads(Path(sys.argv[1] if len(sys.argv) > 1 else ROOT / "config/cloud.public.json").read_text())
    url, key = cfg["ABQARI_CLOUD_URL"], cfg["ABQARI_CLOUD_ANON_KEY"]
    failures: list[str] = []

    def check(ok: bool, label: str, detail: object = "") -> None:
        print(("PASS " if ok else "FAIL ") + label + (f" — {detail}" if detail and not ok else ""))
        if not ok:
            failures.append(label)

    status, settings = call(url, key, "/auth/v1/settings")
    check(status == 200, "auth service answers", (status, settings))
    if status == 200 and isinstance(settings, dict):
        check(bool(settings.get("external", {}).get("email")), "email sign-in is enabled", settings.get("external"))
        print(f"INFO email confirmation required: {not settings.get('mailer_autoconfirm', False)}")

    def is_missing(reply: object) -> bool:
        return isinstance(reply, dict) and reply.get("code") in {"PGRST205", "PGRST202", "42P01", "42883"}

    def is_refused(status: int, reply: object) -> bool:
        return status in (401, 403) and isinstance(reply, dict) and reply.get("code") == "42501"

    for table in ["profiles", "user_roles", "skills", "learning_progress", "classes", "class_members"]:
        status, reply = call(url, key, f"/rest/v1/{table}?select=*&limit=1")
        if is_missing(reply):
            check(False, f"table {table} exists (run abqari_supabase_setup.sql)", reply)
        else:
            check(is_refused(status, reply), f"signed-out read of {table} is refused", (status, reply))

    for fn, body in [("join_class", {"code": "ABCD2345"}), ("sync_progress", {"items": []}),
                     ("class_progress", {"class": "00000000-0000-0000-0000-000000000000"}),
                     ("set_user_role", {"target": "00000000-0000-0000-0000-000000000000", "new_role": "admin"})]:
        status, reply = call(url, key, f"/rest/v1/rpc/{fn}", "POST", body)
        if is_missing(reply):
            check(False, f"function {fn} exists (run abqari_supabase_setup.sql)", reply)
        else:
            check(is_refused(status, reply), f"signed-out call of {fn} is refused", (status, reply))

    print(f"\n{'ALL CHECKS PASSED' if not failures else f'{len(failures)} CHECK(S) FAILED'}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
